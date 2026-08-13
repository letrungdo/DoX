import 'dart:async';
import 'dart:math' as math;

import 'package:auto_route/auto_route.dart';
import 'package:do_x/constants/dimens.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/model/movie_model.dart';
import 'package:do_x/router/app_router.gr.dart';
import 'package:do_x/screen/core/screen_state.dart';
import 'package:do_x/screen/movie/movie_detail_body.dart';
import 'package:do_x/screen/movie/movie_player_controls.dart';
import 'package:do_x/screen/movie/movie_player_layout.dart';
import 'package:do_x/screen/movie/movie_settings_sheet.dart';
import 'package:do_x/screen/movie/movie_thumbnail_track.dart';
import 'package:do_x/services/movie_service.dart';
import 'package:do_x/utils/logger.dart';
import 'package:do_x/view_model/movie/movie_detail_view_model.dart';
import 'package:do_x/widgets/app_bar/app_bar_base.dart';
import 'package:do_x/widgets/app_scaffold.dart';
import 'package:do_x/widgets/dialog/app_modal.dart';
import 'package:do_x/widgets/loading.dart';
import 'package:do_x/widgets/neu/neu_button.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_orientation_manager/flutter_orientation_manager.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

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

/// Lets the overlay host drive the embedded detail screen — currently only to
/// leave full screen, which the host cannot do on its own.
class MovieDetailController {
  VoidCallback? _exitFullScreen;

  void exitFullScreen() => _exitFullScreen?.call();
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
  bool _isSpacePressed = false;
  Timer? _spaceLongPressTimer;
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

  bool get _supportsOrientationManager =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _vm = context.read<MovieDetailViewModel>();
  }

  @override
  void initState() {
    super.initState();
    logger.d('MovieDetailScreen: initState');
    widget.controller?._exitFullScreen = _exitFullScreen;
    _initOrientationListener();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final shouldAutoEnterFullScreen =
          kIsWeb || defaultTargetPlatform == TargetPlatform.macOS;
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
    if (_vm.selectedEpisode != null && _videoController == null) {
      _playEpisode(_vm.selectedEpisode!);
    }
    super.initData();
  }

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
      if (oldWidget.controller?._exitFullScreen == _exitFullScreen) {
        oldWidget.controller?._exitFullScreen = null;
      }
      widget.controller?._exitFullScreen = _exitFullScreen;
    }
    if (oldWidget.movieId != widget.movieId ||
        oldWidget.movieUrl != widget.movieUrl) {
      unawaited(_detachAndDisposeController());
      () async {
        await _vm.init(
          widget.movieUrl,
          widget.movieId,
          initialMovie: widget.initialMovie,
        );
        if (!mounted) return;
        if (_vm.selectedEpisode != null && _videoController == null) {
          _playEpisode(_vm.selectedEpisode!);
        }
      }();
    }
  }

  @override
  void dispose() {
    logger.d('MovieDetailScreen: dispose');
    if (widget.controller?._exitFullScreen == _exitFullScreen) {
      widget.controller?._exitFullScreen = null;
    }
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
    _volumeHideTimer?.cancel();
    _orientationSubscription?.cancel();
    _videoFocusNode.dispose();
    _progressTimer?.cancel();
    _watchdogTimer?.cancel();

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
      httpHeaders: {'Referer': '${movieService.baseUrl}/'},
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

  void _startControlsTimer() {
    _controlsTimer?.cancel();
    if (_isPlaying && !_showVolumeControl) {
      _controlsTimer = Timer(const Duration(seconds: 3), () {
        if (mounted && !_isTimelineHovering && !_isDragging) {
          setState(() => _showControls = false);
        }
      });
    }
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
    if (_showControls) _startControlsTimer();
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
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.space) {
        if (!_isSpacePressed) {
          _isSpacePressed = true;
          _spaceLongPressTimer?.cancel();
          _spaceLongPressTimer = Timer(const Duration(milliseconds: 500), () {
            if (_isSpacePressed && mounted) {
              _start2xSpeed();
            }
          });
        }
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.escape && _isFullScreen) {
        _exitFullScreen();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        _seekBy(const Duration(seconds: -10));
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        _seekBy(const Duration(seconds: 10));
        return KeyEventResult.handled;
      }
    } else if (event is KeyRepeatEvent) {
      if (event.logicalKey == LogicalKeyboardKey.space) {
        return KeyEventResult.handled;
      }
    } else if (event is KeyUpEvent) {
      if (event.logicalKey == LogicalKeyboardKey.space) {
        _spaceLongPressTimer?.cancel();
        if (_isSpacePressed) {
          if (_isSpeedBoosted) {
            _stop2xSpeed();
          } else {
            _togglePlayback();
          }
          _isSpacePressed = false;
        }
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
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
    if (!mounted || action == null) return;

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

  void _triggerSkipIndicator({required bool isForward}) {
    if (isForward) {
      _skipForwardTimer?.cancel();
      setState(() => _skipForwardValue += 10);
      _skipForwardTimer = Timer(const Duration(milliseconds: 600), () {
        if (mounted) setState(() => _skipForwardValue = 0);
      });
    } else {
      _skipBackwardTimer?.cancel();
      setState(() => _skipBackwardValue += 10);
      _skipBackwardTimer = Timer(const Duration(milliseconds: 600), () {
        if (mounted) setState(() => _skipBackwardValue = 0);
      });
    }
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

        return PopScope(
          canPop: widget.embedded || !_isFullScreen,
          onPopInvokedWithResult: (didPop, result) {
            if (!widget.embedded && _isFullScreen) {
              _toggleFullScreen();
            }
          },
          child: _isFullScreen
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
                              _buildVideoPlayerArea(isFullScreen: false),
                              Expanded(child: _buildDetailBody()),
                            ],
                          ),
                  ),
                ),
        );
      },
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
                          child: _buildVideoPlayerArea(
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

    Widget playerWidget = Focus(
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
              });
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
                              ),
                            ),
                            // Bottom Gradient and Controls
                            Align(
                              alignment: Alignment.bottomCenter,
                              child: Container(
                                padding: EdgeInsets.only(
                                  bottom:
                                      4 +
                                      (isFullScreen
                                          ? MediaQuery.paddingOf(context).bottom
                                          : 0),
                                  left: isFullScreen
                                      ? MediaQuery.paddingOf(context).left
                                      : 0,
                                  right: isFullScreen
                                      ? MediaQuery.paddingOf(context).right
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
                                            constraints.maxWidth > previewWidth
                                            ? constraints.maxWidth -
                                                  previewWidth
                                            : 0.0;
                                        final previewLeft =
                                            (constraints.maxWidth *
                                                        _dragFraction -
                                                    previewWidth / 2)
                                                .clamp(0.0, maxPreviewLeft);

                                        return Stack(
                                          clipBehavior: Clip.none,
                                          children: [
                                            MouseRegion(
                                              cursor: SystemMouseCursors.click,
                                              onEnter: (event) =>
                                                  _updateHoverPreview(
                                                    event.localPosition.dx,
                                                    constraints.maxWidth,
                                                  ),
                                              onHover: (event) =>
                                                  _updateHoverPreview(
                                                    event.localPosition.dx,
                                                    constraints.maxWidth,
                                                  ),
                                              onExit: (_) {
                                                if (_isTimelineHovering) {
                                                  setState(
                                                    () => _isTimelineHovering =
                                                        false,
                                                  );
                                                }
                                                _startControlsTimer();
                                              },
                                              child: GestureDetector(
                                                behavior:
                                                    HitTestBehavior.opaque,
                                                onHorizontalDragStart:
                                                    (details) {
                                                      _resumeAfterDrag =
                                                          controller
                                                              .value
                                                              .isPlaying;
                                                      unawaited(
                                                        controller.pause(),
                                                      );
                                                      _controlsTimer?.cancel();
                                                      setState(
                                                        () =>
                                                            _isDragging = true,
                                                      );
                                                      _updateDragPosition(
                                                        controller,
                                                        details
                                                            .localPosition
                                                            .dx,
                                                        constraints.maxWidth,
                                                      );
                                                    },
                                                onHorizontalDragUpdate:
                                                    (details) {
                                                      _updateDragPosition(
                                                        controller,
                                                        details
                                                            .localPosition
                                                            .dx,
                                                        constraints.maxWidth,
                                                      );
                                                    },
                                                onHorizontalDragEnd: (_) =>
                                                    _finishDragging(controller),
                                                onHorizontalDragCancel: () =>
                                                    _finishDragging(controller),
                                                onTapDown: (details) {
                                                  _updateDragPosition(
                                                    controller,
                                                    details.localPosition.dx,
                                                    constraints.maxWidth,
                                                  );
                                                },
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        top: 14,
                                                        bottom: 2,
                                                      ),
                                                  child: VideoProgressIndicator(
                                                    controller,
                                                    allowScrubbing: false,
                                                    colors:
                                                        const VideoProgressColors(
                                                          playedColor:
                                                              Colors.pinkAccent,
                                                          bufferedColor:
                                                              Colors.white30,
                                                          backgroundColor:
                                                              Colors.white12,
                                                        ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            if (_isDragging ||
                                                _isTimelineHovering)
                                              Positioned(
                                                left: previewLeft,
                                                bottom: 42,
                                                child: PlayerScrubPreview(
                                                  track: _vm.thumbnailTrack,
                                                  cue: _hoverThumbnailCue,
                                                  width: previewWidth,
                                                  referer:
                                                      '${movieService.baseUrl}/',
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
                                                tooltip: l10n.previousEpisode,
                                                icon: const Icon(
                                                  Icons.skip_previous_rounded,
                                                  color: Colors.white,
                                                  size: 24,
                                                ),
                                                onPressed: _playPreviousEpisode,
                                              ),
                                            if (!isNarrow)
                                              IconButton(
                                                icon: Icon(
                                                  _isPlaying
                                                      ? Icons.pause_rounded
                                                      : Icons
                                                            .play_arrow_rounded,
                                                  color: Colors.white,
                                                  size: 28,
                                                ),
                                                onPressed: _togglePlayback,
                                              ),
                                            if (!isNarrow && _hasNextEpisode)
                                              IconButton(
                                                tooltip: l10n.nextEpisode,
                                                icon: const Icon(
                                                  Icons.skip_next_rounded,
                                                  color: Colors.white,
                                                  size: 24,
                                                ),
                                                onPressed: _playNextEpisode,
                                              ),
                                            const SizedBox(width: 4),
                                            ValueListenableBuilder(
                                              valueListenable: controller,
                                              builder:
                                                  (
                                                    context,
                                                    VideoPlayerValue value,
                                                    child,
                                                  ) {
                                                    final currentPos =
                                                        _isDragging
                                                        ? _dragPosition
                                                        : (_virtualSeekPosition ??
                                                              value.position);
                                                    return Text(
                                                      '${formatDuration(currentPos)} / ${formatDuration(value.duration)}',
                                                      style: const TextStyle(
                                                        color: Colors.white,
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
                                                      _controlsTimer?.cancel();
                                                      _volumeHideTimer
                                                          ?.cancel();
                                                    }
                                                  } else {
                                                    _volumeHideTimer?.cancel();
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
                                                onPressed: () => _setVideoCover(
                                                  !_isVideoCover,
                                                ),
                                              ),
                                            // Fullscreen button
                                            IconButton(
                                              icon: Icon(
                                                isFullScreen
                                                    ? Icons
                                                          .fullscreen_exit_rounded
                                                    : Icons.fullscreen_rounded,
                                                color: Colors.white,
                                              ),
                                              onPressed: _toggleFullScreen,
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  ],
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
                                                  icon: Icons.skip_next_rounded,
                                                  size: 44,
                                                  onPressed: _playNextEpisode,
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
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
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
