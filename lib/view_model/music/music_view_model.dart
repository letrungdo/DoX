import 'dart:async';
import 'dart:math';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/model/music_shelf.dart';
import 'package:do_x/model/music_track.dart';
import 'package:do_x/services/music_auth_service.dart';
import 'package:do_x/services/music_playback_session.dart';
import 'package:do_x/services/music_service.dart';
import 'package:do_x/utils/device_type.dart';
import 'package:do_x/utils/logger.dart';
import 'package:do_x/view_model/core/core_view_model.dart';

enum MusicTab { home, search, likes, history }

/// How a tap on a heart ended. A like is the one action on this page that
/// needs an account, so "you are not signed in" is an outcome of its own and
/// not just another failure. The bot protection's check is another: it is
/// the user, not the app, who can get past it.
enum MusicLikeOutcome { done, signInRequired, challengeRequired, failed }

class MusicViewModel extends CoreViewModel implements MusicPlaybackControls {
  MusicViewModel({
    Future<String> Function(String transcodingUrl)? resolveStream,
    MusicPlaybackSession? playback,
  }) : _resolveStream = resolveStream ?? musicService.resolvePlayableStream,
       _playback = playback ?? musicPlayback;

  /// Turns a track's transcoding link into one a player can open. Replaceable
  /// so a test can decide when each answer arrives.
  final Future<String> Function(String transcodingUrl) _resolveStream;

  /// Where the system's media controls are kept up to date.
  final MusicPlaybackSession _playback;

  /// Heading for the one row built from a plain search, for an account the
  /// service has no selections for.
  static const _fallbackShelfTitle = 'Trending';

  List<MusicShelf> _shelves = [];
  List<MusicShelf> get shelves => _shelves;

  /// Every Discover track in the order it is shown, which is the queue the
  /// player walks with next/previous while the tab is Discover.
  List<MusicTrack> get discoverTracks => [
    for (final shelf in _shelves) ...shelf.tracks,
  ];

  List<MusicTrack> _searchResults = [];
  List<MusicTrack> get searchResults => _searchResults;

  List<MusicTrack> _likedTracks = [];
  List<MusicTrack> get likedTracks => _likedTracks;

  List<MusicTrack> _historyTracks = [];
  List<MusicTrack> get historyTracks => _historyTracks;

  MusicTab _currentTab = MusicTab.home;
  MusicTab get currentTab => _currentTab;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  MusicTrack? _currentTrack;
  MusicTrack? get currentTrack => _currentTrack;

  VideoPlayerController? _audioController;
  VideoPlayerController? get audioController => _audioController;

  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;

  Duration _position = Duration.zero;
  Duration get position => _position;

  Duration _duration = Duration.zero;
  Duration get duration => _duration;

  bool _isRepeatEnabled = false;
  bool get isRepeatEnabled => _isRepeatEnabled;

  bool _isShuffleEnabled = false;
  bool get isShuffleEnabled => _isShuffleEnabled;

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  Timer? _positionTimer;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    musicAuth.addListener(_onAccountChanged);
    _start();
  }

  /// The stored token has to be back before the first request goes out, or the
  /// personal endpoints answer as a stranger and the page opens empty.
  Future<void> _start() async {
    await musicAuth.restore();
    await loadHomeData();
  }

  bool get isSignedIn => musicAuth.isSignedIn;

  String get accountName => musicAuth.account?.username ?? '';

  /// Signing in or out changes what the personal tabs can show, so refetch
  /// whichever one is open.
  void _onAccountChanged() {
    if (_currentTab == MusicTab.likes) {
      loadLikedTracks();
    } else if (_currentTab == MusicTab.history) {
      loadHistoryTracks();
    } else {
      notifyListenersSafe();
    }
  }

  void switchTab(MusicTab tab) {
    _currentTab = tab;
    if (tab == MusicTab.likes) {
      loadLikedTracks();
    } else if (tab == MusicTab.history) {
      loadHistoryTracks();
    }
    notifyListenersSafe();
  }

  Future<void> loadHomeData() async {
    _isLoading = true;
    notifyListenersSafe();
    try {
      // The hearts come along with the rows: a liked track has to look liked
      // wherever it turns up, not only in the likes tab.
      await musicService.loadLikedTrackIds();
      _shelves = await musicService.getDiscoverShelves();
      // An account the service has nothing personal for still gets a page.
      if (_shelves.isEmpty) {
        final tracks = await musicService.searchTracks('');
        if (tracks.isNotEmpty) {
          _shelves = [MusicShelf(title: _fallbackShelfTitle, tracks: tracks)];
        }
      }
    } catch (e, st) {
      logger.e('MusicViewModel loadHomeData failed', error: e, stackTrace: st);
    } finally {
      _isLoading = false;
      notifyListenersSafe();
    }
  }

  Future<void> loadLikedTracks() async {
    _isLoading = true;
    notifyListenersSafe();
    try {
      _likedTracks = await musicService.getLikedTracks();
    } catch (e, st) {
      logger.e(
        'MusicViewModel loadLikedTracks failed',
        error: e,
        stackTrace: st,
      );
    } finally {
      _isLoading = false;
      notifyListenersSafe();
    }
  }

  Future<void> loadHistoryTracks() async {
    _isLoading = true;
    notifyListenersSafe();
    try {
      _historyTracks = await musicService.getHistoryTracks();
    } catch (e, st) {
      logger.e(
        'MusicViewModel loadHistoryTracks failed',
        error: e,
        stackTrace: st,
      );
    } finally {
      _isLoading = false;
      notifyListenersSafe();
    }
  }

  Future<void> searchTracks(String query) async {
    _searchQuery = query;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), () async {
      _isLoading = true;
      notifyListenersSafe();
      try {
        _searchResults = await musicService.searchTracks(query);
      } catch (e, st) {
        logger.e(
          'MusicViewModel searchTracks failed',
          error: e,
          stackTrace: st,
        );
      } finally {
        _isLoading = false;
        notifyListenersSafe();
      }
    });
  }

  /// The check the last like was stopped by, once [toggleLike] has answered
  /// [MusicLikeOutcome.challengeRequired].
  String? _likeChallengeUrl;
  String? get likeChallengeUrl => _likeChallengeUrl;

  Future<MusicLikeOutcome> toggleLike(MusicTrack track) async {
    _likeChallengeUrl = null;
    try {
      await musicService.toggleLikeTrack(track);
    } on MusicSignInRequired {
      return MusicLikeOutcome.signInRequired;
    } on MusicChallengeRequired catch (e) {
      _likeChallengeUrl = e.url;
      return MusicLikeOutcome.challengeRequired;
    } catch (e, st) {
      logger.e('MusicViewModel toggleLike failed', error: e, stackTrace: st);
      notifyListenersSafe();
      return MusicLikeOutcome.failed;
    }
    // Refresh liked tracks if we are on the likes tab
    if (_currentTab == MusicTab.likes) {
      await loadLikedTracks();
    }
    notifyListenersSafe();
    return MusicLikeOutcome.done;
  }

  Future<void> signOut() async {
    await musicAuth.signOut();
  }

  bool isLiked(String trackId) => musicService.isTrackLiked(trackId);

  /// Bumped by every tap on a track and by the page going away. A track
  /// takes a couple of round trips to come up, and whatever was asked for in
  /// the meantime wins: a load that finds the number moved on throws its
  /// player away instead of starting it, or two tracks play over each other
  /// and one of them belongs to nobody — nothing can stop it but killing the
  /// app.
  int _playGeneration = 0;

  bool _isCurrentPlay(int generation) =>
      generation == _playGeneration && !isDispose;

  Future<void> playTrack(MusicTrack track) async {
    if (_currentTrack?.id == track.id && _audioController != null) {
      togglePlay();
      return;
    }

    final generation = ++_playGeneration;
    // Read before the first await, while the page is certainly still there.
    final channelName = context.l10n.musicPlaybackChannel;
    _positionTimer?.cancel();
    // Let go of it before waiting on it: a tap that lands during the wait
    // must not find it still here and stop it a second time.
    final oldController = _audioController;
    _audioController = null;
    if (oldController != null) {
      oldController.removeListener(_videoPlayerListener);
      await oldController.pause();
      await oldController.dispose();
    }
    if (!_isCurrentPlay(generation)) return;

    _currentTrack = track;
    _isPlaying = false;
    _position = Duration.zero;
    _duration = track.duration;
    notifyListenersSafe();
    // Here rather than in initState, which is too early to read the
    // translation the notification channel is named with.
    _playback.attach(this, channelName: channelName);
    _playback.updateTrack(track, _duration);
    _playback.updateState(
      playing: false,
      position: Duration.zero,
      loading: true,
    );

    VideoPlayerController? controller;
    try {
      final mediaStreamUrl = await _resolveStream(track.streamUrl);
      if (!_isCurrentPlay(generation)) return;
      if (mediaStreamUrl.isEmpty) {
        throw Exception('Could not resolve playable dynamic media link');
      }

      // The plugin pauses itself when the app is backgrounded unless told
      // otherwise; the music carrying on is the point of a music player.
      controller = VideoPlayerController.networkUrl(
        Uri.parse(mediaStreamUrl),
        videoPlayerOptions: VideoPlayerOptions(allowBackgroundPlayback: true),
      );
      await controller.initialize();
      if (!_isCurrentPlay(generation)) {
        await controller.dispose();
        return;
      }
      _audioController = controller;
      _duration = controller.value.duration;
      await controller.play();
      _isPlaying = true;
      unawaited(_setWakelock(true));
      _playback.updateTrack(track, _duration);
      _playback.updateState(playing: true, position: Duration.zero);

      controller.addListener(_videoPlayerListener);
      _startPositionTimer();
    } catch (e, st) {
      if (!_isCurrentPlay(generation)) {
        // Superseded while it failed: the player it half opened is nobody's.
        if (controller != _audioController) await controller?.dispose();
        return;
      }
      logger.e(
        'MusicViewModel playTrack network failure',
        error: e,
        stackTrace: st,
      );
      _isPlaying = false;
      unawaited(_setWakelock(false));
      _playback.updateState(playing: false, position: Duration.zero);
    }
    notifyListenersSafe();
  }

  void _videoPlayerListener() {
    final controller = _audioController;
    if (controller == null) return;

    if (controller.value.isCompleted) {
      if (_isRepeatEnabled) {
        seekTo(Duration.zero);
        controller.play();
      } else {
        // Released here rather than only where playback fails: with nothing
        // left in the queue the track that just ended is the last one, and the
        // lock would outlive the music. [playTrack] takes it again for a queue
        // that does have a next track.
        _isPlaying = false;
        unawaited(_setWakelock(false));
        nextTrack();
      }
    }
  }

  void _startPositionTimer() {
    _positionTimer?.cancel();
    _positionTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      final controller = _audioController;
      if (controller != null && controller.value.isInitialized) {
        _position = controller.value.position;
        notifyListenersSafe();
      }
    });
  }

  void togglePlay() {
    final controller = _audioController;
    if (controller == null || !controller.value.isInitialized) return;

    if (controller.value.isPlaying) {
      controller.pause();
      _isPlaying = false;
    } else {
      controller.play();
      _isPlaying = true;
    }
    _onPlayingChanged(controller);
  }

  void _onPlayingChanged(VideoPlayerController controller) {
    unawaited(_setWakelock(_isPlaying));
    _playback.updateState(
      playing: _isPlaying,
      position: controller.value.position,
    );
    notifyListenersSafe();
  }

  @override
  void resume() {
    final controller = _audioController;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.isPlaying) return;
    controller.play();
    _isPlaying = true;
    _onPlayingChanged(controller);
  }

  @override
  void pause() {
    final controller = _audioController;
    if (controller == null || !controller.value.isInitialized) return;
    if (!controller.value.isPlaying) return;
    controller.pause();
    _isPlaying = false;
    _onPlayingChanged(controller);
  }

  /// The notification's stop: the track is paused where it is, so opening the
  /// app again finds it ready to carry on.
  @override
  void stopPlayback() => pause();

  @override
  void nextTrack() {
    List<MusicTrack> currentList = [];
    switch (_currentTab) {
      case MusicTab.home:
        currentList = discoverTracks;
        break;
      case MusicTab.search:
        currentList = _searchResults;
        break;
      case MusicTab.likes:
        currentList = _likedTracks;
        break;
      case MusicTab.history:
        currentList = _historyTracks;
        break;
    }
    if (currentList.isEmpty) currentList = discoverTracks;

    if (currentList.isEmpty) return;
    if (_isShuffleEnabled) {
      final randomIndex = Random().nextInt(currentList.length);
      playTrack(currentList[randomIndex]);
      return;
    }

    final currentIndex = currentList.indexWhere(
      (t) => t.id == _currentTrack?.id,
    );
    final nextIndex = (currentIndex + 1) % currentList.length;
    playTrack(currentList[nextIndex]);
  }

  @override
  void previousTrack() {
    List<MusicTrack> currentList = [];
    switch (_currentTab) {
      case MusicTab.home:
        currentList = discoverTracks;
        break;
      case MusicTab.search:
        currentList = _searchResults;
        break;
      case MusicTab.likes:
        currentList = _likedTracks;
        break;
      case MusicTab.history:
        currentList = _historyTracks;
        break;
    }
    if (currentList.isEmpty) currentList = discoverTracks;

    if (currentList.isEmpty) return;
    final currentIndex = currentList.indexWhere(
      (t) => t.id == _currentTrack?.id,
    );
    var prevIndex = currentIndex - 1;
    if (prevIndex < 0) prevIndex = currentList.length - 1;
    playTrack(currentList[prevIndex]);
  }

  void toggleRepeat() {
    _isRepeatEnabled = !_isRepeatEnabled;
    notifyListenersSafe();
  }

  void toggleShuffle() {
    _isShuffleEnabled = !_isShuffleEnabled;
    notifyListenersSafe();
  }

  @override
  void seekTo(Duration position) {
    final controller = _audioController;
    if (controller == null || !controller.value.isInitialized) return;
    controller.seekTo(position);
    _position = position;
    _playback.updateState(playing: _isPlaying, position: position);
    notifyListenersSafe();
  }

  /// Holds the television's screen on while a track plays, the way the channel
  /// player does.
  ///
  /// Only a television: an album side is half an hour nobody touches the
  /// remote for, and the set goes to standby over it — while on a phone a
  /// screen that will not turn off during music is a battery complaint, not a
  /// feature. Failures are logged and swallowed: a platform without a wakelock
  /// is no reason to stop the music.
  Future<void> _setWakelock(bool enabled) async {
    if (!deviceType.isTv) return;
    try {
      if (enabled) {
        await WakelockPlus.enable();
      } else {
        await WakelockPlus.disable();
      }
    } on Object catch (e) {
      logger.d('MusicViewModel wakelock failed: $e');
    }
  }

  @override
  void dispose() {
    // Never left behind: the page can go away mid-track, and a lock still held
    // is a television that never sleeps again.
    unawaited(_setWakelock(false));
    // Any track still loading finds this and drops its player.
    _playGeneration++;
    musicAuth.removeListener(_onAccountChanged);
    _playback.detach(this);
    _positionTimer?.cancel();
    _debounceTimer?.cancel();
    _audioController?.removeListener(_videoPlayerListener);
    _audioController?.dispose();
    super.dispose();
  }
}
