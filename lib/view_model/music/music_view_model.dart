import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/model/music_shelf.dart';
import 'package:do_x/model/music_track.dart';
import 'package:do_x/model/music_video.dart';
import 'package:do_x/services/music_auth_service.dart';
import 'package:do_x/services/music_playback_session.dart';
import 'package:do_x/services/music_service.dart';
import 'package:do_x/services/music_video_matcher.dart';
import 'package:do_x/services/storage_service.dart';
import 'package:do_x/services/youtube_music_service.dart';
import 'package:do_x/utils/device_type.dart';
import 'package:do_x/utils/logger.dart';
import 'package:do_x/utils/video_view.dart';
import 'package:do_x/view_model/core/core_view_model.dart';

enum MusicTab { home, search, likes }

/// How a tap on a heart ended. A like is the one action on this page that
/// needs an account, so "you are not signed in" is an outcome of its own and
/// not just another failure. The bot protection's check is another: it is
/// the user, not the app, who can get past it.
enum MusicLikeOutcome { done, signInRequired, challengeRequired, failed }

class MusicViewModel extends CoreViewModel implements MusicPlaybackControls {
  MusicViewModel({
    Future<String> Function(String transcodingUrl)? resolveStream,
    MusicPlaybackSession? playback,
    Future<MusicVideo?> Function(MusicTrack track)? findVideo,
    Future<MusicVideo?> Function(MusicVideo video)? findHdVideo,
    Future<List<MusicShelf>> Function()? discoverShelves,
    bool? videoEnabled,
    Duration hdPictureGrace = const Duration(seconds: 3),
  }) : _hdPictureGrace = hdPictureGrace,
       _resolveStream = resolveStream ?? musicService.resolvePlayableStream,
       _playback = playback ?? musicPlayback,
       _findVideo = findVideo ?? youtubeMusicService.findVideo,
       _findHdVideo = findHdVideo ?? youtubeMusicService.withHd,
       _discoverShelves = discoverShelves ?? musicService.getDiscoverShelves,
       _isVideoEnabled = videoEnabled ?? storageService.getMusicVideoEnabled();

  /// Turns a track's transcoding link into one a player can open. Replaceable
  /// so a test can decide when each answer arrives.
  final Future<String> Function(String transcodingUrl) _resolveStream;

  /// Where the system's media controls are kept up to date.
  final MusicPlaybackSession _playback;

  /// Looks up the YouTube video that goes with a track. Replaceable so a test
  /// can hand one over without the network.
  final Future<MusicVideo?> Function(MusicTrack track) _findVideo;

  /// Adds the HD streams to a video found by [_findVideo], which takes
  /// longer. Replaceable for the same reason.
  final Future<MusicVideo?> Function(MusicVideo video) _findHdVideo;

  /// Fetches the Discover rows. Replaceable so a test can hand some over
  /// without the network.
  final Future<List<MusicShelf>> Function() _discoverShelves;

  /// How long a track's start waits to learn whether it has an official
  /// video, whose sound would be played instead — in HD if that is in by
  /// then. A video that turns up later is still shown, muted over the
  /// track's own sound.
  static const _officialVideoWait = Duration(seconds: 4);

  /// How long the 360p picture, once found, waits for the HD one before it
  /// goes up. The HD lookup usually lands within a second of it, and a
  /// picture that comes up in HD beats one that sharpens a few seconds in.
  /// Replaceable so a test need not sit through it.
  final Duration _hdPictureGrace;

  /// How far a muted video may wander from the sound before it is jumped
  /// back with a seek, and how long it is then left alone: a seek takes a
  /// moment to land, and pulling it back again before it has would only
  /// make it stutter.
  ///
  /// Large on purpose. A seek stops the picture while it decodes its way
  /// from the keyframe before, and at 350ms a television — slower to decode,
  /// its position read a poll late — sought every two seconds and the video
  /// jerked all the way through. A smaller drift is played away instead:
  /// see [_videoCatchUpDrift].
  static const _maxVideoDrift = Duration(milliseconds: 1500);
  static const _videoResyncPause = Duration(seconds: 3);

  /// How far a picture laid over the track's own sound may wander before it
  /// is jumped back. That picture is another upload, often another cut, and
  /// was never in step to the frame: only a stall that has left it well
  /// behind is worth the visible jump.
  static const _maxLooseVideoDrift = Duration(seconds: 5);

  /// How far ahead of the sound a new picture is sought: the sound plays on
  /// while the picture buffers its way there.
  static const _videoSeekLead = Duration(milliseconds: 500);

  /// A drift past which the muted picture runs a little fast or slow until
  /// it is back within [_videoInStepDrift] — unseen, where a seek is a
  /// visible jump.
  ///
  /// Only for the official video, whose sound is the one playing, where lips
  /// out of step show. A picture at 1.08× on a 60Hz screen shows its frames
  /// unevenly, and over a track's own sound — another upload, often another
  /// cut — the steadier picture is worth more than the tighter fit.
  static const _videoCatchUpDrift = Duration(milliseconds: 200);
  static const _videoInStepDrift = Duration(milliseconds: 60);
  static const _videoCatchUpSpeed = 0.08;

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

  /// The likes tab has not been fetched for the account signed in now, so
  /// opening it fetches it. Once it has, a heart tapped here keeps it up to
  /// date by itself, and only a refresh asks the service again.
  bool _likedTracksStale = true;

  MusicTab _currentTab = MusicTab.home;
  MusicTab get currentTab => _currentTab;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  MusicTrack? _currentTrack;
  MusicTrack? get currentTrack => _currentTrack;

  VideoPlayerController? _audioController;
  VideoPlayerController? get audioController => _audioController;

  bool _isVideoEnabled;
  bool get isVideoEnabled => _isVideoEnabled;

  /// The player whose picture is on screen: [audioController] itself when the
  /// sound comes from the video ([isAudioFromVideo]), otherwise a muted one
  /// kept in step with it.
  VideoPlayerController? _videoController;

  /// What to show for the current track, or null for its artwork.
  VideoPlayerController? get videoController =>
      _isVideoEnabled ? _videoController : null;

  bool _isAudioFromVideo = false;

  /// The track is being played from its official video, sound and all.
  bool get isAudioFromVideo => _isAudioFromVideo;

  /// The video found for the current track, whether or not it is shown.
  MusicVideo? _foundVideo;

  /// The current track has a video to show. Looked up whether the video is
  /// on or off, so the switch is offered only for a track that has one.
  bool get hasVideo => _foundVideo != null;

  bool _isFindingVideo = false;

  /// The current track's video is still being looked for.
  bool get isFindingVideo => _isFindingVideo;

  bool _isPreparingPicture = false;

  /// The current track's picture may still be on its way: looked for, or
  /// found and opening. A full-screen video waits this out across a skip
  /// rather than closing in the gap — the lookup can answer before the
  /// picture it found has opened.
  bool get isVideoPending => _isFindingVideo || _isPreparingPicture;

  DateTime _lastVideoResync = DateTime(0);

  /// Whether the page is the one on screen. Its tab is kept alive once
  /// visited, so it can be behind another tab, or covered by a page pushed
  /// over it, with the music still playing.
  bool _isPageVisible = true;

  /// Tells the page's players whether anyone can see them. Only the muted
  /// picture cares: out of sight it is paused, as it is with the app in the
  /// background, while the sound plays on.
  void setPageVisible(bool visible) {
    if (_isPageVisible == visible) return;
    _isPageVisible = visible;
    _syncVideo();
  }

  /// The rate the muted picture was last set to play at while it catches up.
  double _videoSpeed = 1;

  /// The stream [_videoController] shows, so the HD picture replaces the
  /// 360p one and never the other way round.
  String? _pictureUrl;

  /// The picture is a looped stand-in, which follows the sound's play and
  /// pause but not its position — see [MusicVideo.loops].
  bool _pictureLoops = false;

  /// Bumped by every change of picture: an older one still opening finds it
  /// moved on and lets its player go.
  int _pictureRequest = 0;

  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;

  /// Where the sound is, kept apart from the rest of the page's state: it
  /// moves twice a second, and only the seek bar and the times beside it
  /// need to hear of it — not the whole page, list and all.
  final _position = ValueNotifier(Duration.zero);
  Duration get position => _position.value;
  ValueListenable<Duration> get positionListenable => _position;

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

  /// Where the last seek was sent, and when. A seek takes a moment to land,
  /// and until it has the player still reports where it was — which, written
  /// to [_position], would pull the seek bar's thumb back for a tick.
  Duration? _seekTarget;
  DateTime _seekSentAt = DateTime(0);

  /// How long a seek is waited for before the player's own position is
  /// believed again, and how near the target counts as landed.
  static const _seekLandWait = Duration(seconds: 2);
  static const _seekLandedWithin = Duration(seconds: 1);

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
  /// whichever one is open, and the other the next time it is opened.
  void _onAccountChanged() {
    _likedTracksStale = true;
    if (_currentTab == MusicTab.likes) {
      loadLikedTracks();
    } else {
      notifyListenersSafe();
    }
  }

  void switchTab(MusicTab tab) {
    _currentTab = tab;
    if (tab == MusicTab.likes && _likedTracksStale) {
      loadLikedTracks();
    }
    notifyListenersSafe();
  }

  /// Fetches the open tab again: the page's tab tapped once more at the top
  /// of its list, or switched back to.
  Future<void> onRefresh() async {
    switch (_currentTab) {
      case MusicTab.home:
        await loadHomeData();
      case MusicTab.search:
        if (_searchQuery.isNotEmpty) await searchTracks(_searchQuery);
      case MusicTab.likes:
        await loadLikedTracks();
    }
  }

  Future<void> loadHomeData() async {
    // Heading for the one row built from a plain search, for an account the
    // service has no selections for. Read before the first await, while the
    // page is certainly still there.
    final fallbackTitle = context.l10n.musicShelfTrending;
    _isLoading = true;
    notifyListenersSafe();
    try {
      // The hearts come along with the rows: a liked track has to look liked
      // wherever it turns up, not only in the likes tab. Asked for together,
      // as neither needs the other's answer.
      final (_, shelves) = await (
        musicService.loadLikedTrackIds(),
        _discoverShelves(),
      ).wait;
      _shelves = shelves;
      // An account the service has nothing personal for still gets a page.
      if (_shelves.isEmpty) {
        final tracks = await musicService.searchTracks('');
        if (tracks.isNotEmpty) {
          _shelves = [MusicShelf(title: fallbackTitle, tracks: tracks)];
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
      _likedTracksStale = false;
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

  Future<void> searchTracks(String query) async {
    _searchQuery = query;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), () async {
      _isLoading = true;
      notifyListenersSafe();
      try {
        final results = await musicService.searchTracks(query);
        // Typed over while it was on its way: the newer search's answer is
        // the one to show, and this one could land after it.
        if (query != _searchQuery) return;
        _searchResults = results;
      } catch (e, st) {
        logger.e(
          'MusicViewModel searchTracks failed',
          error: e,
          stackTrace: st,
        );
      } finally {
        // A superseded search leaves the spinner to the one after it.
        if (query == _searchQuery) {
          _isLoading = false;
          notifyListenersSafe();
        }
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
    // The likes tab follows the heart without asking the service for the
    // whole list again: the change is the one just accepted.
    if (musicService.isTrackLiked(track.id)) {
      if (!_likedTracks.any((t) => t.id == track.id)) {
        _likedTracks = [track, ..._likedTracks];
      }
    } else {
      _likedTracks = [
        for (final t in _likedTracks)
          if (t.id != track.id) t,
      ];
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
    // Only waited on when there is something to let go of: with nothing
    // playing, the stream is asked for before this call first yields, so a
    // second tap cannot get in ahead of it.
    if (_audioController != null || _videoController != null) {
      await _releasePlayers();
      if (!_isCurrentPlay(generation)) return;
    }

    _currentTrack = track;
    _isPlaying = false;
    _seekTarget = null;
    _position.value = Duration.zero;
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

    // All asked for at once: the video is a search and a manifest away, and
    // the track's own stream should not queue up behind it. The 360p picture
    // is quick; HD takes longer and replaces it when it comes.
    final streamFuture = _resolveStream(
      track.streamUrl,
    ).catchError((Object _) => '');
    final videoFuture = _findVideoSafely(track);
    final hdFuture = videoFuture.then(
      (video) => video == null ? null : _findHdSafely(video),
    );
    // Counted from when the 360p picture is found, not from when pictures
    // start going up, which is after the wait for an official sound.
    final hdInTime = videoFuture.then(
      (video) => video == null ? null : _within(hdFuture, _hdPictureGrace),
    );
    _foundVideo = null;
    _isFindingVideo = true;
    _isPreparingPicture = false;
    void found(MusicVideo? video, {required bool last}) {
      if (!_isCurrentPlay(generation)) return;
      if (video != null && video.isPlayable) _foundVideo = video;
      if (last) _isFindingVideo = false;
      notifyListenersSafe();
    }

    unawaited(videoFuture.then((video) => found(video, last: false)));
    unawaited(hdFuture.then((video) => found(video, last: true)));

    VideoPlayerController? controller;
    try {
      // An official video brings the sound with it, so where the sound comes
      // from has to be settled before anything plays.
      final early = _isVideoEnabled
          ? await _videoWithin(videoFuture, hdFuture, _officialVideoWait)
          : null;
      if (!_isCurrentPlay(generation)) return;
      MusicVideo? official;
      // Set when the sound is the muxed stream, which is its own picture.
      String? soundPicture;
      if (early != null && early.carriesAudio) {
        // The HD sound first, with the HD picture laid over it; then the
        // muxed stream, which is sound and picture in one.
        final hdAudio = early.hdAudioUrl;
        if (hdAudio != null) {
          controller = await _tryOpen(
            hdAudio,
            background: true,
            hasPicture: false,
            headers: early.hdHeaders,
          );
        }
        final muxed = early.muxedUrl;
        if (controller == null && muxed != null) {
          controller = await _tryOpen(
            muxed,
            background: true,
            hasPicture: true,
          );
          if (controller != null) soundPicture = muxed;
        }
        if (controller != null) official = early;
        if (!_isCurrentPlay(generation)) {
          await controller?.dispose();
          return;
        }
      }

      if (controller == null) {
        final mediaStreamUrl = await streamFuture;
        if (!_isCurrentPlay(generation)) return;
        if (mediaStreamUrl.isEmpty) {
          throw Exception('Could not resolve playable dynamic media link');
        }
        controller = await _openPlayer(
          mediaStreamUrl,
          background: true,
          hasPicture: false,
        );
        if (!_isCurrentPlay(generation)) {
          await controller.dispose();
          return;
        }
      }

      _audioController = controller;
      _isAudioFromVideo = official != null;
      if (soundPicture != null) {
        _videoController = controller;
        _pictureUrl = soundPicture;
      }
      _duration = controller.value.duration;
      await controller.play();
      _isPlaying = true;
      unawaited(_setWakelock(true));
      _playback.updateTrack(track, _duration);
      _playback.updateState(playing: true, position: Duration.zero);

      controller.addListener(_videoPlayerListener);
      _startPositionTimer();
      unawaited(
        _attachPictures(
          official != null ? Future.value(official) : videoFuture,
          hdFuture,
          hdInTime,
          generation,
        ),
      );
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

  /// The best video known by the time [wait] is up: the HD one if it is in,
  /// otherwise the 360p one if that is.
  Future<MusicVideo?> _videoWithin(
    Future<MusicVideo?> basic,
    Future<MusicVideo?> hd,
    Duration wait,
  ) async {
    MusicVideo? basicSoFar;
    unawaited(basic.then((video) => basicSoFar = video));
    final deadline = Future<MusicVideo?>.delayed(wait);
    final best = await Future.any([hd, deadline]);
    if (best != null) return best;
    // HD came back empty before the deadline, or not at all: the 360p one
    // may still arrive in the time left.
    return basicSoFar ?? await Future.any([basic, deadline]);
  }

  /// Stops and lets go of the current players. Taken off the fields before
  /// they are waited on: a tap that lands during the wait must not find them
  /// still here and stop them a second time.
  Future<void> _releasePlayers() async {
    final audio = _audioController;
    final video = _videoController;
    _audioController = null;
    _videoController = null;
    _pictureUrl = null;
    _pictureLoops = false;
    _videoSpeed = 1;
    _pictureRequest++;
    _isAudioFromVideo = false;
    if (audio != null) {
      audio.removeListener(_videoPlayerListener);
      await audio.pause();
      await audio.dispose();
    }
    if (video != null && !identical(video, audio)) await video.dispose();
  }

  /// The player for [url], ready to play, or an error — never a half-opened
  /// player left for nobody to dispose of.
  ///
  /// [background] keeps it going once the app has left the screen, which is
  /// what the sound wants and what a muted picture must not do: nobody is
  /// watching it, and it would spend data and battery on nothing.
  ///
  /// [hasPicture] says the stream carries a picture to show. Only such a
  /// stream may go to a platform view: Android's platform-view player reads
  /// the video format as it opens and crashes the app on a stream of sound
  /// alone, which has none.
  Future<VideoPlayerController> _openPlayer(
    String url, {
    required bool background,
    required bool hasPicture,
    Map<String, String> headers = const {},
  }) async {
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(url),
      httpHeaders: headers,
      videoPlayerOptions: VideoPlayerOptions(
        allowBackgroundPlayback: background,
        // A muted picture must not take Android's audio focus: every player
        // asks for it on play unless told to mix, and the sound playing lost
        // it and stopped the moment the video came up. Android only — on iOS
        // the flag changes the whole app's audio session, and a mixing
        // session loses the lock-screen controls.
        mixWithOthers:
            !background && defaultTargetPlatform == TargetPlatform.android,
      ),
      viewType: hasPicture ? pictureViewType : VideoViewType.textureView,
    );
    try {
      await controller.initialize();
    } on Object {
      // Not waited on: a player the platform refused to create never finishes
      // disposing.
      unawaited(controller.dispose());
      rethrow;
    }
    return controller;
  }

  Future<MusicVideo?> _findVideoSafely(MusicTrack track) =>
      _findVideo(track).catchError((Object _) => null);

  Future<MusicVideo?> _findHdSafely(MusicVideo video) =>
      _findHdVideo(video).catchError((Object _) => null);

  /// [_openPlayer], with a stream that will not open answered by null.
  Future<VideoPlayerController?> _tryOpen(
    String url, {
    required bool background,
    required bool hasPicture,
    Map<String, String> headers = const {},
  }) async {
    try {
      return await _openPlayer(
        url,
        background: background,
        hasPicture: hasPicture,
        headers: headers,
      );
    } on Object catch (e) {
      logger.d('[MusicVideo] stream would not open: $e');
      if (headers.isEmpty) return null;
      // Only the HD streams carry headers. Tried once more without them: a
      // player may not take a User-Agent of someone else's.
      try {
        return await _openPlayer(
          url,
          background: background,
          hasPicture: hasPicture,
        );
      } on Object catch (e) {
        logger.d('[MusicVideo] stream would not open without headers: $e');
        return null;
      }
    }
  }

  /// Puts the picture up: the HD one where [hdInTime] has it, otherwise the
  /// 360p one as soon as there is one, with the HD one swapped in when it
  /// arrives.
  Future<void> _attachPictures(
    Future<MusicVideo?> basic,
    Future<MusicVideo?> hd,
    Future<MusicVideo?> hdInTime,
    int generation,
  ) async {
    _isPreparingPicture = true;
    MusicVideo? shownHd;
    try {
      final first = await basic;
      // The HD one straight away where it comes in time; it falls back to
      // the 360p stream by itself if its own will not open.
      final early = first == null ? null : await hdInTime;
      if (early?.hdVideoUrl != null) {
        shownHd = early;
        await _showPicture(early!, generation);
      } else if (first != null) {
        await _showPicture(first, generation);
      }
    } finally {
      // The first picture is up, or there is none: from here the HD one only
      // replaces it.
      if (_isCurrentPlay(generation)) {
        _isPreparingPicture = false;
        notifyListenersSafe();
      }
    }
    if (shownHd != null) return;
    final better = await hd;
    if (better != null) await _showPicture(better, generation);
  }

  /// What [future] comes back with inside [wait], or null after it.
  static Future<T?> _within<T>(Future<T?> future, Duration wait) {
    final result = Completer<T?>();
    final timer = Timer(wait, () {
      if (!result.isCompleted) result.complete(null);
    });
    future.then(
      (value) {
        timer.cancel();
        if (!result.isCompleted) result.complete(value);
      },
      onError: (Object _) {
        timer.cancel();
        if (!result.isCompleted) result.complete(null);
      },
    );
    return result.future;
  }

  /// Lays [video]'s best picture, muted, over the sound already playing —
  /// the HD one if it opens, the 360p one if not — unless what is on screen
  /// is already as good.
  ///
  /// Not one shorter than the sound, or the picture would run out before the
  /// music does. The official video the sound itself comes from passes by
  /// construction.
  Future<void> _showPicture(MusicVideo video, int generation) async {
    if (!_canShowPicture(generation)) return;
    // The stream's own length where it gave one; the listing's otherwise.
    final length = _duration > Duration.zero
        ? _duration
        : _currentTrack?.duration ?? Duration.zero;
    if (!_isAudioFromVideo &&
        !video.loops &&
        video.duration + MusicVideoMatcher.lengthSlack < length) {
      return;
    }

    final shown = _pictureUrl;
    final urls = video.pictureUrls;
    // Only better than what is up: everything before it in the list.
    final candidates = shown == null || !urls.contains(shown)
        ? urls
        : urls.sublist(0, urls.indexOf(shown));
    if (candidates.isEmpty) return;

    final request = ++_pictureRequest;
    for (final url in candidates) {
      final follower = await _tryOpen(
        url,
        background: false,
        hasPicture: true,
        headers: video.headersFor(url),
      );
      if (follower == null) continue;
      if (!_canShowPicture(generation) || request != _pictureRequest) {
        await follower.dispose();
        return;
      }
      await follower.setVolume(0);
      if (video.loops) await follower.setLooping(true);
      final sound = _audioController;
      if (!video.loops && sound != null) {
        // Put in place while still paused and off screen. Sought once it was
        // playing, a 1080p picture on a television stalled while it decoded
        // its way there from the keyframe before, came up behind the sound,
        // and was pulled about for seconds after.
        await follower.seekTo(sound.value.position + _videoSeekLead);
        if (!_canShowPicture(generation) || request != _pictureRequest) {
          await follower.dispose();
          return;
        }
      }
      final old = _videoController;
      _videoController = follower;
      _pictureUrl = url;
      _pictureLoops = video.loops;
      _videoSpeed = 1;
      if (old != null && !identical(old, _audioController)) {
        unawaited(old.dispose());
      }
      // Left alone while the seek above lands.
      _lastVideoResync = DateTime.now();
      _syncVideo();
      notifyListenersSafe();
      return;
    }
  }

  bool _canShowPicture(int generation) =>
      _isCurrentPlay(generation) && _isVideoEnabled && _audioController != null;

  /// Keeps a muted video with the sound: playing when it plays, paused when
  /// it pauses, and pulled back to it when the two have drifted apart.
  ///
  /// Paused while the app or the page is off screen, whatever the sound is
  /// doing, and
  /// left on its last frame once the sound has run past its end. A looped
  /// stand-in only follows play and pause: it has no place in the song.
  void _syncVideo() {
    final video = _videoController;
    final audio = _audioController;
    if (video == null || audio == null || identical(video, audio)) return;
    if (!video.value.isInitialized || !audio.value.isInitialized) return;

    final lifecycle = WidgetsBinding.instance.lifecycleState;
    final onScreen =
        _isPageVisible &&
        (lifecycle == null || lifecycle == AppLifecycleState.resumed);
    final position = audio.value.position;
    final withinVideo = _pictureLoops || position < video.value.duration;
    final shouldPlay = onScreen && audio.value.isPlaying && withinVideo;
    if (shouldPlay != video.value.isPlaying) {
      unawaited(shouldPlay ? video.play() : video.pause());
    }
    if (!onScreen || !withinVideo || _pictureLoops) return;

    final now = DateTime.now();
    final ahead = video.value.position - position;
    final drift = ahead.abs();
    final maxDrift = _isAudioFromVideo ? _maxVideoDrift : _maxLooseVideoDrift;
    if (drift > maxDrift &&
        now.difference(_lastVideoResync) > _videoResyncPause) {
      logger.d('[MusicVideo] picture ${ahead.inMilliseconds}ms off, seeking');
      _lastVideoResync = now;
      _setVideoSpeed(video, 1);
      unawaited(video.seekTo(position));
      return;
    }
    // Still landing from the last seek: its position means nothing yet.
    if (now.difference(_lastVideoResync) < _videoResyncPause) return;
    if (!_isAudioFromVideo) return;
    if (drift > _videoCatchUpDrift) {
      _setVideoSpeed(
        video,
        ahead.isNegative ? 1 + _videoCatchUpSpeed : 1 - _videoCatchUpSpeed,
      );
    } else if (drift < _videoInStepDrift) {
      _setVideoSpeed(video, 1);
    }
  }

  void _setVideoSpeed(VideoPlayerController video, double speed) {
    if (_videoSpeed == speed) return;
    _videoSpeed = speed;
    unawaited(video.setPlaybackSpeed(speed));
  }

  /// Shows or hides the video. A hidden muted video is let go of — it would
  /// go on costing data for a picture nobody sees — while one that carries
  /// the sound keeps playing, just out of sight. Turned back on mid-track,
  /// the video already found is laid over the sound playing.
  void toggleVideo() {
    _isVideoEnabled = !_isVideoEnabled;
    unawaited(storageService.setMusicVideoEnabled(_isVideoEnabled));
    final video = _videoController;
    if (!_isVideoEnabled) {
      _pictureRequest++;
      if (video != null && !identical(video, _audioController)) {
        _videoController = null;
        _pictureUrl = null;
        _pictureLoops = false;
        unawaited(video.dispose());
      }
    } else {
      final found = _foundVideo;
      if (found != null && _audioController != null) {
        unawaited(_showPicture(found, _playGeneration));
      }
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
        final position = controller.value.position;
        final target = _seekTarget;
        // A seek still on its way leaves the bar where the seek put it.
        final seeking =
            target != null &&
            (position - target).abs() > _seekLandedWithin &&
            DateTime.now().difference(_seekSentAt) < _seekLandWait;
        if (!seeking) {
          _seekTarget = null;
          _position.value = position;
        }
        _syncVideo();
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
    _syncVideo();
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

  /// The list next and previous walk: the one a track was last picked
  /// from, as it stood then. A snapshot, so a refresh of the list on screen —
  /// the tab switched back to, a new search — does not swap the queue out
  /// under the track playing.
  List<MusicTrack> _queue = const [];

  /// The list the open tab shows, falling back to Discover when it is empty.
  List<MusicTrack> get _tabTracks {
    final tracks = switch (_currentTab) {
      MusicTab.home => discoverTracks,
      MusicTab.search => _searchResults,
      MusicTab.likes => _likedTracks,
    };
    return tracks.isEmpty ? discoverTracks : tracks;
  }

  /// Plays [track] as picked from the open tab's list, which becomes the
  /// queue from here on.
  Future<void> playFromList(MusicTrack track) {
    _queue = List.unmodifiable(_tabTracks);
    return playTrack(track);
  }

  /// The queue, or the open tab's list for a track that was not picked from
  /// one.
  List<MusicTrack> get _playQueue => _queue.isEmpty ? _tabTracks : _queue;

  @override
  void nextTrack() {
    final currentList = _playQueue;
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
    final currentList = _playQueue;
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
    _seekTarget = position;
    _seekSentAt = DateTime.now();
    // Nothing else on the page moves with a seek: the bar and the times
    // beside it hear of it through [positionListenable], and the rest of the
    // page is not rebuilt for it.
    _position.value = position;
    final video = _videoController;
    if (video != null && !identical(video, controller) && !_pictureLoops) {
      _lastVideoResync = DateTime.now();
      _setVideoSpeed(video, 1);
      unawaited(video.seekTo(position));
    }
    _playback.updateState(playing: _isPlaying, position: position);
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
    final audio = _audioController;
    final video = _videoController;
    audio?.removeListener(_videoPlayerListener);
    audio?.dispose();
    if (video != null && !identical(video, audio)) video.dispose();
    _position.dispose();
    super.dispose();
  }
}
