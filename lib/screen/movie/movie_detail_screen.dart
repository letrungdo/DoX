import 'dart:async';
import 'dart:math' as math;

import 'package:auto_route/auto_route.dart';
import 'package:dio/dio.dart';
import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/model/movie_model.dart';
import 'package:do_x/router/app_router.gr.dart';
import 'package:do_x/screen/movie/movie_detail_body.dart';
import 'package:do_x/screen/movie/movie_player_controls.dart';
import 'package:do_x/screen/movie/movie_player_layout.dart';
import 'package:do_x/screen/movie/movie_settings_sheet.dart';
import 'package:do_x/screen/movie/movie_thumbnail_track.dart';
import 'package:do_x/services/movie_library_service.dart';
import 'package:do_x/services/movie_service.dart';
import 'package:do_x/utils/logger.dart';
import 'package:do_x/widgets/app_bar/app_bar_base.dart';
import 'package:do_x/widgets/neu/neu_button.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_orientation_manager/flutter_orientation_manager.dart';
import 'package:video_player/video_player.dart';

@RoutePage()
class MovieDetailScreen extends StatefulWidget {
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
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

/// Lets the overlay host drive the embedded detail screen — currently only to
/// leave full screen, which the host cannot do on its own.
class MovieDetailController {
  VoidCallback? _exitFullScreen;

  void exitFullScreen() => _exitFullScreen?.call();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  MovieDetail? _detail;
  bool _isLoading = true;
  VideoPlayerController? _videoController;
  bool _isPlaying = false;
  bool _isFullScreen = false;
  MovieEpisodeServer? _selectedServer;
  MovieEpisode? _selectedEpisode;
  bool _isLoadingStream = false;
  double _playbackSpeed = 1.0;
  double _volume = 1.0;
  double _lastAudibleVolume = 1.0;
  bool _showVolumeControl = false;
  bool _showControls = true;
  Timer? _controlsTimer;
  StreamSubscription<Orientation>? _orientationSubscription;
  final FocusNode _videoFocusNode = FocusNode(debugLabel: 'movie-video');
  VoidCallback? _videoValueListener;
  int _controllerGeneration = 0;
  int _detailGeneration = 0;
  int _thumbnailGeneration = 0;
  int _qualityGeneration = 0;

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
  ThumbnailTrack? _thumbnailTrack;
  ThumbnailCue? _hoverThumbnailCue;

  final _cancelToken = CancelToken();

  String _selectedQuality = 'Auto';
  List<MovieStreamVariant> _availableQualities = const [];
  String? _masterStreamUrl;
  bool _isFavorite = false;
  bool _isUpdatingFavorite = false;
  bool _hasRecordedWatch = false;
  bool _isRotationLocked = false;

  Duration? _virtualSeekPosition;
  Timer? _virtualSeekTimer;

  bool get _supportsOrientationManager =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void initState() {
    super.initState();
    logger.d('MovieDetailScreen: initState');
    widget.controller?._exitFullScreen = _exitFullScreen;
    _loadDetail();
    _loadLibraryState();
    _initOrientationListener();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final shouldAutoEnterFullScreen = kIsWeb || defaultTargetPlatform == TargetPlatform.macOS;
      if (mounted && shouldAutoEnterFullScreen) _enterFullScreen();
    });
  }

  void _initOrientationListener() {
    if (!_supportsOrientationManager) return;
    _orientationSubscription = FlutterOrientationManager.orientationStream.listen((orientation) {
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
    if (oldWidget.movieId != widget.movieId || oldWidget.movieUrl != widget.movieUrl) {
      _hasRecordedWatch = false;
      _isFavorite = false;
      unawaited(_detachAndDisposeController());
      _loadDetail();
      _loadLibraryState();
    }
  }

  @override
  void dispose() {
    logger.d('MovieDetailScreen: dispose');
    if (widget.controller?._exitFullScreen == _exitFullScreen) {
      widget.controller?._exitFullScreen = null;
    }
    _controllerGeneration++;
    _detailGeneration++;
    _thumbnailGeneration++;
    _qualityGeneration++;
    final controller = _videoController;
    final listener = _videoValueListener;
    _videoController = null;
    _videoValueListener = null;
    if (controller != null) {
      if (listener != null) controller.removeListener(listener);
      unawaited(controller.dispose());
    }
    _controlsTimer?.cancel();
    _orientationSubscription?.cancel();
    _videoFocusNode.dispose();
    _cancelToken.cancel();

    // Reset everything to normal
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    if (_supportsOrientationManager) {
      FlutterOrientationManager.enableAutoRotation();
    }

    super.dispose();
  }

  Future<void> _loadDetail({bool showLoading = true}) async {
    final generation = ++_detailGeneration;
    if (showLoading) setState(() => _isLoading = true);
    final detail = await movieService.getMovieDetail(widget.movieUrl, widget.movieId, cancelToken: _cancelToken);
    if (!mounted || generation != _detailGeneration) return;
    setState(() {
      _detail = detail;
      _isLoading = false;
      _masterStreamUrl = detail?.streamUrl;
      _thumbnailTrack = null;
      _hoverThumbnailCue = null;
      if (detail != null && detail.servers.isNotEmpty) {
        _selectedServer = detail.servers.first;
        if (_selectedServer!.episodes.isNotEmpty) {
          _selectedEpisode = _selectedServer!.episodes.first;
        }
      }
    });

    final thumbnailTrackUrl = detail?.thumbnailTrackUrl;
    if (thumbnailTrackUrl != null && thumbnailTrackUrl.isNotEmpty) {
      unawaited(_loadThumbnailTrack(thumbnailTrackUrl, generation));
    }

    if (_masterStreamUrl != null && _masterStreamUrl!.isNotEmpty) {
      unawaited(_useMasterStream(_masterStreamUrl!));
    }
  }

  Future<void> _refreshDetail() async {
    await Future.wait<void>([_loadDetail(showLoading: false), _loadLibraryState()]);
  }

  Future<void> _loadThumbnailTrack(String trackUrl, int detailGeneration) async {
    final generation = ++_thumbnailGeneration;
    try {
      final response = await Dio().get<String>(
        trackUrl,
        options: Options(
          responseType: ResponseType.plain,
          headers: {
            'Referer': '${movieService.baseUrl}/',
            'User-Agent':
                'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
                'AppleWebKit/537.36 Chrome/120 Safari/537.36',
          },
        ),
      );
      final track = ThumbnailTrack.parse(trackUrl, response.data ?? '');
      if (!mounted || generation != _thumbnailGeneration || detailGeneration != _detailGeneration || track == null) {
        return;
      }
      setState(() {
        _thumbnailTrack = track;
        if (_isTimelineHovering || _isDragging) {
          _hoverThumbnailCue = track.cueAt(_dragPosition);
        }
      });
      unawaited(precacheImage(NetworkImage(track.spriteUrl, headers: {'Referer': '${movieService.baseUrl}/'}), context).catchError((_) {}));
    } catch (error, stackTrace) {
      logger.e('MovieDetailScreen: thumbnail track unavailable', error: error, stackTrace: stackTrace);
    }
  }

  Future<void> _useMasterStream(String masterUrl) async {
    final generation = ++_qualityGeneration;
    setState(() {
      _masterStreamUrl = masterUrl;
      _selectedQuality = 'Auto';
      _availableQualities = const [];
      _isLoadingStream = true;
    });
    final variants = await movieService.getStreamVariants(masterUrl);
    if (!mounted || generation != _qualityGeneration || masterUrl != _masterStreamUrl) {
      return;
    }
    final selectedQuality = variants.isEmpty ? 'Auto' : variants.first.label;
    final selectedUrl = variants.isEmpty ? masterUrl : variants.first.url;
    setState(() {
      _availableQualities = variants;
      _selectedQuality = selectedQuality;
    });
    await _initVideoPlayer(selectedUrl);
  }

  String? _qualityUrlFor(String quality) {
    final masterUrl = _masterStreamUrl;
    if (masterUrl == null) return null;
    if (quality == 'Auto') return masterUrl;
    for (final variant in _availableQualities) {
      if (variant.label == quality) return variant.url;
    }
    return null;
  }

  Movie get _libraryMovie {
    final detail = _detail;
    final initialMovie = widget.initialMovie;
    final title = detail?.title.isNotEmpty == true ? detail!.title : initialMovie?.title ?? '';
    final poster = detail?.poster.isNotEmpty == true ? detail!.poster : initialMovie?.poster ?? '';
    final description = detail?.description.isNotEmpty == true ? detail!.description : initialMovie?.description;
    return Movie(id: widget.movieId, title: title, url: widget.movieUrl, poster: poster, description: description);
  }

  Future<void> _loadLibraryState() async {
    final movieId = widget.movieId;
    try {
      final state = await movieLibraryService.getState(movieId);
      if (!mounted || movieId != widget.movieId) return;
      setState(() {
        _isFavorite = state.isFavorite;
      });
    } catch (error, stackTrace) {
      logger.e('MovieDetailScreen: load library state failed', error: error, stackTrace: stackTrace);
    }
  }

  Future<void> _recordWatched() async {
    if (_hasRecordedWatch) return;
    _hasRecordedWatch = true;
    try {
      await movieLibraryService.markWatched(_libraryMovie);
    } catch (error, stackTrace) {
      _hasRecordedWatch = false;
      logger.e('MovieDetailScreen: mark watched failed', error: error, stackTrace: stackTrace);
    }
  }

  Future<void> _toggleFavorite() async {
    final l10n = AppLocalizations.of(context);
    if (_isUpdatingFavorite) return;
    final nextValue = !_isFavorite;
    setState(() => _isUpdatingFavorite = true);
    try {
      await movieLibraryService.setFavorite(_libraryMovie, nextValue);
      if (!mounted) return;
      setState(() => _isFavorite = nextValue);
    } catch (error, stackTrace) {
      logger.e('MovieDetailScreen: update favorite failed', error: error, stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.updateFavoriteFailed)));
      }
    } finally {
      if (mounted) setState(() => _isUpdatingFavorite = false);
    }
  }

  Future<void> _initVideoPlayer(String url, {Duration? seekTo}) async {
    final generation = ++_controllerGeneration;
    final oldController = _videoController;
    final oldListener = _videoValueListener;
    final l10n = AppLocalizations.of(context);
    setState(() {
      _isLoadingStream = true;
      _showControls = true;
      _videoController = null;
      _videoValueListener = null;
      _isTimelineHovering = false;
    });

    if (oldController != null) {
      if (oldListener != null) oldController.removeListener(oldListener);
      await WidgetsBinding.instance.endOfFrame;
      await oldController.dispose();
    }
    if (!mounted || generation != _controllerGeneration) return;

    final controller = VideoPlayerController.networkUrl(Uri.parse(url), httpHeaders: {'Referer': '${movieService.baseUrl}/'});

    try {
      await controller.initialize();
      await controller.setPlaybackSpeed(_playbackSpeed);
      await controller.setVolume(_volume);
      if (seekTo != null) {
        await controller.seekTo(seekTo);
      }
      await controller.play();

      if (!mounted || generation != _controllerGeneration) {
        await controller.dispose();
        return;
      }

      void videoValueListener() {
        if (!mounted || generation != _controllerGeneration || !identical(_videoController, controller)) {
          return;
        }
        final isPlaying = controller.value.isPlaying;
        if (isPlaying != _isPlaying) {
          setState(() => _isPlaying = isPlaying);
          if (isPlaying) _startControlsTimer();
        }
      }

      setState(() {
        _videoController = controller;
        _videoValueListener = videoValueListener;
        _isLoadingStream = false;
        _isPlaying = true;
      });
      controller.addListener(videoValueListener);
      _startControlsTimer();
      unawaited(_recordWatched());
    } catch (e) {
      await controller.dispose();
      if (!mounted || generation != _controllerGeneration) return;
      setState(() {
        _isLoadingStream = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.videoStreamError)));
    }
  }

  Future<void> _detachAndDisposeController() async {
    _controllerGeneration++;
    final controller = _videoController;
    final listener = _videoValueListener;
    if (controller == null) return;

    if (mounted) {
      setState(() {
        _videoController = null;
        _videoValueListener = null;
        _isPlaying = false;
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
    if (quality == _selectedQuality || _masterStreamUrl == null) return;
    final targetUrl = _qualityUrlFor(quality);
    if (targetUrl == null) return;
    final currentPos = _videoController?.value.position;
    setState(() {
      _selectedQuality = quality;
    });
    await _initVideoPlayer(targetUrl, seekTo: currentPos);
  }

  Future<void> _switchServer(MovieEpisodeServer server) async {
    setState(() {
      _selectedServer = server;
      if (server.episodes.isNotEmpty) {
        _selectedEpisode = server.episodes.first;
      }
    });
    if (_selectedEpisode != null) {
      await _playEpisode(_selectedEpisode!);
    }
  }

  Future<void> _playEpisode(MovieEpisode episode) async {
    setState(() {
      _selectedEpisode = episode;
      _isLoadingStream = true;
    });

    String? streamUrl = episode.m3u8Url;

    // If streamUrl is null, it might be a alternative server alternative server
    if (streamUrl == null && _selectedServer != null) {
      final match = RegExp(r'Server (\d+)').firstMatch(_selectedServer!.name);
      if (match != null) {
        final serverIndex = int.tryParse(match.group(1)!);
        if (serverIndex != null) {
          streamUrl = await movieService.getStreamUrl(
            widget.movieId,
            movieUrl: widget.movieUrl,
            server: serverIndex,
            cancelToken: _cancelToken,
          );
        }
      }
    }

    if (streamUrl != null && streamUrl.isNotEmpty) {
      await _useMasterStream(streamUrl);
    } else if (episode.embedUrl != null) {
      // WebView embed support could be added here
      setState(() => _isLoadingStream = false);
    } else {
      if (mounted) {
        setState(() => _isLoadingStream = false);
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.videoStreamError)));
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

  void _toggleMute() {
    _setVolume(_volume > 0 ? 0 : _lastAudibleVolume);
  }

  void _toggleVolumeControl() {
    _controlsTimer?.cancel();
    setState(() => _showVolumeControl = !_showVolumeControl);
    if (!_showVolumeControl) _startControlsTimer();
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
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
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

  void _updateDragPosition(VideoPlayerController controller, double localX, double width) {
    final fraction = (localX / width).clamp(0.0, 1.0);
    final target = controller.value.duration * fraction;
    setState(() {
      _dragFraction = fraction;
      _dragPosition = target;
      _hoverThumbnailCue = _thumbnailTrack?.cueAt(target);
    });
    unawaited(controller.seekTo(target));
  }

  void _updateHoverPreview(double localX, double width, {bool showPreview = true}) {
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
      _hoverThumbnailCue = _thumbnailTrack?.cueAt(target);
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

  void _showSettingsBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MovieSettingsSheet(
        selectedQuality: _selectedQuality,
        availableQualities: _availableQualities,
        playbackSpeed: _playbackSpeed,
        isRotationLocked: _isRotationLocked,
        supportsOrientationManager: _supportsOrientationManager,
        onQualityChanged: (q) {
          _switchQuality(q);
        },
        onSpeedChanged: (s) {
          setState(() => _playbackSpeed = s);
          _videoController?.setPlaybackSpeed(s);
        },
        onRotationLockToggled: () {
          _toggleRotationLock();
        },
      ),
    );
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
  Widget _buildOriginalTitleBar(String originalTitle) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      color: theme.appBarTheme.backgroundColor ?? theme.colorScheme.surface,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: Text(
        originalTitle,
        maxLines: subtitleMaxLines,
        overflow: TextOverflow.ellipsis,
        style:
            theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7)) ??
            const TextStyle(fontSize: 12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final title = _detail?.title ?? widget.initialMovie?.title ?? movieService.getLabel();
    final originalTitle = _detail?.originalTitle ?? widget.initialMovie?.originalTitle;
    final titleFit = appBarTitleFit(context, title);
    final hasOriginalTitle = originalTitle != null && originalTitle.isNotEmpty && originalTitle != title;

    return PopScope(
      // Embedded, the host owns the back button — it minimises, and asks this
      // screen to leave full screen through [controller].
      canPop: widget.embedded || !_isFullScreen,
      onPopInvokedWithResult: (didPop, result) {
        if (!widget.embedded && _isFullScreen) {
          _toggleFullScreen();
        }
      },
      child: _isFullScreen
          ? Scaffold(
              backgroundColor: Colors.black,
              body: SizedBox.expand(child: _buildVideoPlayerArea(isFullScreen: true)),
            )
          : widget.embedded
          ? _buildEmbedded(context, title: title, originalTitle: hasOriginalTitle ? originalTitle : null, titleFit: titleFit)
          : GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: Scaffold(
                appBar: DoAppBar(
                  title: title,
                  titleStyle: titleFit.titleStyle,
                  titleMaxLines: titleMaxLines,
                  height: titleFit.height,
                  actions: [
                    NeuIconButton(
                      size: appBarActionSize,
                      iconSize: 18,
                      depth: appBarActionDepth,
                      tooltip: _isFavorite ? l10n.removeFromFavorites : l10n.addToFavorites,
                      onPressed: _isUpdatingFavorite ? null : _toggleFavorite,
                      icon: _isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: _isFavorite ? Colors.pinkAccent : null,
                    ),
                  ],
                ),
                body: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (hasOriginalTitle) _buildOriginalTitleBar(originalTitle),
                          // Pinned above the scrollable body so playback stays in view.
                          _buildVideoPlayerArea(isFullScreen: false),
                          Expanded(child: _buildDetailBody()),
                        ],
                      ),
              ),
            ),
    );
  }

  Widget _buildDetailBody() {
    return MovieDetailBody(
      detail: _detail,
      selectedServer: _selectedServer,
      selectedEpisode: _selectedEpisode,
      onRefresh: _refreshDetail,
      onServerSelected: _switchServer,
      onEpisodeSelected: _playEpisode,
      onRelatedTap: (related) {
        if (widget.embedded) {
          widget.onRelatedMovieTap?.call(related);
        } else {
          context.replaceRoute(MovieDetailRoute(movieUrl: related.url, movieId: related.id, initialMovie: related));
        }
      },
    );
  }

  /// The page as it lives inside the `MovieScreen` overlay. [minimizeProgress]
  /// (1 = expanded, 0 = mini bar) drives every size here, so a drag reads as
  /// the player shrinking into the bottom bar while the rest fades away.
  Widget _buildEmbedded(BuildContext context, {required String title, required String? originalTitle, required AppBarTitleFit titleFit}) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final t = widget.minimizeProgress.clamp(0.0, 1.0);
    final mediaQuery = MediaQuery.of(context);
    final controller = _videoController;
    final aspectRatio = (controller?.value.isInitialized ?? false) ? controller!.value.aspectRatio : 16 / 9;
    final screenWidth = mediaQuery.size.width;
    final fullPlayerHeight = math.max(screenWidth / aspectRatio, minPlayerHeight);
    final playerWidth = miniPlayerWidth + (screenWidth - miniPlayerWidth) * t;
    // Fixed so the player can be clamped against the space the header leaves.
    final headerHeight = mediaQuery.padding.top + titleFit.height + (originalTitle != null ? embeddedSubtitleHeight : 0);

    final header = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: mediaQuery.padding.top),
        SizedBox(
          height: titleFit.height,
          child: Row(
            children: [
              IconButton(tooltip: l10n.minimize, icon: const Icon(Icons.keyboard_arrow_down_rounded), onPressed: widget.onMinimize),
              Expanded(
                child: Text(title, style: titleFit.titleStyle, maxLines: titleMaxLines, overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 8),
              NeuIconButton(
                size: appBarActionSize,
                iconSize: 18,
                depth: appBarActionDepth,
                tooltip: _isFavorite ? l10n.removeFromFavorites : l10n.addToFavorites,
                onPressed: _isUpdatingFavorite ? null : _toggleFavorite,
                icon: _isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: _isFavorite ? Colors.pinkAccent : null,
              ),
              IconButton(tooltip: l10n.close, icon: const Icon(Icons.close_rounded), onPressed: widget.onClose),
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
                style:
                    theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7)) ??
                    const TextStyle(fontSize: 12),
              ),
            ),
          ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // Landscape phones leave less room than the aspect ratio asks for.
        final playerHeight = math.min(
          miniPlayerHeight + (fullPlayerHeight - miniPlayerHeight) * t,
          math.max(miniPlayerHeight, constraints.maxHeight - headerHeight * t),
        );
        // The box is still card-sized while the opening zoom runs.
        final boxedPlayerWidth = math.min(playerWidth, constraints.maxWidth);
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
                      child: SizedBox(height: headerHeight, child: header),
                    ),
                  ),
                ),
              ),
              SizedBox(
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
                        child: _buildVideoPlayerArea(isFullScreen: false, fillParent: true, compact: t < 0.6),
                      ),
                    ),
                    if (t < 1)
                      Expanded(
                        child: Opacity(opacity: 1 - t, child: _buildMiniChrome(title, originalTitle)),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: ClipRect(
                  child: Opacity(
                    opacity: t,
                    child: IgnorePointer(
                      ignoring: t < 0.99,
                      child: _isLoading ? const Center(child: CircularProgressIndicator()) : _buildDetailBody(),
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
      child: Row(
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
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                if (originalTitle != null)
                  Text(
                    originalTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7)),
                  ),
              ],
            ),
          ),
          IconButton(icon: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded), onPressed: _togglePlayback),
          IconButton(tooltip: l10n.close, icon: const Icon(Icons.close_rounded), onPressed: widget.onClose),
        ],
      ),
    );
  }

  Widget _buildVideoPlayerArea({required bool isFullScreen, bool fillParent = false, bool compact = false}) {
    final controller = _videoController;
    final l10n = AppLocalizations.of(context);

    final aspectRatio = (controller != null && controller.value.isInitialized) ? controller.value.aspectRatio : 16 / 9;

    if (compact) {
      return Container(
        color: Colors.black,
        child: (controller != null && controller.value.isInitialized)
            ? Center(
                child: AspectRatio(aspectRatio: aspectRatio, child: VideoPlayer(controller)),
              )
            : const Center(
                child: SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.pinkAccent)),
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
        child: Container(
          color: Colors.black,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              if (controller != null && controller.value.isInitialized)
                Center(
                  child: AspectRatio(aspectRatio: controller.value.aspectRatio, child: VideoPlayer(controller)),
                )
              else if (_isLoadingStream)
                const Center(child: CircularProgressIndicator(color: Colors.pinkAccent))
              else
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.play_circle_outline_rounded, size: 56, color: Colors.white54),
                      const SizedBox(height: 12),
                      NeuButton(
                        onPressed: () {
                          final qualityUrl = _qualityUrlFor(_selectedQuality);
                          if (qualityUrl != null) {
                            _initVideoPlayer(qualityUrl);
                          } else {
                            _loadDetail();
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
                          // Bottom Gradient and Controls
                          Align(
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              padding: EdgeInsets.only(
                                bottom: 4 + (isFullScreen ? MediaQuery.paddingOf(context).bottom : 0),
                                left: isFullScreen ? MediaQuery.paddingOf(context).left : 0,
                                right: isFullScreen ? MediaQuery.paddingOf(context).right : 0,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
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
                                      final maxPreviewLeft = constraints.maxWidth > previewWidth
                                          ? constraints.maxWidth - previewWidth
                                          : 0.0;
                                      final previewLeft = (constraints.maxWidth * _dragFraction - previewWidth / 2).clamp(
                                        0.0,
                                        maxPreviewLeft,
                                      );

                                      return Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          MouseRegion(
                                            cursor: SystemMouseCursors.click,
                                            onEnter: (event) => _updateHoverPreview(event.localPosition.dx, constraints.maxWidth),
                                            onHover: (event) => _updateHoverPreview(event.localPosition.dx, constraints.maxWidth),
                                            onExit: (_) {
                                              if (_isTimelineHovering) {
                                                setState(() => _isTimelineHovering = false);
                                              }
                                              _startControlsTimer();
                                            },
                                            child: GestureDetector(
                                              behavior: HitTestBehavior.opaque,
                                              onHorizontalDragStart: (details) {
                                                _resumeAfterDrag = controller.value.isPlaying;
                                                unawaited(controller.pause());
                                                _controlsTimer?.cancel();
                                                setState(() => _isDragging = true);
                                                _updateDragPosition(controller, details.localPosition.dx, constraints.maxWidth);
                                              },
                                              onHorizontalDragUpdate: (details) {
                                                _updateDragPosition(controller, details.localPosition.dx, constraints.maxWidth);
                                              },
                                              onHorizontalDragEnd: (_) => _finishDragging(controller),
                                              onHorizontalDragCancel: () => _finishDragging(controller),
                                              onTapDown: (details) {
                                                _updateDragPosition(controller, details.localPosition.dx, constraints.maxWidth);
                                              },
                                              child: Padding(
                                                padding: const EdgeInsets.only(top: 14, bottom: 2),
                                                child: VideoProgressIndicator(
                                                  controller,
                                                  allowScrubbing: false,
                                                  colors: const VideoProgressColors(
                                                    playedColor: Colors.pinkAccent,
                                                    bufferedColor: Colors.white30,
                                                    backgroundColor: Colors.white12,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          if (_isDragging || _isTimelineHovering)
                                            Positioned(
                                              left: previewLeft,
                                              bottom: 42,
                                              child: PlayerScrubPreview(
                                                track: _thumbnailTrack,
                                                cue: _hoverThumbnailCue,
                                                width: previewWidth,
                                                referer: '${movieService.baseUrl}/',
                                                fallback: VideoPlayer(controller),
                                                position: _dragPosition,
                                              ),
                                            ),
                                        ],
                                      );
                                    },
                                  ),
                                  Row(
                                    children: [
                                      const SizedBox(width: 12),
                                      ValueListenableBuilder(
                                        valueListenable: controller,
                                        builder: (context, VideoPlayerValue value, child) {
                                          final currentPos = _isDragging ? _dragPosition : (_virtualSeekPosition ?? value.position);
                                          return Text(
                                            '${formatDuration(currentPos)} / ${formatDuration(value.duration)}',
                                            style: const TextStyle(color: Colors.white, fontSize: 11),
                                          );
                                        },
                                      ),
                                      const Spacer(),
                                      IconButton(
                                        tooltip: l10n.volume,
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints.tightFor(width: 40, height: 40),
                                        icon: Icon(_volumeIcon, color: _volume == 0 ? Colors.white70 : Colors.white),
                                        onPressed: _toggleVolumeControl,
                                      ),
                                      // Fullscreen button
                                      IconButton(
                                        icon: Icon(
                                          isFullScreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                                          color: Colors.white,
                                        ),
                                        onPressed: _toggleFullScreen,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Center Controls (Play/Pause)
                          if (!_isDragging)
                            Center(
                              child: PlayerCenterButton(
                                icon: _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                size: 64,
                                onPressed: _togglePlayback,
                              ),
                            ),

                          if (_showVolumeControl)
                            Positioned(
                              right: 12 + (isFullScreen ? MediaQuery.paddingOf(context).right : 0),
                              bottom: 58 + (isFullScreen ? MediaQuery.paddingOf(context).bottom : 0),
                              child: PlayerVolumePopup(
                                volume: _volume,
                                icon: _volumeIcon,
                                onToggleMute: _toggleMute,
                                onChanged: _setVolume,
                                onChangeStart: () => _controlsTimer?.cancel(),
                              ),
                            ),

                          // Top bar with back icon and settings
                          Positioned(
                            top: 12 + (isFullScreen ? MediaQuery.paddingOf(context).top : 0),
                            left: 12 + (isFullScreen ? MediaQuery.paddingOf(context).left : 0),
                            right: 12 + (isFullScreen ? MediaQuery.paddingOf(context).right : 0),
                            child: PlayerTopBar(showBack: isFullScreen, onBack: _toggleFullScreen, onSettings: _showSettingsBottomSheet),
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
    );

    if (isFullScreen) {
      return SizedBox.expand(child: playerWidget);
    }
    return playerWidget;
  }
}
