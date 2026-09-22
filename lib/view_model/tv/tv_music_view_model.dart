import 'dart:async';
import 'dart:math';
import 'package:video_player/video_player.dart';
import 'package:do_x/model/music_track.dart';
import 'package:do_x/services/music_auth_service.dart';
import 'package:do_x/services/music_service.dart';
import 'package:do_x/utils/logger.dart';
import 'package:do_x/view_model/core/core_view_model.dart';

enum MusicTab { home, search, likes, history }

/// How a tap on a heart ended. A like is the one action on this page that
/// needs an account, so "you are not signed in" is an outcome of its own and
/// not just another failure.
enum MusicLikeOutcome { done, signInRequired, failed }

class TvMusicViewModel extends CoreViewModel {
  List<MusicTrack> _trendingTracks = [];
  List<MusicTrack> get trendingTracks => _trendingTracks;

  List<MusicTrack> _recommendedTracks = [];
  List<MusicTrack> get recommendedTracks => _recommendedTracks;

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
      final results = await Future.wait([
        musicService.getTrendingTracks(),
        musicService.getMoreOfWhatYouLike(),
      ]);
      _trendingTracks = results[0];
      _recommendedTracks = results[1];
    } catch (e, st) {
      logger.e(
        'TvMusicViewModel loadHomeData failed',
        error: e,
        stackTrace: st,
      );
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
        'TvMusicViewModel loadLikedTracks failed',
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
        'TvMusicViewModel loadHistoryTracks failed',
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
          'TvMusicViewModel searchTracks failed',
          error: e,
          stackTrace: st,
        );
      } finally {
        _isLoading = false;
        notifyListenersSafe();
      }
    });
  }

  Future<MusicLikeOutcome> toggleLike(MusicTrack track) async {
    try {
      await musicService.toggleLikeTrack(track);
    } on MusicSignInRequired {
      return MusicLikeOutcome.signInRequired;
    } catch (e, st) {
      logger.e('TvMusicViewModel toggleLike failed', error: e, stackTrace: st);
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

  Future<void> playTrack(MusicTrack track) async {
    if (_currentTrack?.id == track.id && _audioController != null) {
      togglePlay();
      return;
    }

    _positionTimer?.cancel();
    final oldController = _audioController;
    if (oldController != null) {
      await oldController.pause();
      await oldController.dispose();
    }

    _currentTrack = track;
    _isPlaying = false;
    _position = Duration.zero;
    _duration = track.duration;
    notifyListenersSafe();

    try {
      final mediaStreamUrl = await musicService.resolvePlayableStream(
        track.streamUrl,
      );
      if (mediaStreamUrl.isEmpty) {
        throw Exception('Could not resolve playable dynamic media link');
      }

      final controller = VideoPlayerController.networkUrl(
        Uri.parse(mediaStreamUrl),
      );
      _audioController = controller;

      await controller.initialize();
      _duration = controller.value.duration;
      await controller.play();
      _isPlaying = true;

      controller.addListener(_videoPlayerListener);
      _startPositionTimer();
    } catch (e, st) {
      logger.e(
        'TvMusicViewModel playTrack network failure',
        error: e,
        stackTrace: st,
      );
      _isPlaying = false;
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
    notifyListenersSafe();
  }

  void nextTrack() {
    List<MusicTrack> currentList = [];
    switch (_currentTab) {
      case MusicTab.home:
        currentList = _trendingTracks;
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
    if (currentList.isEmpty) currentList = _trendingTracks;

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

  void previousTrack() {
    List<MusicTrack> currentList = [];
    switch (_currentTab) {
      case MusicTab.home:
        currentList = _trendingTracks;
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
    if (currentList.isEmpty) currentList = _trendingTracks;

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

  void seekTo(Duration position) {
    final controller = _audioController;
    if (controller == null || !controller.value.isInitialized) return;
    controller.seekTo(position);
    _position = position;
    notifyListenersSafe();
  }

  @override
  void dispose() {
    musicAuth.removeListener(_onAccountChanged);
    _positionTimer?.cancel();
    _debounceTimer?.cancel();
    _audioController?.removeListener(_videoPlayerListener);
    _audioController?.dispose();
    super.dispose();
  }
}
