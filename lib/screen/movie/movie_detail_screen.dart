import 'dart:async';
import 'dart:math' as math;

import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:do_x/constants/dimens.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/model/movie_model.dart';
import 'package:do_x/router/app_router.gr.dart';
import 'package:do_x/screen/core/screen_state.dart';
import 'package:do_x/screen/movie/movie_detail_body.dart';
import 'package:do_x/screen/movie/movie_detail_controller.dart';
import 'package:do_x/screen/movie/movie_player_controls.dart';
import 'package:do_x/screen/movie/movie_player_layout.dart';
import 'package:do_x/screen/movie/movie_settings_sheet.dart';
import 'package:do_x/screen/movie/movie_thumbnail_track.dart';
import 'package:do_x/services/movie_service.dart';
import 'package:do_x/utils/device_type.dart';
import 'package:do_x/utils/logger.dart';
import 'package:do_x/view_model/movie/movie_detail_view_model.dart';
import 'package:do_x/widgets/app_bar/app_bar_base.dart';
import 'package:do_x/widgets/app_scaffold.dart';
import 'package:do_x/widgets/dialog/app_modal.dart';
import 'package:do_x/widgets/focusable_tap.dart';
import 'package:do_x/widgets/loading.dart';
import 'package:do_x/widgets/neu/neu_button.dart';
import 'package:do_x/widgets/player_controls_focus.dart';
import 'package:do_x/widgets/tv_shell.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_orientation_manager/flutter_orientation_manager.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// How long playback may report itself as playing without the position moving
/// before the player is treated as wedged and rebuilt.
const _stallLimit = Duration(seconds: 12);

/// How long playback must run cleanly before the stall budget is handed back,
/// so a film that hiccups once an hour never runs out of retries.
const _healthyRunToForgiveStalls = Duration(seconds: 30);

/// Rebuild attempts for one wedged stream before the user is asked to retry.
const _maxRecoveryAttempts = 3;

@RoutePage()
class MovieDetailScreen extends StatefulScreen implements AutoRouteWrapper {
  final String movieUrl;
  final String movieId;
  final Movie? initialMovie;

  /// Rendered inside the YouTube-style overlay of `MovieScreen` instead of as a
  /// route of its own: no [Scaffold] chrome, and the layout collapses towards a
  /// mini player as [minimizeProgress] goes to 0.
  final bool embedded;

  /// 1 = fully expanded page, 0 = mini player bar. Only used when [embedded].
  final double minimizeProgress;

  final ValueChanged<bool>? onFullScreenChanged;
  final MovieDetailController? controller;

  /// Embedded mode never pushes a route for a related movie; the host swaps the
  /// movie it is showing instead.
  final ValueChanged<Movie>? onRelatedMovieTap;
  final VoidCallback? onClose;
  final VoidCallback? onMinimize;
  final GestureDragStartCallback? onPlayerDragStart;
  final GestureDragUpdateCallback? onPlayerDragUpdate;
  final GestureDragEndCallback? onPlayerDragEnd;

  const MovieDetailScreen({
    super.key,
    required this.movieUrl,
    required this.movieId,
    this.initialMovie,
    this.embedded = false,
    this.minimizeProgress = 1,
    this.onFullScreenChanged,
    this.controller,
    this.onRelatedMovieTap,
    this.onClose,
    this.onMinimize,
    this.onPlayerDragStart,
    this.onPlayerDragUpdate,
    this.onPlayerDragEnd,
  });

  @override
  Widget wrappedRoute(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => MovieDetailViewModel(),
      child: this,
    );
  }

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState
    extends ScreenState<MovieDetailScreen, MovieDetailViewModel> {
  late MovieDetailViewModel _vm;
  VideoPlayerController? _videoController;
  bool _isPlaying = false;
  bool _isFullScreen = false;
  double _playbackSpeed = 1.0;
  double _volume = 1.0;
  double _lastAudibleVolume = 1.0;
  bool _showVolumeControl = false;
  bool _showControls = true;
  Timer? _controlsTimer;
  Timer? _progressTimer;
  StreamSubscription<Orientation>? _orientationSubscription;
  final FocusNode _videoFocusNode = FocusNode(debugLabel: 'movie-video');

  /// The two control bars, named so the remote can be handed to them: they sit
  /// inside the video's own focus node, where directional traversal has no way
  /// to find them. See [PlayerControlsFocus].
  final FocusScopeNode _topControlsScope = FocusScopeNode(
    debugLabel: 'movie-top-controls',
  );
  final FocusScopeNode _bottomControlsScope = FocusScopeNode(
    debugLabel: 'movie-bottom-controls',
  );

  /// Whether the remote is resting on one of the control bars.
  bool get _controlsHaveFocus =>
      _topControlsScope.hasFocus || _bottomControlsScope.hasFocus;

  /// The seek bar as a control the remote can stand on. Scrubbing with a D-pad
  /// is a pending position the arrows move and OK commits, so the film does
  /// not re-buffer on every press of the key.
  final FocusNode _timelineFocusNode = FocusNode(debugLabel: 'movie-timeline');
  bool _isScrubbing = false;

  /// The episode grid laid over the picture in full screen, and the remote's
  /// place inside it.
  final FocusScopeNode _episodeOverlayScope = FocusScopeNode(
    debugLabel: 'movie-episode-overlay',
  );
  final FocusNode _currentEpisodeFocusNode = FocusNode(
    debugLabel: 'movie-episode-current',
  );
  final ScrollController _episodeOverlayController = ScrollController();
  bool _showEpisodeOverlay = false;

  /// Where the remote lands on the television's landing page.
  final FocusNode _tvPrimaryActionFocusNode = FocusNode(
    debugLabel: 'movie-tv-primary-action',
  );

  /// Television only: nothing plays until the viewer asks for it, so the page
  /// opens on the poster and its row of actions instead of on a film already
  /// running. Set by the first press that starts playback.
  bool _hasStartedPlayback = false;

  /// Set once the remote has been put on the landing page's first action, so
  /// a rebuild does not snatch it back from wherever the viewer moved it.
  bool _tvLandingFocusRequested = false;

  /// How many times the arrow being held has repeated, so a long press seeks
  /// further per step than a tap does.
  int _seekRepeatCount = 0;

  /// Anchors the volume popup to the volume button, whatever the bar layout is.
  final LayerLink _volumeButtonLink = LayerLink();
  VoidCallback? _videoValueListener;
  int _controllerGeneration = 0;

  bool _isSpeedBoosted = false;
  Offset? _doubleTapPosition;
  int _skipForwardValue = 0;
  int _skipBackwardValue = 0;
  Timer? _skipForwardTimer;
  Timer? _skipBackwardTimer;

  bool _isDragging = false;
  bool _isTimelineHovering = false;
  Duration _dragPosition = Duration.zero;
  double _dragFraction = 0;
  bool _resumeAfterDrag = false;
  ThumbnailCue? _hoverThumbnailCue;

  bool _isRotationLocked = false;
  bool _isPlayPauseKeyDown = false;
  Timer? _playPauseLongPressTimer;

  /// Every key that means "play/pause" on the hardware the player runs on: the
  /// space bar on a desktop keyboard, the OK button of a TV remote (which
  /// arrives as `select`, or as a game-pad button on some boxes), and the
  /// dedicated transport key when the remote has one.
  static final _playPauseKeys = <LogicalKeyboardKey>{
    LogicalKeyboardKey.space,
    LogicalKeyboardKey.select,
    LogicalKeyboardKey.enter,
    LogicalKeyboardKey.gameButtonA,
    LogicalKeyboardKey.mediaPlayPause,
  };
  Timer? _volumeHideTimer;

  /// Full screen only: `true` crops the video to cover the whole screen,
  /// `false` keeps the whole frame visible. Toggled by the button or a pinch.
  bool _isVideoCover = false;

  Duration? _virtualSeekPosition;
  Timer? _virtualSeekTimer;

  /// True while the platform player is refilling its buffer. Without this the
  /// frame simply freezes and a normal stall is indistinguishable from a dead
  /// player.
  bool _isBuffering = false;

  /// The stream the current controller was built from, so a stall can be
  /// recovered by rebuilding it at the position playback died at.
  String? _currentStreamUrl;

  /// Playback watchdog. An HLS stream that errors or stalls mid-play leaves the
  /// platform player wedged: the frame stops, `isPlaying` stays true and
  /// nothing ever recovers, which is why the app had to be killed.
  Timer? _watchdogTimer;
  Duration _watchdogPosition = Duration.zero;
  int _stalledSeconds = 0;
  int _healthySeconds = 0;
  int _recoveryAttempts = 0;
  bool _isRecovering = false;

  /// Guards every call into the orientation plugin: forcing landscape on the
  /// way into full screen, resetting on the way out, the rotation lock in the
  /// settings sheet and the listener that follows the device. A television
  /// answers no to this, so none of them run there.
  bool get _supportsOrientationManager => deviceType.canDriveOrientation;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _vm = context.read<MovieDetailViewModel>();
  }

  @override
  void initState() {
    super.initState();
    logger.d('MovieDetailScreen: initState');
    widget.controller?.attach(_exitFullScreen);
    _initOrientationListener();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // A television opens on its landing page instead: the poster, and a row
      // of actions saying what pressing OK will do. Dropping someone straight
      // into a film they only moved the remote onto is what a ten-foot page
      // is supposed to spare them.
      final shouldAutoEnterFullScreen =
          !deviceType.isTv &&
          (kIsWeb || defaultTargetPlatform == TargetPlatform.macOS);
      if (mounted && shouldAutoEnterFullScreen) _enterFullScreen();
    });
  }

  @override
  void initData() async {
    await _vm.init(
      widget.movieUrl,
      widget.movieId,
      initialMovie: widget.initialMovie,
    );
    if (!mounted) return;
    if (_shouldAutoPlay) _playEpisode(_vm.selectedEpisode!);
    super.initData();
  }

  /// Whether the episode the page settled on should start by itself.
  ///
  /// Everywhere but a television, yes: the page exists to play the film. On a
  /// television playback waits for the landing page's Resume or Play button,
  /// so nothing starts streaming because the remote passed over a poster.
  ///
  /// Written as the negation of [_showTvLanding] rather than as a second copy
  /// of the same test. Spelled out twice they drifted apart, and the gap
  /// between them — a page that neither plays nor shows the landing — was a
  /// spinner that never went away.
  bool get _shouldAutoPlay =>
      _vm.selectedEpisode != null &&
      _videoController == null &&
      !_showTvLanding;

  void _initOrientationListener() {
    if (!_supportsOrientationManager) return;
    _orientationSubscription = FlutterOrientationManager.orientationStream
        .listen((orientation) {
          if (!mounted || _isRotationLocked) return;
          if (orientation == Orientation.landscape && !_isFullScreen) {
            if (_videoController?.value.isInitialized == true) {
              _enterFullScreen();
            }
          } else if (orientation == Orientation.portrait && _isFullScreen) {
            _exitFullScreen();
          }
        });
  }

  @override
  void didUpdateWidget(MovieDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.detach(_exitFullScreen);
      widget.controller?.attach(_exitFullScreen);
    }
    if (oldWidget.movieId != widget.movieId ||
        oldWidget.movieUrl != widget.movieUrl) {
      unawaited(_detachAndDisposeController());
      // Another film: a television is back on its landing page for it.
      _hasStartedPlayback = false;
      _tvLandingFocusRequested = false;
      () async {
        await _vm.init(
          widget.movieUrl,
          widget.movieId,
          initialMovie: widget.initialMovie,
        );
        if (!mounted) return;
        if (_shouldAutoPlay) _playEpisode(_vm.selectedEpisode!);
      }();
    }
  }

  @override
  void dispose() {
    logger.d('MovieDetailScreen: dispose');
    widget.controller?.detach(_exitFullScreen);
    _controllerGeneration++;
    final controller = _videoController;
    final listener = _videoValueListener;
    _videoController = null;
    _videoValueListener = null;
    if (controller != null) {
      if (controller.value.isInitialized) {
        final position = controller.value.position.inSeconds;
        logger.d('MovieDetailScreen: Saving final position $position');
        unawaited(_recordWatched(positionSeconds: position));
      }
      if (listener != null) controller.removeListener(listener);
      unawaited(controller.dispose());
    }
    _controlsTimer?.cancel();
    _playPauseLongPressTimer?.cancel();
    _volumeHideTimer?.cancel();
    _orientationSubscription?.cancel();
    _videoFocusNode.dispose();
    _topControlsScope.dispose();
    _bottomControlsScope.dispose();
    _timelineFocusNode.dispose();
    _episodeOverlayScope.dispose();
    _currentEpisodeFocusNode.dispose();
    _episodeOverlayController.dispose();
    _tvPrimaryActionFocusNode.dispose();
    _progressTimer?.cancel();
    _watchdogTimer?.cancel();
    // Unconditionally, not through [_setWakelock]: the page may be leaving
    // mid-film, and a screen held awake by a player that no longer exists is
    // never switched off again.
    unawaited(WakelockPlus.disable());

    // Reset everything to normal
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    if (_supportsOrientationManager) {
      FlutterOrientationManager.enableAutoRotation();
    }

    super.dispose();
  }

  Future<void> _refreshDetail() async {
    await _vm.init(
      widget.movieUrl,
      widget.movieId,
      initialMovie: widget.initialMovie,
    );
  }

  Future<void> _recordWatched({int? positionSeconds}) async {
    final movie = _vm.getLibraryMovie(
      widget.movieId,
      widget.movieUrl,
      widget.initialMovie,
    );
    await _vm.recordWatched(movie, positionSeconds: positionSeconds);
  }

  /// Holds the screen awake while the film runs, and hands it back the moment
  /// it stops. A player is the one page that has to: nothing is being touched
  /// for two hours, so the display would otherwise time out mid-scene.
  Future<void> _setWakelock(bool enabled) async {
    try {
      await WakelockPlus.toggle(enable: enabled);
    } on Object catch (error) {
      // A platform that has no such switch is not a reason to fail playback.
      logger.d('MovieDetailScreen: wakelock unavailable ($error)');
    }
  }

  void _startProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (_isPlaying) {
        final position = _videoController?.value.position.inSeconds;
        if (position != null) {
          unawaited(_recordWatched(positionSeconds: position));
        }
      }
    });
  }

  Future<void> _toggleFavorite() async {
    final l10n = AppLocalizations.of(context);
    final movie = _vm.getLibraryMovie(
      widget.movieId,
      widget.movieUrl,
      widget.initialMovie,
    );
    try {
      await _vm.toggleFavorite(movie);
    } catch (error) {
      if (mounted) {
        context.showToast(l10n.updateFavoriteFailed, isError: true);
      }
    }
  }

  /// Builds a controller for [url] and hands the screen over to it. Returns
  /// whether it came up; [isRecovery] keeps the retry budget of the stream that
  /// wedged instead of starting a fresh one.
  Future<bool> _initVideoPlayer(
    String url, {
    Duration? seekTo,
    bool isRecovery = false,
  }) async {
    final generation = ++_controllerGeneration;
    final l10n = AppLocalizations.of(context);

    // Cancel progress timer before switching controllers
    _progressTimer?.cancel();
    _watchdogTimer?.cancel();
    _currentStreamUrl = url;
    if (!isRecovery) _recoveryAttempts = 0;

    _vm.setStreamLoading(true);
    setState(() {
      _showControls = true;
      _isTimelineHovering = false;
    });

    final controller = VideoPlayerController.networkUrl(
      Uri.parse(url),
      httpHeaders: {'Referer': '${movieService.effectiveBaseUrl}/'},
    );

    try {
      // Initialize the NEW controller before disposing the OLD one for a smoother transition
      await controller.initialize();

      if (!mounted || generation != _controllerGeneration) {
        await controller.dispose();
        return false;
      }

      await controller.setPlaybackSpeed(_playbackSpeed);
      await controller.setVolume(_volume);

      Duration? initialSeek = seekTo;
      final libraryState = _vm.libraryState;
      if (initialSeek == null && libraryState != null) {
        if (_vm.selectedEpisode?.name == libraryState.lastEpisodeName &&
            _vm.selectedServer?.name == libraryState.lastServerName) {
          final seconds = libraryState.lastPositionSeconds ?? 0;
          if (seconds > 5) {
            initialSeek = Duration(seconds: seconds);
          }
        }
      }

      // Seek and play go out together. Awaiting the seek first made the
      // platform player fill its buffer at the target and only then start,
      // which is what made resuming a saved position sit still for seconds.
      final seek = initialSeek == null ? null : controller.seekTo(initialSeek);
      final play = controller.play();
      if (initialSeek != null && !isRecovery && seekTo == null && mounted) {
        context.showToast(l10n.resumePlayback(formatDuration(initialSeek)));
      }
      await Future.wait([?seek, play]);

      if (!mounted || generation != _controllerGeneration) {
        await controller.dispose();
        return false;
      }

      // Now dispose the old controller
      final oldController = _videoController;
      final oldListener = _videoValueListener;
      if (oldController != null) {
        if (oldListener != null) oldController.removeListener(oldListener);
        // We don't await disposal to avoid blocking the UI thread
        unawaited(oldController.dispose());
      }

      void videoValueListener() {
        if (!mounted ||
            generation != _controllerGeneration ||
            !identical(_videoController, controller)) {
          return;
        }

        // A stream that drops mid-play surfaces here and nowhere else; left
        // alone the frame just freezes for good.
        if (controller.value.hasError) {
          logger.e(
            'MovieDetailScreen: playback error '
            '${controller.value.errorDescription}',
          );
          unawaited(_recoverPlayback());
          return;
        }

        final isBuffering = controller.value.isBuffering;
        if (isBuffering != _isBuffering) {
          setState(() => _isBuffering = isBuffering);
        }

        // Auto play next episode when current one ends
        final duration = controller.value.duration;
        final position = controller.value.position;
        if (duration > Duration.zero &&
            position >= duration &&
            !controller.value.isPlaying &&
            !_vm.isTransitioningEpisode) {
          _playNextEpisode();
          return;
        }

        final isPlaying = controller.value.isPlaying;
        if (isPlaying != _isPlaying) {
          setState(() => _isPlaying = isPlaying);
          unawaited(_setWakelock(isPlaying));
          if (isPlaying) {
            _startControlsTimer();
            _startProgressTimer();
          } else {
            _progressTimer?.cancel();
            // Save progress immediately on pause
            final position = controller.value.position.inSeconds;
            unawaited(_recordWatched(positionSeconds: position));
          }
        }
      }

      setState(() {
        _videoController = controller;
        _videoValueListener = videoValueListener;
        _isPlaying = true;
        _isBuffering = controller.value.isBuffering;
      });
      _vm.setStreamLoading(false);
      unawaited(_setWakelock(true));
      controller.addListener(videoValueListener);
      _startControlsTimer();
      _startProgressTimer();
      _startWatchdog();
      unawaited(_recordWatched());
      // Off the critical path: playback is already running, the quality menu
      // just fills in behind it.
      unawaited(_vm.loadNativeVideoTracks(controller));
      return true;
    } catch (e) {
      await controller.dispose();
      if (!mounted || generation != _controllerGeneration) return false;
      _vm.setStreamLoading(false);
      // A failed recovery attempt is reported by the retry that gives up, not
      // by every round of it.
      if (!isRecovery) {
        context.showToast(l10n.videoStreamError, isError: true);
      }
      return false;
    }
  }

  /// Watches the position while playback claims to be running. A wedged HLS
  /// stream keeps `isPlaying` true forever without advancing, so the position
  /// standing still is the only signal there is.
  void _startWatchdog() {
    _watchdogTimer?.cancel();
    _watchdogPosition = _videoController?.value.position ?? Duration.zero;
    _stalledSeconds = 0;
    _healthySeconds = 0;
    _watchdogTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _tickWatchdog(),
    );
  }

  void _tickWatchdog() {
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) return;
    if (_isRecovering || _isDragging) return;

    final value = controller.value;
    // A pause, a manual seek or the end of the episode are not stalls.
    if (!value.isPlaying || value.position != _watchdogPosition) {
      if (value.isPlaying && value.position > _watchdogPosition) {
        _healthySeconds++;
        if (_healthySeconds >= _healthyRunToForgiveStalls.inSeconds) {
          _recoveryAttempts = 0;
          _healthySeconds = 0;
        }
      }
      _stalledSeconds = 0;
      _watchdogPosition = value.position;
      return;
    }

    _healthySeconds = 0;
    _stalledSeconds++;
    if (_stalledSeconds >= _stallLimit.inSeconds) {
      logger.d('MovieDetailScreen: playback stalled at ${value.position}');
      unawaited(_recoverPlayback());
    }
  }

  /// Rebuilds the player on the same stream at the position it died at, which
  /// is what the user used to have to kill the app to get. After
  /// [_maxRecoveryAttempts] it hands the stream back to the retry button.
  Future<void> _recoverPlayback() async {
    final url = _currentStreamUrl;
    final controller = _videoController;
    if (_isRecovering || url == null || controller == null || !mounted) return;

    final l10n = AppLocalizations.of(context);
    _watchdogTimer?.cancel();
    _progressTimer?.cancel();
    final resumeFrom = controller.value.position;

    _isRecovering = true;
    try {
      while (mounted && _recoveryAttempts < _maxRecoveryAttempts) {
        // Backing off matters: a stream that dropped because the host is
        // rate-limiting comes back only if we stop hammering it.
        if (_recoveryAttempts > 0) {
          await Future.delayed(Duration(seconds: _recoveryAttempts));
          if (!mounted) return;
        }
        _recoveryAttempts++;
        if (await _initVideoPlayer(url, seekTo: resumeFrom, isRecovery: true)) {
          return;
        }
      }
      if (!mounted) return;
      await _detachAndDisposeController();
      if (!mounted) return;
      context.showToast(l10n.videoStreamError, isError: true);
    } finally {
      _isRecovering = false;
    }
  }

  Future<void> _detachAndDisposeController() async {
    _controllerGeneration++;
    _watchdogTimer?.cancel();
    _progressTimer?.cancel();
    final controller = _videoController;
    final listener = _videoValueListener;
    if (controller == null) return;

    unawaited(_setWakelock(false));
    if (mounted) {
      setState(() {
        _videoController = null;
        _videoValueListener = null;
        _isPlaying = false;
        _isBuffering = false;
        _isTimelineHovering = false;
      });
      if (listener != null) {
        controller.removeListener(listener);
      }
      await WidgetsBinding.instance.endOfFrame;
    }
    await controller.dispose();
  }

  Future<void> _switchQuality(String quality) async {
    if (quality == _vm.selectedQuality || _vm.masterStreamUrl == null) return;
    final controller = _videoController;

    // video_player 2.14.0 can override the track on the running player, so the
    // picture changes where it is instead of tearing the controller down and
    // buffering the whole stream again from the current position.
    if (controller != null &&
        controller.value.isInitialized &&
        _vm.canSwitchQualityInPlace) {
      final l10n = AppLocalizations.of(context);
      try {
        await controller.selectVideoTrack(_vm.nativeTrackFor(quality));
        _vm.setSelectedQuality(quality);
        return;
      } catch (error, stackTrace) {
        logger.e(
          'MovieDetailScreen: in-place quality switch failed',
          error: error,
          stackTrace: stackTrace,
        );
        if (mounted) context.showToast(l10n.videoStreamError, isError: true);
        return;
      }
    }

    final targetUrl = _vm.qualityUrlFor(quality);
    if (targetUrl == null) return;
    final currentPos = _videoController?.value.position;
    _vm.setSelectedQuality(quality);
    await _initVideoPlayer(targetUrl, seekTo: currentPos);
  }

  Future<void> _switchServer(MovieEpisodeServer server) async {
    final currentPos = _videoController?.value.position;
    final currentEpisodeName = _vm.selectedEpisode?.name;

    _vm.switchServer(server);

    if (_vm.selectedEpisode != null) {
      final shouldSeek = _vm.selectedEpisode?.name == currentEpisodeName;
      await _playEpisode(
        _vm.selectedEpisode!,
        seekTo: shouldSeek ? currentPos : null,
      );
    }
  }

  bool get _hasNextEpisode => _vm.hasNextEpisode;

  bool get _hasPreviousEpisode => _vm.hasPreviousEpisode;

  void _playNextEpisode() {
    final next = _vm.nextEpisode;
    if (next != null) {
      _playEpisode(next);
    }
  }

  void _playPreviousEpisode() {
    final prev = _vm.previousEpisode;
    if (prev != null) {
      _playEpisode(prev);
    }
  }

  Future<void> _playEpisode(MovieEpisode episode, {Duration? seekTo}) async {
    final streamUrl = await _vm.prepareEpisode(
      episode,
      widget.movieId,
      widget.movieUrl,
    );
    if (streamUrl != null && streamUrl.isNotEmpty) {
      final url = await _vm.getStreamUrlForMaster(streamUrl);
      if (url != null) {
        await _initVideoPlayer(url, seekTo: seekTo);
      }
    } else if (episode.embedUrl != null) {
      _vm.setStreamLoading(false);
    } else {
      if (mounted) {
        _vm.setStreamLoading(false);
        final l10n = AppLocalizations.of(context);
        context.showToast(l10n.videoStreamError, isError: true);
      }
    }
  }

  /// Puts the remote on the bar above the video ([top]) or the one below it.
  ///
  /// [afterFrame] for a bar that is only now being shown: [ExcludeFocus] holds
  /// a hidden bar out of the focus tree, so there is nothing to hand the remote
  /// to until the frame carrying it has been built. A bar already on screen is
  /// entered straight away — waiting on a frame nobody has asked for would
  /// leave the press doing nothing at all.
  void _enterControls(bool top, {required bool afterFrame}) {
    final scope = top ? _topControlsScope : _bottomControlsScope;
    if (!afterFrame) {
      focusPlayerControls(scope);
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_showControls) return;
      focusPlayerControls(scope);
    });
  }

  /// Takes the remote off the control bars and puts it back on the video —
  /// what a press away from a bar does, and what hiding the bars has to do
  /// before the focus they hold is excluded out from under the user.
  void _releaseControlsFocus() {
    if (!_controlsHaveFocus) return;
    _videoFocusNode.requestFocus();
  }

  void _startControlsTimer() {
    _controlsTimer?.cancel();
    if (_isPlaying && !_showVolumeControl) {
      _controlsTimer = Timer(Dimens.playerControlsTimeout, () {
        // A bar the remote is resting on stays: the user is part way through
        // choosing something, and pulling it away would drop their place and
        // the focus with it.
        if (mounted &&
            !_isTimelineHovering &&
            !_isDragging &&
            !_isScrubbing &&
            !_showEpisodeOverlay &&
            !_controlsHaveFocus) {
          setState(() => _showControls = false);
        }
      });
    }
  }

  /// Brings the control overlay back up and restarts its countdown — what
  /// every key the player claims does before doing its own work, so the viewer
  /// sees what the press changed.
  void _wakeControls() {
    if (!_showControls) setState(() => _showControls = true);
    _startControlsTimer();
  }

  /// Hides the overlay and takes the remote off it, which is what the first
  /// press of BACK means on a television.
  void _hideControls() {
    if (!_showControls) return;
    setState(() {
      _showControls = false;
      _showVolumeControl = false;
    });
    _controlsTimer?.cancel();
    _releaseControlsFocus();
  }

  void _togglePlayback() {
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) return;

    final wasPlaying = controller.value.isPlaying;
    if (!_showControls) setState(() => _showControls = true);
    if (wasPlaying) {
      _controlsTimer?.cancel();
      unawaited(controller.pause());
    } else {
      unawaited(controller.play());
      _startControlsTimer();
    }
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
      if (!_showControls) _showVolumeControl = false;
    });
    if (_showControls) {
      _startControlsTimer();
    } else {
      _releaseControlsFocus();
    }
  }

  void _setVolume(double value) {
    final volume = value.clamp(0.0, 1.0);
    if (volume > 0) _lastAudibleVolume = volume;
    setState(() => _volume = volume);
    unawaited(_videoController?.setVolume(volume));
  }

  /// Long-pressing the volume button mutes, and restores the level it was at.
  void _toggleMute() {
    _setVolume(_volume > 0 ? 0 : _lastAudibleVolume);
    HapticFeedback.selectionClick();
    _startControlsTimer();
  }

  void _toggleVolumeControl() {
    _controlsTimer?.cancel();
    _volumeHideTimer?.cancel();
    setState(() => _showVolumeControl = !_showVolumeControl);
    if (!_showVolumeControl) _startControlsTimer();
  }

  void _handleVolumeTap() {
    // A television's own remote owns the volume, and the popup slider is a
    // dead end for a D-pad — so here the button simply mutes and unmutes.
    if (deviceType.isTv) {
      _toggleMute();
      return;
    }
    final isMobile =
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    if (isMobile) {
      _toggleVolumeControl();
    } else {
      _toggleMute();
    }
  }

  IconData get _volumeIcon {
    if (_volume == 0) return Icons.volume_off_rounded;
    if (_volume < 0.5) return Icons.volume_down_rounded;
    return Icons.volume_up_rounded;
  }

  void _toggleRotationLock() {
    if (!_supportsOrientationManager) return;
    final shouldLock = !_isRotationLocked;
    setState(() => _isRotationLocked = shouldLock);
    if (shouldLock) {
      FlutterOrientationManager.lockOrientation();
    } else {
      FlutterOrientationManager.enableAutoRotation();
    }
    _startControlsTimer();
  }

  KeyEventResult _handleVideoKeyEvent(FocusNode node, KeyEvent event) {
    // This node wraps the controls as well as the picture, so a key pressed on
    // a focused button walks up through here first. Claiming it would seek the
    // film instead of moving along the bar, and swallow the OK that was meant
    // to press the button the remote is sitting on.
    if (!node.hasPrimaryFocus) return KeyEventResult.ignored;

    // A held arrow arrives as a repeat, and a repeat left alone walks up to
    // `TvShell`'s shortcuts — whose activators count repeats — and carries the
    // remote off the picture. Every arrow the player claims is claimed on the
    // way down and on every repeat of it.
    final isPress = event is KeyDownEvent;
    if (isPress || event is KeyRepeatEvent) {
      final key = event.logicalKey;

      if (key == LogicalKeyboardKey.arrowLeft ||
          key == LogicalKeyboardKey.arrowRight) {
        final isForward = key == LogicalKeyboardKey.arrowRight;
        _seekRepeatCount = isPress ? 0 : _seekRepeatCount + 1;
        final seconds = _seekStepSeconds;
        _seekBy(Duration(seconds: isForward ? seconds : -seconds));
        _triggerSkipIndicator(isForward: isForward, seconds: seconds);
        return KeyEventResult.handled;
      }

      final isUp = key == LogicalKeyboardKey.arrowUp;
      if (isUp || key == LogicalKeyboardKey.arrowDown) {
        final wasVisible = _showControls;
        if (!wasVisible) {
          // The transport bar is hidden, and hidden means out of the focus
          // tree — so this press wakes it, the way a set-top box behaves.
          // Handled either way, or traversal would run now and carry the
          // remote off the video to whatever sits under the player.
          _wakeControls();
          return KeyEventResult.handled;
        }
        if (!deviceType.isTv) {
          // Bar already up: leave the key alone so traversal can walk onto it.
          return KeyEventResult.ignored;
        }
        if (!isPress) return KeyEventResult.handled;
        // Traversal cannot find the bars — they are inside this very node's
        // rectangle — so the remote is handed to them by name. Up reaches the
        // transport bar (and from there, up again, the bar at the top); down
        // is left to traversal, which is how the server chips and the episode
        // list under an inline player are reached at all. Full screen has no
        // page under the picture, so there down means the transport bar too.
        if (isUp || _isFullScreen) {
          _enterControls(isUp, afterFrame: false);
          return KeyEventResult.handled;
        }
        _startControlsTimer();
        return KeyEventResult.ignored;
      }
    }

    if (event is KeyDownEvent) {
      // Full screen on a television, OK on the picture opens the episode grid
      // rather than pausing: with the transport bar a press away, choosing
      // what to watch next is the thing the picture itself has no key for.
      if (_canOpenEpisodeOverlay && _isSelectKey(event.logicalKey)) {
        _openEpisodeOverlay();
        return KeyEventResult.handled;
      }
      if (_playPauseKeys.contains(event.logicalKey)) {
        if (!_isPlayPauseKeyDown) {
          _isPlayPauseKeyDown = true;
          _playPauseLongPressTimer?.cancel();
          _playPauseLongPressTimer = Timer(
            const Duration(milliseconds: 500),
            () {
              if (_isPlayPauseKeyDown && mounted) {
                _start2xSpeed();
              }
            },
          );
        }
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.escape && _isFullScreen) {
        _exitFullScreen();
        return KeyEventResult.handled;
      }
    } else if (event is KeyRepeatEvent) {
      if (_playPauseKeys.contains(event.logicalKey)) {
        return KeyEventResult.handled;
      }
    } else if (event is KeyUpEvent) {
      if (_playPauseKeys.contains(event.logicalKey)) {
        _playPauseLongPressTimer?.cancel();
        if (_isPlayPauseKeyDown) {
          if (_isSpeedBoosted) {
            _stop2xSpeed();
          } else {
            _togglePlayback();
          }
          _isPlayPauseKeyDown = false;
        }
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  /// The OK button, under each of the names a remote sends it by.
  bool _isSelectKey(LogicalKeyboardKey key) =>
      key == LogicalKeyboardKey.select ||
      key == LogicalKeyboardKey.enter ||
      key == LogicalKeyboardKey.gameButtonA;

  /// How far one press of left or right jumps. A held key jumps further, so
  /// crossing half an hour of film is a couple of seconds of holding rather
  /// than a hundred presses.
  static const _seekStepShort = 10;
  static const _seekStepLong = 30;
  static const _seekRepeatsBeforeLongStep = 5;

  int get _seekStepSeconds => _seekRepeatCount >= _seekRepeatsBeforeLongStep
      ? _seekStepLong
      : _seekStepShort;

  /// The keys a remote's transport row sends, handled for the whole page
  /// rather than for the picture: they mean the same thing wherever the remote
  /// happens to be resting — on a chip in the body, on the transport bar, in
  /// the episode grid.
  KeyEventResult _handlePageKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final controller = _videoController;
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.mediaPlayPause) {
      _wakeControls();
      _togglePlayback();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.mediaPlay) {
      if (controller?.value.isInitialized ?? false) {
        _wakeControls();
        unawaited(controller!.play());
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.mediaPause) {
      if (controller?.value.isInitialized ?? false) {
        _wakeControls();
        unawaited(controller!.pause());
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.mediaStop) {
      if (controller?.value.isInitialized ?? false) {
        unawaited(controller!.pause());
      }
      _leavePlayer();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.mediaFastForward ||
        key == LogicalKeyboardKey.mediaRewind) {
      final isForward = key == LogicalKeyboardKey.mediaFastForward;
      _wakeControls();
      _seekBy(Duration(seconds: isForward ? _seekStepLong : -_seekStepLong));
      _triggerSkipIndicator(isForward: isForward, seconds: _seekStepLong);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.mediaTrackNext) {
      if (_hasNextEpisode) {
        _wakeControls();
        _playNextEpisode();
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.mediaTrackPrevious) {
      if (_hasPreviousEpisode) {
        _wakeControls();
        _playPreviousEpisode();
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// What the stop key does once playback is paused: back out of the picture,
  /// then out of the page — the same ladder the BACK key climbs.
  void _leavePlayer() {
    if (widget.embedded) {
      widget.onClose?.call();
      return;
    }
    if (_isFullScreen) {
      _exitFullScreen();
      return;
    }
    unawaited(Navigator.of(context).maybePop());
  }

  void _seekBy(Duration offset) {
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) return;

    final duration = controller.value.duration;
    final currentPos = _virtualSeekPosition ?? controller.value.position;
    var target = currentPos + offset;

    if (target < Duration.zero) target = Duration.zero;
    if (duration > Duration.zero && target > duration) target = duration;

    setState(() {
      _virtualSeekPosition = target;
    });

    unawaited(controller.seekTo(target));

    _virtualSeekTimer?.cancel();
    _virtualSeekTimer = Timer(const Duration(milliseconds: 1000), () {
      if (mounted) {
        setState(() => _virtualSeekPosition = null);
      }
    });

    if (!_showControls) setState(() => _showControls = true);
    _startControlsTimer();
  }

  void _updateDragPosition(
    VideoPlayerController controller,
    double localX,
    double width,
  ) {
    final fraction = (localX / width).clamp(0.0, 1.0);
    final target = controller.value.duration * fraction;
    setState(() {
      _dragFraction = fraction;
      _dragPosition = target;
      _hoverThumbnailCue = _vm.thumbnailTrack?.cueAt(target);
    });
    unawaited(controller.seekTo(target));
  }

  void _updateHoverPreview(
    double localX,
    double width, {
    bool showPreview = true,
  }) {
    if (width <= 0) return;
    final fraction = (localX / width).clamp(0.0, 1.0);
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) return;
    final target = controller.value.duration * fraction;
    _controlsTimer?.cancel();
    setState(() {
      _isTimelineHovering = showPreview;
      _showControls = true;
      _dragFraction = fraction;
      _dragPosition = target;
      _hoverThumbnailCue = _vm.thumbnailTrack?.cueAt(target);
    });
  }

  void _finishDragging(VideoPlayerController controller) {
    final shouldResume = _resumeAfterDrag;
    setState(() => _isDragging = false);
    _resumeAfterDrag = false;
    if (shouldResume) unawaited(controller.play());
    _startControlsTimer();
  }

  void _enterFullScreen() {
    if (_isFullScreen) return;
    setState(() {
      _isFullScreen = true;
      _showControls = true;
    });
    widget.onFullScreenChanged?.call(true);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    if (_supportsOrientationManager && !_isRotationLocked) {
      FlutterOrientationManager.forceToLandscape();
    }
  }

  void _exitFullScreen() {
    if (!_isFullScreen) return;
    setState(() {
      _isFullScreen = false;
      _showControls = true;
    });
    widget.onFullScreenChanged?.call(false);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    if (_supportsOrientationManager && !_isRotationLocked) {
      FlutterOrientationManager.resetToPortrait();
    }
  }

  /// Toggle full screen manually
  void _toggleFullScreen() {
    logger.d('MovieDetailScreen: _toggleFullScreen (Manual)');
    if (_isFullScreen) {
      _exitFullScreen();
    } else {
      _enterFullScreen();
    }
    _startControlsTimer();
  }

  void _setVideoCover(bool isCover) {
    if (_isVideoCover == isCover) return;
    setState(() => _isVideoCover = isCover);
    _startControlsTimer();
  }

  void _start2xSpeed() {
    if (_videoController == null || !_videoController!.value.isInitialized) {
      return;
    }
    setState(() => _isSpeedBoosted = true);
    _videoController!.setPlaybackSpeed(2.0);
    HapticFeedback.mediumImpact();
  }

  void _stop2xSpeed() {
    if (_videoController == null || !_videoController!.value.isInitialized) {
      return;
    }
    setState(() => _isSpeedBoosted = false);
    _videoController!.setPlaybackSpeed(_playbackSpeed);
  }

  Future<void> _showSettingsBottomSheet() async {
    final l10n = AppLocalizations.of(context);
    final action = await showAppBottomSheet<MovieSettingsAction>(
      context,
      title: l10n.settings,
      padding: EdgeInsets.zero,
      builder: (_) => MovieSettingsSheet(
        selectedQuality: _vm.selectedQuality,
        playbackSpeed: _playbackSpeed,
        isRotationLocked: _isRotationLocked,
        supportsOrientationManager: _supportsOrientationManager,
        onRotationLockToggled: _toggleRotationLock,
      ),
    );
    if (!mounted) return;
    _startControlsTimer();
    if (action == null) return;

    // The follow-up picker is opened from here, not from inside the sheet: by
    // the time it is needed the sheet's own context is gone.
    switch (action) {
      case MovieSettingsAction.quality:
        final quality = await showAppOptionSheet<String>(
          context,
          title: l10n.resolutionQuality,
          options: ['Auto', ..._vm.availableQualities.map((e) => e.label)],
          selected: _vm.selectedQuality,
        );
        if (quality != null) _switchQuality(quality);
      case MovieSettingsAction.speed:
        final speed = await showAppOptionSheet<double>(
          context,
          title: l10n.playbackSpeed,
          options: const [0.5, 0.75, 1.0, 1.25, 1.5, 2.0],
          selected: _playbackSpeed,
          labelBuilder: (v) => v == 1.0 ? '1x' : '${v}x',
        );
        if (speed == null || !mounted) return;
        setState(() => _playbackSpeed = speed);
        _videoController?.setPlaybackSpeed(speed);
    }
  }

  /// [seconds] is how far the jump that raised this badge went, so a held
  /// arrow reads the same as the double tap it is standing in for.
  void _triggerSkipIndicator({
    required bool isForward,
    int seconds = _seekStepShort,
  }) {
    if (isForward) {
      _skipForwardTimer?.cancel();
      setState(() => _skipForwardValue += seconds);
      _skipForwardTimer = Timer(const Duration(milliseconds: 600), () {
        if (mounted) setState(() => _skipForwardValue = 0);
      });
    } else {
      _skipBackwardTimer?.cancel();
      setState(() => _skipBackwardValue += seconds);
      _skipBackwardTimer = Timer(const Duration(milliseconds: 600), () {
        if (mounted) setState(() => _skipBackwardValue = 0);
      });
    }
  }

  /// Moves the pending scrub position by [offset] without seeking.
  ///
  /// A remote has no pointer to drag, so the timeline is scrubbed the way a
  /// set-top box does it: the arrows walk a marker along the bar with the
  /// thumbnail preview following it, and the film only moves once OK says so.
  void _scrubBy(Duration offset) {
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) return;
    final duration = controller.value.duration;
    if (duration <= Duration.zero) return;

    final base = _isScrubbing
        ? _dragPosition
        : (_virtualSeekPosition ?? controller.value.position);
    var target = base + offset;
    if (target < Duration.zero) target = Duration.zero;
    if (target > duration) target = duration;

    _controlsTimer?.cancel();
    setState(() {
      _isScrubbing = true;
      _showControls = true;
      _dragPosition = target;
      _dragFraction = target.inMilliseconds / duration.inMilliseconds;
      _hoverThumbnailCue = _vm.thumbnailTrack?.cueAt(target);
    });
  }

  void _commitScrub() {
    final controller = _videoController;
    if (!_isScrubbing || controller == null) return;
    final target = _dragPosition;
    setState(() => _isScrubbing = false);
    unawaited(controller.seekTo(target));
    _startControlsTimer();
  }

  void _cancelScrub() {
    if (!_isScrubbing) return;
    setState(() => _isScrubbing = false);
    _startControlsTimer();
  }

  KeyEventResult _handleTimelineKeyEvent(FocusNode node, KeyEvent event) {
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) {
      return KeyEventResult.ignored;
    }
    final isPress = event is KeyDownEvent;
    if (!isPress && event is! KeyRepeatEvent) return KeyEventResult.ignored;

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight) {
      final isForward = key == LogicalKeyboardKey.arrowRight;
      _seekRepeatCount = isPress ? 0 : _seekRepeatCount + 1;
      final seconds = _seekStepSeconds;
      _scrubBy(Duration(seconds: isForward ? seconds : -seconds));
      return KeyEventResult.handled;
    }
    if (!isPress) return KeyEventResult.ignored;
    if (_isSelectKey(key) || key == LogicalKeyboardKey.space) {
      _commitScrub();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      // Left to the bar's own exit, which is the way off every other control
      // in it; the marker is simply dropped on the way out.
      _cancelScrub();
      return KeyEventResult.ignored;
    }
    return KeyEventResult.ignored;
  }

  /// The episodes of the server currently selected.
  List<MovieEpisode> get _episodes =>
      _vm.selectedServer?.episodes ?? const <MovieEpisode>[];

  bool get _isSeries => _episodes.length > 1;

  /// Whether OK on the picture should bring the episode grid up.
  bool get _canOpenEpisodeOverlay =>
      deviceType.isTv && _isFullScreen && _isSeries && !_showEpisodeOverlay;

  void _openEpisodeOverlay() {
    if (!_isSeries || _showEpisodeOverlay) return;
    _controlsTimer?.cancel();
    setState(() => _showEpisodeOverlay = true);
    // The grid is only now being built, so there is nothing to hand the remote
    // to until the frame carrying it exists.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_showEpisodeOverlay) return;
      final context = _currentEpisodeFocusNode.context;
      if (context != null) {
        unawaited(
          Scrollable.ensureVisible(
            context,
            alignment: Dimens.tvFocusScrollAlignment,
            duration: Dimens.tvFocusScrollDuration,
          ),
        );
        _currentEpisodeFocusNode.requestFocus();
        return;
      }
      _episodeOverlayScope.requestFocus();
    });
  }

  void _closeEpisodeOverlay() {
    if (!_showEpisodeOverlay) return;
    setState(() => _showEpisodeOverlay = false);
    // Back where the grid was opened from: the picture, or the landing page's
    // row of actions when nothing is playing yet.
    if (_showTvLanding) {
      _tvPrimaryActionFocusNode.requestFocus();
    } else {
      _videoFocusNode.requestFocus();
    }
    _startControlsTimer();
  }

  /// Where playback would pick up from, when the page was left part way
  /// through this very episode on this very server.
  Duration? get _resumePosition {
    final state = _vm.libraryState;
    if (state == null) return null;
    if (state.lastEpisodeName != _vm.selectedEpisode?.name ||
        state.lastServerName != _vm.selectedServer?.name) {
      return null;
    }
    final seconds = state.lastPositionSeconds ?? 0;
    if (seconds <= 5) return null;
    return Duration(seconds: seconds);
  }

  /// The press that starts a film on a television: full screen, then play.
  void _startTvPlayback(MovieEpisode episode, {Duration? seekTo}) {
    setState(() => _hasStartedPlayback = true);
    _enterFullScreen();
    unawaited(_playEpisode(episode, seekTo: seekTo));
  }

  /// The original title, shown as a strip right under the app bar so it stays
  /// visible while the body scrolls.
  Widget _buildOriginalTitleBar(String originalTitle, TextStyle style) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      color: theme.appBarTheme.backgroundColor ?? theme.colorScheme.surface,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: Text(
        originalTitle,
        maxLines: subtitleMaxLines,
        overflow: TextOverflow.ellipsis,
        style: style,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MovieDetailViewModel>(
      builder: (context, vm, child) {
        final l10n = AppLocalizations.of(context);
        final rawTitle =
            vm.detail?.title ??
            widget.initialMovie?.title ??
            movieService.getLabel();
        final titleParts = splitMovieTitle(rawTitle);
        final title = titleParts.title;
        final alternateTitle = titleParts.subtitle;
        final rawOriginalTitle =
            (vm.detail?.originalTitle ?? widget.initialMovie?.originalTitle)
                ?.trim();
        final originalTitle =
            (rawOriginalTitle == null ||
                rawOriginalTitle.isEmpty ||
                rawOriginalTitle == title ||
                rawOriginalTitle == alternateTitle)
            ? null
            : rawOriginalTitle;
        final titleFit = appBarTitleFit(
          context,
          title,
          subtitle: alternateTitle,
          subtitleLines: widget.embedded ? 1 : subtitleMaxLines,
        );

        final page = _isFullScreen
            ? Scaffold(
                backgroundColor: Colors.black,
                body: SizedBox.expand(
                  child: _buildVideoPlayerArea(isFullScreen: true),
                ),
              )
            : widget.embedded
            ? _buildEmbedded(
                context,
                title: title,
                alternateTitle: alternateTitle,
                originalTitle: originalTitle,
                titleFit: titleFit,
              )
            : GestureDetector(
                onTap: () => FocusScope.of(context).unfocus(),
                child: AppScaffold(
                  appBar: DoAppBar(
                    title: title,
                    titleStyle: titleFit.titleStyle,
                    subtitle: alternateTitle == null
                        ? null
                        : Text(
                            alternateTitle,
                            style: titleFit.subtitleStyle,
                            maxLines: subtitleMaxLines,
                            overflow: TextOverflow.ellipsis,
                          ),
                    titleMaxLines: titleMaxLines,
                    height: titleFit.height,
                    actions: [
                      NeuIconButton(
                        size: Dimens.appBarActionSize,
                        iconSize: 18,
                        depth: Dimens.appBarActionDepth,
                        tooltip: vm.isFavorite
                            ? l10n.removeFromFavorites
                            : l10n.addToFavorites,
                        onPressed: vm.isUpdatingFavorite
                            ? null
                            : _toggleFavorite,
                        icon: vm.isFavorite
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: vm.isFavorite ? Colors.pinkAccent : null,
                      ),
                    ],
                  ),
                  body: vm.isLoading
                      ? const Center(child: Loading())
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (originalTitle != null)
                              _buildOriginalTitleBar(
                                originalTitle,
                                subtitleStripStyle(context, originalTitle),
                              ),
                            if (_showTvLanding)
                              _buildTvLanding(l10n)
                            else
                              _buildVideoPlayerArea(isFullScreen: false),
                            Expanded(child: _buildDetailBody()),
                          ],
                        ),
                ),
              );

        return PopScope(
          canPop: (widget.embedded || !_isFullScreen) && !_showEpisodeOverlay,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            // The ladder BACK climbs on a television: the grid first, then the
            // control overlay, and only then the picture itself.
            if (_showEpisodeOverlay) {
              _closeEpisodeOverlay();
              return;
            }
            if (widget.embedded) return;
            if (deviceType.isTv &&
                _isFullScreen &&
                _showControls &&
                _videoController != null) {
              _hideControls();
              return;
            }
            if (_isFullScreen) _toggleFullScreen();
          },
          // Watching the whole page, taking no turn of its own: the transport
          // keys below are read wherever the remote happens to be resting.
          child: Focus(
            canRequestFocus: false,
            skipTraversal: true,
            onKeyEvent: _handlePageKeyEvent,
            child: _showEpisodeOverlay
                ? Stack(children: [page, _buildEpisodeOverlay(l10n)])
                : page,
          ),
        );
      },
    );
  }

  /// Television only: the page opens on the poster and a row of actions, and
  /// nothing streams until one of them is pressed.
  ///
  /// Embedded too: the browse page opens every film that way, so it is the one
  /// path a viewer on a television actually takes. Exempting it would leave
  /// the landing unreachable and a poster still streaming on the press that
  /// only meant to open it.
  bool get _showTvLanding => deviceType.isTv && !_hasStartedPlayback;

  /// The television landing page: the poster as the hero, and the row of
  /// actions that decide what the OK button does — resume, start again, or
  /// pick an episode. Nothing here streams until one of them is pressed.
  ///
  /// [fillParent] takes the box the player would have had, for the embedded
  /// overlay the browse page opens a film into; on its own the landing stands
  /// [tvLandingHeroHeight] tall.
  Widget _buildTvLanding(AppLocalizations l10n, {bool fillParent = false}) {
    final poster = _vm.detail?.poster ?? widget.initialMovie?.poster ?? '';
    final episode = _vm.selectedEpisode;
    final resumeFrom = _resumePosition;
    final theme = Theme.of(context);

    final content = LayoutBuilder(
      builder: (context, constraints) {
        // The embedded player collapses towards a bar the size of a thumbnail.
        // There is no room for a row of ten-foot buttons in it, and a viewer
        // on a television never sees that state anyway — the browse page does
        // not minimise there. Below the height a player needs, the poster is
        // shown on its own rather than overflowing.
        final showActions =
            !constraints.maxHeight.isFinite ||
            constraints.maxHeight >= minPlayerHeight;

        // The first action is where the remote lands, so the page opens on the
        // thing the viewer came for instead of on the app bar.
        if (showActions && !_tvLandingFocusRequested && episode != null) {
          _tvLandingFocusRequested = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || !_showTvLanding) return;
            _tvPrimaryActionFocusNode.requestFocus();
          });
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            if (poster.isNotEmpty)
              CachedNetworkImage(
                imageUrl: poster,
                fit: BoxFit.cover,
                placeholder: (_, _) => const ColoredBox(color: Colors.black),
                errorWidget: (_, _, _) => const ColoredBox(color: Colors.black),
              )
            else
              const ColoredBox(color: Colors.black),
            // The actions sit on the poster, so the poster has to stop
            // competing with them where they are.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black87],
                ),
              ),
            ),
            if (showActions)
              Align(
                alignment: Alignment.bottomLeft,
                child: Padding(
                  padding: Dimens.screenPadding,
                  child: Wrap(
                    spacing: Dimens.modalItemSpacing,
                    runSpacing: Dimens.modalItemSpacing,
                    children: [
                      if (resumeFrom != null)
                        NeuButton(
                          focusNode: _tvPrimaryActionFocusNode,
                          accent: theme.colorScheme.primary,
                          onPressed: episode == null
                              ? null
                              : () => _startTvPlayback(
                                  episode,
                                  seekTo: resumeFrom,
                                ),
                          child: Text(
                            l10n.resumePlayback(formatDuration(resumeFrom)),
                          ),
                        ),
                      NeuButton(
                        focusNode: resumeFrom == null
                            ? _tvPrimaryActionFocusNode
                            : null,
                        accent: resumeFrom == null
                            ? theme.colorScheme.primary
                            : null,
                        onPressed: episode == null
                            ? null
                            : () => _startTvPlayback(
                                episode,
                                seekTo: Duration.zero,
                              ),
                        child: Text(l10n.playFromStart),
                      ),
                      if (_isSeries)
                        NeuButton(
                          onPressed: _openEpisodeOverlay,
                          child: Text(l10n.episodeLabel),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );

    if (fillParent) return content;
    return SizedBox(height: tvLandingHeroHeight, child: content);
  }

  /// The episode grid, over whatever is behind it — the picture in full
  /// screen, the landing page before playback has started.
  Widget _buildEpisodeOverlay(AppLocalizations l10n) {
    final episodes = _episodes;
    final selectedSlug = _vm.selectedEpisode?.slug;
    return Positioned.fill(
      child: FocusScope(
        node: _episodeOverlayScope,
        child: Shortcuts(
          shortcuts: const <ShortcutActivator, Intent>{
            SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
          },
          child: Actions(
            actions: {
              DismissIntent: CallbackAction<DismissIntent>(
                onInvoke: (_) {
                  _closeEpisodeOverlay();
                  return null;
                },
              ),
            },
            // Dimmed rather than opaque: the film keeps running underneath,
            // and the viewer is choosing where to take it next.
            child: Material(
              color: Colors.black.withValues(alpha: 0.85),
              child: SafeArea(
                child: Padding(
                  padding: Dimens.screenPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.episodeLabel,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: Dimens.modalItemSpacing),
                      Expanded(
                        child: SingleChildScrollView(
                          controller: _episodeOverlayController,
                          child: Wrap(
                            spacing: Dimens.modalItemSpacing,
                            runSpacing: Dimens.modalItemSpacing,
                            children: [
                              for (final episode in episodes)
                                _EpisodeOverlayTile(
                                  key: ValueKey(episode.slug),
                                  label: episode.name,
                                  isSelected: episode.slug == selectedSlug,
                                  focusNode: episode.slug == selectedSlug
                                      ? _currentEpisodeFocusNode
                                      : null,
                                  onTap: () {
                                    _closeEpisodeOverlay();
                                    if (_hasStartedPlayback) {
                                      unawaited(_playEpisode(episode));
                                    } else {
                                      _startTvPlayback(episode);
                                    }
                                  },
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailBody() {
    return MovieDetailBody(
      detail: _vm.detail,
      selectedServer: _vm.selectedServer,
      selectedEpisode: _vm.selectedEpisode,
      onRefresh: _refreshDetail,
      onServerSelected: _switchServer,
      onEpisodeSelected: _playEpisode,
      onRelatedTap: (related) {
        if (widget.embedded) {
          widget.onRelatedMovieTap?.call(related);
        } else {
          context.replaceRoute(
            MovieDetailRoute(
              movieUrl: related.url,
              movieId: related.id,
              initialMovie: related,
            ),
          );
        }
      },
    );
  }

  /// The page as it lives inside the `MovieScreen` overlay. [minimizeProgress]
  /// (1 = expanded, 0 = mini bar) drives every size here, so a drag reads as
  /// the player shrinking into the bottom bar while the rest fades away.
  Widget _buildEmbedded(
    BuildContext context, {
    required String title,
    required String? alternateTitle,
    required String? originalTitle,
    required AppBarTitleFit titleFit,
  }) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final t = widget.minimizeProgress.clamp(0.0, 1.0);
    final mediaQuery = MediaQuery.of(context);
    final controller = _videoController;
    final aspectRatio = (controller?.value.isInitialized ?? false)
        ? controller!.value.aspectRatio
        : 16 / 9;
    final screenWidth = mediaQuery.size.width;
    final playerWidth = miniPlayerWidth + (screenWidth - miniPlayerWidth) * t;
    // Landscape puts the notch and the rounded corners on the sides, where the
    // header controls and the body text would otherwise run underneath them.
    // The video itself stays full bleed.
    final sideInsets = EdgeInsets.only(
      left: mediaQuery.padding.left,
      right: mediaQuery.padding.right,
    );
    // Fixed so the player can be clamped against the space the header leaves.
    final headerHeight =
        mediaQuery.padding.top +
        titleFit.height +
        (originalTitle != null ? embeddedSubtitleHeight : 0);

    final header = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: mediaQuery.padding.top),
        SizedBox(
          height: titleFit.height,
          child: Row(
            children: [
              // Gone, not disabled, when the host does not minimise: a dead
              // button is one more row for a remote to stop on.
              if (widget.onMinimize != null)
                IconButton(
                  tooltip: l10n.minimize,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded),
                  onPressed: widget.onMinimize,
                ),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: titleFit.titleStyle,
                      maxLines: titleMaxLines,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (alternateTitle != null)
                      Text(
                        alternateTitle,
                        style: titleFit.subtitleStyle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              NeuIconButton(
                size: Dimens.appBarActionSize,
                iconSize: 18,
                depth: Dimens.appBarActionDepth,
                tooltip: _vm.isFavorite
                    ? l10n.removeFromFavorites
                    : l10n.addToFavorites,
                onPressed: _vm.isUpdatingFavorite ? null : _toggleFavorite,
                icon: _vm.isFavorite
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                color: _vm.isFavorite ? Colors.pinkAccent : null,
              ),
              IconButton(
                tooltip: l10n.close,
                icon: const Icon(Icons.close_rounded),
                onPressed: widget.onClose,
              ),
            ],
          ),
        ),
        if (originalTitle != null)
          SizedBox(
            height: embeddedSubtitleHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                originalTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: subtitleStripStyle(context, originalTitle, maxLines: 1),
              ),
            ),
          ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // Capped against the space left under the header, so a wide desktop
        // window (or a landscape phone) still leaves a body to scroll.
        // The insets fade in with the page: expanded, the video sits inside
        // them; collapsed to the mini bar, the host already places it clear of
        // the edges, so applying them there would shift the bar sideways.
        final activeSideInsets = sideInsets * t;
        final fullPlayerHeight = inlinePlayerHeight(
          width: screenWidth - sideInsets.horizontal,
          aspectRatio: aspectRatio,
          availableHeight: constraints.maxHeight - headerHeight,
        );
        final playerHeight = math.min(
          miniPlayerHeight + (fullPlayerHeight - miniPlayerHeight) * t,
          math.max(miniPlayerHeight, constraints.maxHeight - headerHeight * t),
        );
        // The box is still card-sized while the opening zoom runs.
        final boxedPlayerWidth = math.min(
          playerWidth,
          constraints.maxWidth - activeSideInsets.horizontal,
        );
        return Material(
          color: theme.colorScheme.surface,
          child: Column(
            children: [
              // Align+ClipRect collapses the header without reflowing its
              // content. Kept mounted at t == 0 so a drag that bottoms out
              // keeps feeding this recognizer instead of being cancelled.
              GestureDetector(
                // The strip above the video drags the page down just like the
                // video itself does.
                behavior: HitTestBehavior.opaque,
                onVerticalDragStart: widget.onPlayerDragStart,
                onVerticalDragUpdate: widget.onPlayerDragUpdate,
                onVerticalDragEnd: widget.onPlayerDragEnd,
                child: ClipRect(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    heightFactor: t,
                    child: Opacity(
                      opacity: t,
                      child: SizedBox(
                        height: headerHeight,
                        child: Padding(padding: sideInsets, child: header),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: activeSideInsets,
                child: SizedBox(
                  height: playerHeight,
                  child: Row(
                    children: [
                      SizedBox(
                        width: boxedPlayerWidth,
                        height: playerHeight,
                        child: GestureDetector(
                          onVerticalDragStart: widget.onPlayerDragStart,
                          onVerticalDragUpdate: widget.onPlayerDragUpdate,
                          onVerticalDragEnd: widget.onPlayerDragEnd,
                          child: _showTvLanding
                              ? _buildTvLanding(l10n, fillParent: true)
                              : _buildVideoPlayerArea(
                                  isFullScreen: false,
                                  fillParent: true,
                                  compact: t < 0.6,
                                ),
                        ),
                      ),
                      if (t < 1)
                        Expanded(
                          child: Opacity(
                            opacity: 1 - t,
                            child: _buildMiniChrome(
                              title,
                              alternateTitle ?? originalTitle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: ClipRect(
                  child: Opacity(
                    opacity: t,
                    child: IgnorePointer(
                      ignoring: t < 0.99,
                      // Untappable is not enough for a remote: left in the
                      // focus tree, a body faded out behind the mini player
                      // still takes the D-pad. It enters the tree exactly
                      // when it becomes visible.
                      child: ExcludeFocus(
                        excluding: t < 0.99,
                        child: Padding(
                          padding: sideInsets,
                          child: _vm.isLoading
                              ? const Center(child: Loading())
                              : _buildDetailBody(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Title and transport controls sitting next to the collapsed player.
  Widget _buildMiniChrome(String title, String? originalTitle) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (originalTitle != null && constraints.maxWidth > 180)
                      Text(
                        originalTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.7,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (constraints.maxWidth > 90)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  ),
                  onPressed: _togglePlayback,
                ),
              if (constraints.maxWidth > 130)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: l10n.close,
                  icon: const Icon(Icons.close_rounded),
                  onPressed: widget.onClose,
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildVideoPlayerArea({
    required bool isFullScreen,
    bool fillParent = false,
    bool compact = false,
  }) {
    final controller = _videoController;
    final l10n = AppLocalizations.of(context);

    final aspectRatio = (controller != null && controller.value.isInitialized)
        ? controller.value.aspectRatio
        : 16 / 9;

    if (compact) {
      return Container(
        color: Colors.black,
        child: (controller != null && controller.value.isInitialized)
            ? Center(
                child: AspectRatio(
                  aspectRatio: aspectRatio,
                  child: VideoPlayer(controller),
                ),
              )
            : const Center(
                child: SizedBox.square(
                  dimension: 20,
                  child: Loading(size: 20, strokeWidth: 2),
                ),
              ),
      );
    }

    Widget playerWidget = TvFocusSurface(
      node: _videoFocusNode,
      child: Focus(
        focusNode: _videoFocusNode,
        autofocus: true,
        onKeyEvent: _handleVideoKeyEvent,
        child: PlayerBox(
          aspectRatio: aspectRatio,
          // Ultra-wide videos would otherwise be so short that the centre play
          // button covers the progress bar.
          minHeight: (isFullScreen || fillParent) ? 0 : minPlayerHeight,
          fill: isFullScreen || fillParent,
          child: MouseRegion(
            cursor: _showControls
                ? SystemMouseCursors.click
                : SystemMouseCursors.none,
            onEnter: (_) {
              if (!_showControls) {
                setState(() => _showControls = true);
              }
              _startControlsTimer();
            },
            onHover: (_) {
              if (!_showControls) {
                setState(() => _showControls = true);
              }
              _startControlsTimer();
            },
            onExit: (_) {
              if (mounted) {
                setState(() {
                  _showControls = false;
                  _showVolumeControl = false;
                  _isTimelineHovering = false;
                });
                _releaseControlsFocus();
                _controlsTimer?.cancel();
                _volumeHideTimer?.cancel();
              }
            },
            child: Container(
              color: Colors.black,
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  if (controller != null && controller.value.isInitialized)
                    // Zoomed full screen covers the screen, notch area included, so
                    // the sides are cropped rather than letterboxed. Everything else
                    // keeps the whole frame visible.
                    (isFullScreen && _isVideoCover)
                        ? SizedBox.expand(
                            child: FittedBox(
                              fit: BoxFit.cover,
                              clipBehavior: Clip.hardEdge,
                              child: SizedBox(
                                width: controller.value.size.width,
                                height: controller.value.size.height,
                                child: VideoPlayer(controller),
                              ),
                            ),
                          )
                        : Center(
                            child: AspectRatio(
                              aspectRatio: controller.value.aspectRatio,
                              child: VideoPlayer(controller),
                            ),
                          )
                  // `_isLoading` counts too: the detail request runs before the
                  // stream one, and without it the retry button flashes up first.
                  else if (_vm.isLoadingStream || _vm.isLoading)
                    const Center(child: Loading())
                  else
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.play_circle_outline_rounded,
                            size: 56,
                            color: Colors.white54,
                          ),
                          const SizedBox(height: 12),
                          NeuButton(
                            onPressed: () {
                              if (_vm.selectedEpisode != null) {
                                _playEpisode(_vm.selectedEpisode!);
                              } else {
                                _vm.loadDetail(
                                  widget.movieUrl,
                                  widget.movieId,
                                  force: true,
                                );
                              }
                            },
                            accent: Theme.of(context).colorScheme.primary,
                            child: Text(l10n.loadStream),
                          ),
                        ],
                      ),
                    ),

                  if (controller != null && controller.value.isInitialized)
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          _videoFocusNode.requestFocus();
                          _toggleControls();
                        },
                        onDoubleTapDown: (details) {
                          _doubleTapPosition = details.localPosition;
                        },
                        onDoubleTap: () {
                          if (_doubleTapPosition != null) {
                            final width = context.size?.width ?? 0;
                            if (width > 0) {
                              if (_doubleTapPosition!.dx < width / 2) {
                                _seekBy(const Duration(seconds: -10));
                                _triggerSkipIndicator(isForward: false);
                              } else {
                                _seekBy(const Duration(seconds: 10));
                                _triggerSkipIndicator(isForward: true);
                              }
                            }
                          }
                        },
                        onLongPressStart: (_) => _start2xSpeed(),
                        onLongPressEnd: (_) => _stop2xSpeed(),
                        // Pinch out fills the screen, pinch in goes back to the
                        // whole frame — the way a video player is expected to zoom.
                        onScaleUpdate: isFullScreen
                            ? (details) {
                                if (details.pointerCount < 2) return;
                                if (details.scale > 1.15) {
                                  _setVideoCover(true);
                                } else if (details.scale < 0.85) {
                                  _setVideoCover(false);
                                }
                              }
                            : null,
                      ),
                    ),

                  // Refilling the buffer, or rebuilding the player after a stall,
                  // holds the last frame — say so, or it reads as a freeze.
                  //
                  // This slot is occupied whether or not the spinner shows.
                  // Dropping it out of the list shifts every child below it, and
                  // the reconciliation that follows tears down the timeline's
                  // drag recogniser mid-scrub — buffering starts on the very seek
                  // the scrub asks for, so the drag would die as it began.
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Center(
                        child:
                            controller != null &&
                                controller.value.isInitialized &&
                                (_isBuffering || _vm.isLoadingStream)
                            ? const Loading()
                            : const SizedBox.shrink(),
                      ),
                    ),
                  ),

                  // Always-on Overlays (2x, Skip indicators)
                  if (controller != null && controller.value.isInitialized)
                    Positioned.fill(
                      child: PlayerGestureOverlays(
                        isSpeedBoosted: _isSpeedBoosted,
                        skipForwardValue: _skipForwardValue,
                        skipBackwardValue: _skipBackwardValue,
                      ),
                    ),

                  // Video Controls Overlay
                  if (controller != null && controller.value.isInitialized)
                    Positioned.fill(
                      child: ExcludeFocus(
                        // Hidden, the bar is only invisible and untappable —
                        // it stays perfectly focusable, so the D-pad lands on
                        // a play button nobody can see and OK presses it. An
                        // arrow brings the bar back and puts the remote on it
                        // in the same press.
                        excluding: !_showControls,
                        child: IgnorePointer(
                          ignoring: !_showControls,
                          child: AnimatedOpacity(
                            opacity: _showControls ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 300),
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    // Tapping the video only shows and hides the
                                    // controls, never plays or pauses. Play/pause
                                    // is the centre button's job, so a tap meant to
                                    // dismiss the controls cannot stop the film.
                                    onTap: () {
                                      _videoFocusNode.requestFocus();
                                      _toggleControls();
                                    },
                                    onDoubleTapDown: (details) {
                                      _doubleTapPosition =
                                          details.localPosition;
                                    },
                                    onDoubleTap: () {
                                      if (_doubleTapPosition != null) {
                                        final width = context.size?.width ?? 0;
                                        if (width > 0) {
                                          if (_doubleTapPosition!.dx <
                                              width / 2) {
                                            _seekBy(
                                              const Duration(seconds: -10),
                                            );
                                            _triggerSkipIndicator(
                                              isForward: false,
                                            );
                                          } else {
                                            _seekBy(
                                              const Duration(seconds: 10),
                                            );
                                            _triggerSkipIndicator(
                                              isForward: true,
                                            );
                                          }
                                        }
                                      }
                                    },
                                    onLongPressStart: (_) => _start2xSpeed(),
                                    onLongPressEnd: (_) => _stop2xSpeed(),
                                  ),
                                ),
                                // Bottom Gradient and Controls
                                PlayerControlsFocus(
                                  node: _bottomControlsScope,
                                  // Up is the way off the bottom bar: back onto
                                  // the picture, not further into the page.
                                  //
                                  // On a television it leads to the bar above
                                  // instead, which the remote otherwise has no
                                  // way to reach: up from the picture is what
                                  // enters this bar, and down from the top bar
                                  // is what comes back to the picture. Down
                                  // out of this bar is left to traversal, which
                                  // is how the episode list under an inline
                                  // player is reached.
                                  exit: TraversalDirection.up,
                                  onExit: () {
                                    _cancelScrub();
                                    if (deviceType.isTv) {
                                      _enterControls(true, afterFrame: false);
                                    } else {
                                      _videoFocusNode.requestFocus();
                                    }
                                    _startControlsTimer();
                                  },
                                  child: Align(
                                    alignment: Alignment.bottomCenter,
                                    child: Container(
                                      padding: EdgeInsets.only(
                                        bottom:
                                            4 +
                                            (isFullScreen
                                                ? MediaQuery.paddingOf(
                                                    context,
                                                  ).bottom
                                                : 0),
                                        left: isFullScreen
                                            ? MediaQuery.paddingOf(context).left
                                            : 0,
                                        right: isFullScreen
                                            ? MediaQuery.paddingOf(
                                                context,
                                              ).right
                                            : 0,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.transparent,
                                            Colors.black.withValues(alpha: 0.7),
                                          ],
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                        ),
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          LayoutBuilder(
                                            builder: (context, constraints) {
                                              const previewWidth = 160.0;
                                              final maxPreviewLeft =
                                                  constraints.maxWidth >
                                                      previewWidth
                                                  ? constraints.maxWidth -
                                                        previewWidth
                                                  : 0.0;
                                              final previewLeft =
                                                  (constraints.maxWidth *
                                                              _dragFraction -
                                                          previewWidth / 2)
                                                      .clamp(
                                                        0.0,
                                                        maxPreviewLeft,
                                                      );

                                              return Stack(
                                                clipBehavior: Clip.none,
                                                children: [
                                                  // The seek bar as a control
                                                  // of its own, so a remote
                                                  // can stand on it: the
                                                  // arrows walk a marker
                                                  // along it and OK commits.
                                                  Focus(
                                                    focusNode:
                                                        _timelineFocusNode,
                                                    onKeyEvent:
                                                        _handleTimelineKeyEvent,
                                                    child: MouseRegion(
                                                      cursor: SystemMouseCursors
                                                          .click,
                                                      onEnter: (event) =>
                                                          _updateHoverPreview(
                                                            event
                                                                .localPosition
                                                                .dx,
                                                            constraints
                                                                .maxWidth,
                                                          ),
                                                      onHover: (event) =>
                                                          _updateHoverPreview(
                                                            event
                                                                .localPosition
                                                                .dx,
                                                            constraints
                                                                .maxWidth,
                                                          ),
                                                      onExit: (_) {
                                                        if (_isTimelineHovering) {
                                                          setState(
                                                            () =>
                                                                _isTimelineHovering =
                                                                    false,
                                                          );
                                                        }
                                                        _startControlsTimer();
                                                      },
                                                      child: GestureDetector(
                                                        behavior:
                                                            HitTestBehavior
                                                                .opaque,
                                                        onHorizontalDragStart:
                                                            (details) {
                                                              _resumeAfterDrag =
                                                                  controller
                                                                      .value
                                                                      .isPlaying;
                                                              unawaited(
                                                                controller
                                                                    .pause(),
                                                              );
                                                              _controlsTimer
                                                                  ?.cancel();
                                                              setState(
                                                                () =>
                                                                    _isDragging =
                                                                        true,
                                                              );
                                                              _updateDragPosition(
                                                                controller,
                                                                details
                                                                    .localPosition
                                                                    .dx,
                                                                constraints
                                                                    .maxWidth,
                                                              );
                                                            },
                                                        onHorizontalDragUpdate:
                                                            (details) {
                                                              _updateDragPosition(
                                                                controller,
                                                                details
                                                                    .localPosition
                                                                    .dx,
                                                                constraints
                                                                    .maxWidth,
                                                              );
                                                            },
                                                        onHorizontalDragEnd:
                                                            (_) =>
                                                                _finishDragging(
                                                                  controller,
                                                                ),
                                                        onHorizontalDragCancel:
                                                            () =>
                                                                _finishDragging(
                                                                  controller,
                                                                ),
                                                        onTapDown: (details) {
                                                          _updateDragPosition(
                                                            controller,
                                                            details
                                                                .localPosition
                                                                .dx,
                                                            constraints
                                                                .maxWidth,
                                                          );
                                                        },
                                                        child: Padding(
                                                          padding:
                                                              const EdgeInsets.only(
                                                                top: 10,
                                                                bottom: 2,
                                                              ),
                                                          child: VideoSeekBar(
                                                            controller:
                                                                controller,
                                                            isFocused:
                                                                _timelineFocusNode
                                                                    .hasFocus,
                                                            isHovered:
                                                                _isTimelineHovering,
                                                            isDragging:
                                                                _isDragging,
                                                            isScrubbing:
                                                                _isScrubbing,
                                                            dragFraction:
                                                                _dragFraction,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  if (_isDragging ||
                                                      _isTimelineHovering ||
                                                      _isScrubbing)
                                                    Positioned(
                                                      left: previewLeft,
                                                      bottom: 42,
                                                      child: PlayerScrubPreview(
                                                        track:
                                                            _vm.thumbnailTrack,
                                                        cue: _hoverThumbnailCue,
                                                        width: previewWidth,
                                                        referer:
                                                            '${movieService.effectiveBaseUrl}/',
                                                        fallback: VideoPlayer(
                                                          controller,
                                                        ),
                                                        position: _dragPosition,
                                                      ),
                                                    ),
                                                ],
                                              );
                                            },
                                          ),
                                          LayoutBuilder(
                                            builder: (context, constraints) {
                                              final isNarrow =
                                                  constraints.maxWidth <
                                                  Dimens.playerNarrowThreshold;
                                              return Row(
                                                children: [
                                                  const SizedBox(width: 8),
                                                  if (!isNarrow &&
                                                      _hasPreviousEpisode)
                                                    IconButton(
                                                      tooltip:
                                                          l10n.previousEpisode,
                                                      icon: const Icon(
                                                        Icons
                                                            .skip_previous_rounded,
                                                        color: Colors.white,
                                                        size: 24,
                                                      ),
                                                      onPressed:
                                                          _playPreviousEpisode,
                                                    ),
                                                  if (!isNarrow)
                                                    IconButton(
                                                      icon: Icon(
                                                        _isPlaying
                                                            ? Icons
                                                                  .pause_rounded
                                                            : Icons
                                                                  .play_arrow_rounded,
                                                        color: Colors.white,
                                                        size: 28,
                                                      ),
                                                      onPressed:
                                                          _togglePlayback,
                                                    ),
                                                  if (!isNarrow &&
                                                      _hasNextEpisode)
                                                    IconButton(
                                                      tooltip: l10n.nextEpisode,
                                                      icon: const Icon(
                                                        Icons.skip_next_rounded,
                                                        color: Colors.white,
                                                        size: 24,
                                                      ),
                                                      onPressed:
                                                          _playNextEpisode,
                                                    ),
                                                  const SizedBox(width: 4),
                                                  ValueListenableBuilder(
                                                    valueListenable: controller,
                                                    builder:
                                                        (
                                                          context,
                                                          VideoPlayerValue
                                                          value,
                                                          child,
                                                        ) {
                                                          final currentPos =
                                                              (_isDragging ||
                                                                  _isScrubbing)
                                                              ? _dragPosition
                                                              : (_virtualSeekPosition ??
                                                                    value
                                                                        .position);
                                                          return Text(
                                                            '${formatDuration(currentPos)} / ${formatDuration(value.duration)}',
                                                            style:
                                                                const TextStyle(
                                                                  color: Colors
                                                                      .white,
                                                                  fontSize: 12,
                                                                ),
                                                          );
                                                        },
                                                  ),
                                                  const Spacer(),
                                                  CompositedTransformTarget(
                                                    link: _volumeButtonLink,
                                                    child: PlayerVolumeButton(
                                                      icon: _volumeIcon,
                                                      muted: _volume == 0,
                                                      tooltip: _volume == 0
                                                          ? l10n.unmute
                                                          : l10n.volume,
                                                      onTap: _handleVolumeTap,
                                                      onLongPress: _toggleMute,
                                                      onHover: (hovering) {
                                                        if (hovering) {
                                                          if (!_showVolumeControl) {
                                                            setState(
                                                              () =>
                                                                  _showVolumeControl =
                                                                      true,
                                                            );
                                                            _controlsTimer
                                                                ?.cancel();
                                                            _volumeHideTimer
                                                                ?.cancel();
                                                          }
                                                        } else {
                                                          _volumeHideTimer
                                                              ?.cancel();
                                                          _volumeHideTimer = Timer(
                                                            const Duration(
                                                              milliseconds: 200,
                                                            ),
                                                            () {
                                                              if (mounted) {
                                                                setState(
                                                                  () =>
                                                                      _showVolumeControl =
                                                                          false,
                                                                );
                                                                _startControlsTimer();
                                                              }
                                                            },
                                                          );
                                                        }
                                                      },
                                                    ),
                                                  ),
                                                  // Fit / fill toggle, full screen only —
                                                  // inline there is nothing to crop to.
                                                  if (isFullScreen)
                                                    IconButton(
                                                      tooltip: _isVideoCover
                                                          ? l10n.zoomToFit
                                                          : l10n.zoomToFill,
                                                      icon: Icon(
                                                        _isVideoCover
                                                            ? Icons
                                                                  .zoom_in_map_rounded
                                                            : Icons
                                                                  .zoom_out_map_rounded,
                                                        color: Colors.white,
                                                      ),
                                                      onPressed: () =>
                                                          _setVideoCover(
                                                            !_isVideoCover,
                                                          ),
                                                    ),
                                                  // Fullscreen button
                                                  IconButton(
                                                    icon: Icon(
                                                      isFullScreen
                                                          ? Icons
                                                                .fullscreen_exit_rounded
                                                          : Icons
                                                                .fullscreen_rounded,
                                                      color: Colors.white,
                                                    ),
                                                    onPressed:
                                                        _toggleFullScreen,
                                                  ),
                                                ],
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),

                                // Center Controls (Play/Pause, Next/Prev)
                                // Only shown if the bottom bar is too narrow to hold them
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    if (constraints.maxWidth >=
                                            Dimens.playerNarrowThreshold ||
                                        _isDragging) {
                                      return const SizedBox.shrink();
                                    }
                                    return Center(
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Align(
                                              alignment: Alignment.centerRight,
                                              child: _hasPreviousEpisode
                                                  ? PlayerCenterButton(
                                                      icon: Icons
                                                          .skip_previous_rounded,
                                                      size: 44,
                                                      onPressed:
                                                          _playPreviousEpisode,
                                                    )
                                                  : const SizedBox.shrink(),
                                            ),
                                          ),
                                          const SizedBox(width: 32),
                                          PlayerCenterButton(
                                            icon: _isPlaying
                                                ? Icons.pause_rounded
                                                : Icons.play_arrow_rounded,
                                            size: 64,
                                            onPressed: _togglePlayback,
                                          ),
                                          const SizedBox(width: 32),
                                          Expanded(
                                            child: Align(
                                              alignment: Alignment.centerLeft,
                                              child: _hasNextEpisode
                                                  ? PlayerCenterButton(
                                                      icon: Icons
                                                          .skip_next_rounded,
                                                      size: 44,
                                                      onPressed:
                                                          _playNextEpisode,
                                                    )
                                                  : const SizedBox.shrink(),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),

                                if (_showVolumeControl)
                                  Positioned(
                                    left: 0,
                                    top: 0,
                                    // Follows the button itself, so it stays centred
                                    // on it no matter how the bar is laid out.
                                    child: CompositedTransformFollower(
                                      link: _volumeButtonLink,
                                      showWhenUnlinked: false,
                                      targetAnchor: Alignment.topCenter,
                                      followerAnchor: Alignment.bottomCenter,
                                      offset: const Offset(0, -4),
                                      child: MouseRegion(
                                        onEnter: (_) {
                                          _controlsTimer?.cancel();
                                          _volumeHideTimer?.cancel();
                                        },
                                        onExit: (_) {
                                          setState(
                                            () => _showVolumeControl = false,
                                          );
                                          _startControlsTimer();
                                        },
                                        child: PlayerVolumePopup(
                                          volume: _volume,
                                          onChanged: _setVolume,
                                          onChangeStart: () =>
                                              _controlsTimer?.cancel(),
                                        ),
                                      ),
                                    ),
                                  ),

                                // Top bar with back icon and settings
                                Positioned(
                                  top:
                                      12 +
                                      (isFullScreen
                                          ? MediaQuery.paddingOf(context).top
                                          : 0),
                                  left:
                                      12 +
                                      (isFullScreen
                                          ? MediaQuery.paddingOf(context).left
                                          : 0),
                                  right:
                                      12 +
                                      (isFullScreen
                                          ? MediaQuery.paddingOf(context).right
                                          : 0),
                                  child: PlayerControlsFocus(
                                    node: _topControlsScope,
                                    exit: TraversalDirection.down,
                                    onExit: () {
                                      _videoFocusNode.requestFocus();
                                      _startControlsTimer();
                                    },
                                    child: PlayerTopBar(
                                      showBack: isFullScreen,
                                      onBack: _toggleFullScreen,
                                      onSettings: _showSettingsBottomSheet,
                                      title: isFullScreen
                                          ? splitMovieTitle(
                                              _vm.detail?.title ?? '',
                                            ).title
                                          : null,
                                      subtitle: isFullScreen
                                          ? [
                                                  splitMovieTitle(
                                                    _vm.detail?.title ?? '',
                                                  ).subtitle,
                                                  _vm.selectedEpisode?.name,
                                                ]
                                                .whereType<String>()
                                                .where((s) => s.isNotEmpty)
                                                .join(' • ')
                                          : null,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (isFullScreen) {
      return SizedBox.expand(child: playerWidget);
    }
    return playerWidget;
  }
}

/// One episode in the grid laid over the player, sized and spaced to be read
/// and hit from across a room rather than with a fingertip.
class _EpisodeOverlayTile extends StatelessWidget {
  const _EpisodeOverlayTile({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.focusNode,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FocusableTap(
      focusNode: focusNode,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Dimens.pagePadding,
          vertical: Dimens.modalItemSpacing,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? scheme.primary
              : Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(Dimens.radiusControl),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? scheme.onPrimary : Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
