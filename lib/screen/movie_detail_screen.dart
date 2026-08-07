import 'dart:async';
import 'dart:math' as math;

import 'package:auto_route/auto_route.dart';
import 'package:dio/dio.dart';
import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/model/movie_model.dart';
import 'package:do_x/router/app_router.gr.dart';
import 'package:do_x/services/movie_library_service.dart';
import 'package:do_x/services/movie_service.dart';
import 'package:do_x/utils/logger.dart';
import 'package:do_x/widgets/app_bar/app_bar_base.dart';
import 'package:do_x/widgets/neu/neu_button.dart';
import 'package:do_x/widgets/neu/neu_card.dart';
import 'package:do_x/widgets/neu/neu_chip.dart';
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

  const MovieDetailScreen({super.key, required this.movieUrl, required this.movieId, this.initialMovie});

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

const _titleMaxLines = 3;
const _subtitleMaxLines = 2;

/// Keeps the inline player tall enough for the centre button and the progress
/// bar not to collide, however wide the video is.
const _minPlayerHeight = 220.0;

/// Sizes the inline player to [aspectRatio] but never below [minHeight];
/// when [fill] is set it simply takes all the space its parent offers.
class _PlayerBox extends StatelessWidget {
  const _PlayerBox({
    required this.aspectRatio,
    required this.minHeight,
    required this.fill,
    required this.child,
  });

  final double aspectRatio;
  final double minHeight;
  final bool fill;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (fill) return child;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite ? constraints.maxWidth : MediaQuery.sizeOf(context).width;
        return SizedBox(width: width, height: math.max(width / aspectRatio, minHeight), child: child);
      },
    );
  }
}

/// Result of shrinking a text to fit a line budget.
class _TextFit {
  const _TextFit({required this.fontSize, required this.height});
  final double fontSize;
  final double height;
}

/// Styles and toolbar height for the app bar title block.
class _AppBarTitleFit {
  const _AppBarTitleFit({required this.titleStyle, required this.subtitleStyle, required this.height});
  final TextStyle titleStyle;
  final TextStyle? subtitleStyle;
  final double height;
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
  _ThumbnailTrack? _thumbnailTrack;
  _ThumbnailCue? _hoverThumbnailCue;

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

  /// True when the language chip already reads as "Vietsub" / "Phụ đề".
  bool get _languageImpliesVietsub {
    final language = _detail?.language?.toLowerCase();
    if (language == null || language.isEmpty) return false;
    return language.contains('sub') || language.contains('phụ đề');
  }

  bool get _supportsOrientationManager =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void initState() {
    super.initState();
    logger.d('MovieDetailScreen: initState');
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
      final track = _ThumbnailTrack.parse(trackUrl, response.data ?? '');
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
      builder: (context) => _SettingsBottomSheet(
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

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return '$hours:${twoDigits(minutes)}:${twoDigits(seconds)}';
    } else {
      return '${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
  }

  Widget _buildThumbnailPreview(VideoPlayerController controller, double previewWidth) {
    final cue = _hoverThumbnailCue;
    final track = _thumbnailTrack;
    if (cue == null || track == null) return VideoPlayer(controller);

    final scale = previewWidth / cue.width;
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            left: -cue.x * scale,
            top: -cue.y * scale,
            width: track.spriteWidth * scale,
            height: track.spriteHeight * scale,
            child: Image.network(
              cue.imageUrl,
              headers: {'Referer': '${movieService.baseUrl}/'},
              fit: BoxFit.fill,
              gaplessPlayback: true,
              filterQuality: FilterQuality.low,
              errorBuilder: (_, _, _) => const ColoredBox(
                color: Colors.black,
                child: Center(child: Icon(Icons.image_not_supported, color: Colors.white38)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Shrinks [style] until [text] fits in [maxLines] within [maxWidth], and
  /// reports the height it occupies at that size.
  _TextFit _fitText({
    required BuildContext context,
    required String text,
    required TextStyle style,
    required double maxWidth,
    required int maxLines,
    required double minFontSize,
  }) {
    final textDirection = Directionality.of(context);
    final textScaler = MediaQuery.textScalerOf(context);
    double fontSize = style.fontSize ?? 14;

    while (true) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style.copyWith(fontSize: fontSize)),
        maxLines: maxLines,
        textDirection: textDirection,
        textScaler: textScaler,
      )..layout(maxWidth: maxWidth);
      final fits = !painter.didExceedMaxLines;
      final height = painter.height;
      painter.dispose();
      if (fits || fontSize <= minFontSize) {
        return _TextFit(fontSize: fontSize, height: height);
      }
      fontSize = math.max(minFontSize, fontSize - 0.5);
    }
  }

  _AppBarTitleFit _appBarTitleFit(BuildContext context, String title, String? originalTitle) {
    final theme = Theme.of(context);
    final titleStyle = theme.appBarTheme.titleTextStyle ?? theme.textTheme.titleLarge ?? const TextStyle(fontSize: 20);
    final subtitleStyle =
        theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7)) ??
        const TextStyle(fontSize: 12);

    final screenWidth = MediaQuery.sizeOf(context).width;
    final availableWidth = screenWidth > 272 ? screenWidth - 160 : 120.0;

    final titleFit = _fitText(
      context: context,
      text: title,
      style: titleStyle,
      maxWidth: availableWidth,
      maxLines: _titleMaxLines,
      minFontSize: 12,
    );

    _TextFit? subtitleFit;
    if (originalTitle != null && originalTitle.isNotEmpty && originalTitle != title) {
      subtitleFit = _fitText(
        context: context,
        text: originalTitle,
        style: subtitleStyle,
        maxWidth: availableWidth,
        maxLines: _subtitleMaxLines,
        minFontSize: 9,
      );
    }

    // 12 = 6px breathing room above/below the title block.
    final height = titleFit.height + (subtitleFit != null ? subtitleFit.height + 2 : 0) + 12;
    return _AppBarTitleFit(
      titleStyle: titleStyle.copyWith(fontSize: titleFit.fontSize),
      subtitleStyle: subtitleFit == null ? null : subtitleStyle.copyWith(fontSize: subtitleFit.fontSize),
      height: math.max(56.0, height),
    );
  }

  /// One labelled line of the info card, e.g. `Đạo diễn  •  A, B`.
  /// Renders nothing when [values] is empty.
  Widget _buildMetadataRow({required IconData icon, required String label, required List<String> values}) {
    if (values.isEmpty) return const SizedBox.shrink();
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          SizedBox(
            width: 78,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colorScheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Text(
              values.join(', '),
              style: const TextStyle(fontSize: 12.5, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServerMetadataChip({required IconData icon, required String label, Color? color}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color ?? colorScheme.onSurfaceVariant),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final title = _detail?.title ?? widget.initialMovie?.title ?? movieService.getLabel();
    final originalTitle = _detail?.originalTitle ?? widget.initialMovie?.originalTitle;
    final titleFit = _appBarTitleFit(context, title, originalTitle);

    return PopScope(
      canPop: !_isFullScreen,
      onPopInvokedWithResult: (didPop, result) {
        if (_isFullScreen) {
          _toggleFullScreen();
        }
      },
      child: _isFullScreen
          ? Scaffold(
              backgroundColor: Colors.black,
              body: SizedBox.expand(child: _buildVideoPlayerArea(isFullScreen: true)),
            )
          : GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: Scaffold(
                appBar: DoAppBar(
                  title: title,
                  titleStyle: titleFit.titleStyle,
                  subtitle: titleFit.subtitleStyle == null
                      ? null
                      : Text(
                          originalTitle!,
                          style: titleFit.subtitleStyle,
                          maxLines: _subtitleMaxLines,
                          overflow: TextOverflow.ellipsis,
                        ),
                  titleMaxLines: _titleMaxLines,
                  height: titleFit.height,
                  actions: [
                    NeuIconButton(
                      tooltip: _isFavorite ? l10n.removeFromFavorites : l10n.addToFavorites,
                      onPressed: _isUpdatingFavorite ? null : _toggleFavorite,
                      icon: _isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: _isFavorite ? Colors.pinkAccent : null,
                    ),
                  ],
                ),
                body: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : RefreshIndicator(
                        onRefresh: _refreshDetail,
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildVideoPlayerArea(isFullScreen: false),
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if ((_detail?.views?.isNotEmpty ?? false) ||
                                        (_detail?.likes?.isNotEmpty ?? false) ||
                                        (_detail?.hasVietsub ?? false)) ...[
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          if (_detail?.quality?.isNotEmpty ?? false)
                                            _buildServerMetadataChip(
                                              icon: Icons.high_quality_rounded,
                                              label: _detail!.quality!,
                                              color: Colors.amberAccent,
                                            ),
                                          if (_detail?.language?.isNotEmpty ?? false)
                                            _buildServerMetadataChip(
                                              icon: Icons.language_rounded,
                                              label: _detail!.language!,
                                              color: Colors.blueAccent,
                                            ),
                                          if (_detail?.time?.isNotEmpty ?? false)
                                            _buildServerMetadataChip(
                                              icon: Icons.timer_outlined,
                                              label: _detail!.time!,
                                            ),
                                          if (_detail?.views?.isNotEmpty ?? false)
                                            _buildServerMetadataChip(icon: Icons.visibility_rounded, label: _detail!.views!),
                                          if (_detail?.likes?.isNotEmpty ?? false)
                                            _buildServerMetadataChip(
                                              icon: Icons.favorite_rounded,
                                              label: _detail!.likes!,
                                              color: Colors.pinkAccent,
                                            ),
                                          // Skipped when `language` already says it (e.g. lang "Vietsub"),
                                          // otherwise the same tag shows twice.
                                          if ((_detail?.hasVietsub ?? false) && !_languageImpliesVietsub)
                                            _buildServerMetadataChip(
                                              icon: Icons.subtitles_rounded,
                                              label: l10n.vietsub,
                                              color: Colors.lightGreenAccent,
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                    ],
                                    // Server selector
                                    if (_detail!.servers.isNotEmpty) ...[
                                      NeuCard(
                                        margin: const EdgeInsets.symmetric(vertical: 4),
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(l10n.serverLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  // Clips at the viewport so chips never draw over the
                                                  // label; the padding keeps room for their shadows.
                                                  child: SingleChildScrollView(
                                                    scrollDirection: Axis.horizontal,
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                                    child: Row(
                                                      spacing: 8,
                                                      children: _detail!.servers.map((srv) {
                                                        final isSelected = _selectedServer?.name == srv.name;
                                                        return NeuChip(
                                                          label: srv.name,
                                                          isSelected: isSelected,
                                                          fontSize: 12,
                                                          onTap: () {
                                                            _switchServer(srv);
                                                          },
                                                        );
                                                      }).toList(),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            if (_selectedServer != null && _selectedServer!.episodes.length > 1) ...[
                                              const SizedBox(height: 12),
                                              Text(
                                                '${l10n.episodeLabel}:',
                                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                              ),
                                              const SizedBox(height: 8),
                                              SizedBox(
                                                width: double.infinity,
                                                child: Wrap(
                                                  spacing: 8,
                                                  runSpacing: 8,
                                                  children: _selectedServer!.episodes.map((ep) {
                                                    final isSelected = _selectedEpisode?.slug == ep.slug;
                                                    return NeuChip(
                                                      label: ep.name,
                                                      isSelected: isSelected,
                                                      fontSize: 11,
                                                      onTap: () {
                                                        _playEpisode(ep);
                                                      },
                                                    );
                                                  }).toList(),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                    ],

                                    // Description
                                    if (_detail?.description.isNotEmpty ?? false)
                                      NeuCard(
                                        margin: const EdgeInsets.symmetric(vertical: 8),
                                        padding: const EdgeInsets.all(12),
                                        child: Text(
                                          _detail!.description.replaceAll(RegExp(r'<[^>]*>'), '').trim(),
                                          style: const TextStyle(fontSize: 13, height: 1.4),
                                        ),
                                      ),

                                    // Tags and Metadata
                                    if ((_detail?.tags.isNotEmpty ?? false) ||
                                        (_detail?.countries.isNotEmpty ?? false) ||
                                        (_detail?.actors.isNotEmpty ?? false) ||
                                        (_detail?.directors.isNotEmpty ?? false)) ...[
                                      const SizedBox(height: 12),
                                      NeuCard(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            _buildMetadataRow(
                                              icon: Icons.movie_creation_rounded,
                                              label: l10n.directorLabel,
                                              values: _detail!.directors,
                                            ),
                                            _buildMetadataRow(
                                              icon: Icons.people_alt_rounded,
                                              label: l10n.actorsLabel,
                                              values: _detail!.actors,
                                            ),
                                            _buildMetadataRow(
                                              icon: Icons.public_rounded,
                                              label: l10n.countryLabel,
                                              values: _detail!.countries,
                                            ),
                                            _buildMetadataRow(
                                              icon: Icons.local_offer_rounded,
                                              label: l10n.genreLabel,
                                              values: _detail!.tags,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],

                                    // Related movies
                                    if (_detail?.relatedMovies.isNotEmpty ?? false) ...[
                                      const SizedBox(height: 20),
                                      Text(l10n.relatedMovies, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 12),
                                      SizedBox(
                                        height: 200,
                                        child: ListView.separated(
                                          scrollDirection: Axis.horizontal,
                                          clipBehavior: Clip.none,
                                          itemCount: _detail!.relatedMovies.length,
                                          separatorBuilder: (_, _) => const SizedBox(width: 12),
                                          itemBuilder: (context, index) {
                                            final rel = _detail!.relatedMovies[index];
                                            return SizedBox(
                                              width: 130,
                                              child: GestureDetector(
                                                onTap: () {
                                                  context.replaceRoute(
                                                    MovieDetailRoute(movieUrl: rel.url, movieId: rel.id, initialMovie: rel),
                                                  );
                                                },
                                                child: NeuCard(
                                                  margin: EdgeInsets.zero,
                                                  padding: EdgeInsets.zero,
                                                  clipBehavior: Clip.antiAlias,
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                                    children: [
                                                      Expanded(
                                                        child: Image.network(
                                                          rel.poster,
                                                          fit: BoxFit.cover,
                                                          errorBuilder: (_, _, _) => Container(color: Colors.grey),
                                                        ),
                                                      ),
                                                      Padding(
                                                        padding: const EdgeInsets.all(6.0),
                                                        child: Text(
                                                          rel.title,
                                                          maxLines: 2,
                                                          overflow: TextOverflow.ellipsis,
                                                          style: const TextStyle(fontSize: 11),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              // Add spacing at bottom to prevent shadow clipping and respect safe area
                              SizedBox(height: MediaQuery.paddingOf(context).bottom),
                            ],
                          ),
                        ),
                      ),
              ),
            ),
    );
  }

  Widget _buildVideoPlayerArea({required bool isFullScreen}) {
    final controller = _videoController;
    final l10n = AppLocalizations.of(context);

    final aspectRatio = (controller != null && controller.value.isInitialized) ? controller.value.aspectRatio : 16 / 9;

    Widget playerWidget = Focus(
      focusNode: _videoFocusNode,
      autofocus: true,
      onKeyEvent: _handleVideoKeyEvent,
      child: _PlayerBox(
        aspectRatio: aspectRatio,
        // Ultra-wide videos would otherwise be so short that the centre play
        // button covers the progress bar.
        minHeight: isFullScreen ? 0 : _minPlayerHeight,
        fill: isFullScreen,
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
                  child: IgnorePointer(
                    child: Stack(
                      children: [
                        if (_isSpeedBoosted)
                          Align(
                            alignment: Alignment.topCenter,
                            child: Container(
                              margin: const EdgeInsets.only(top: 16),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(16)),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.fast_forward_rounded, color: Colors.white, size: 16),
                                  const SizedBox(width: 4),
                                  const Text(
                                    '2x',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (_skipBackwardValue > 0)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(left: 32),
                              padding: const EdgeInsets.all(16),
                              decoration: const BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.fast_rewind_rounded, color: Colors.white, size: 32),
                                  Text(
                                    '-${_skipBackwardValue}s',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (_skipForwardValue > 0)
                          Align(
                            alignment: Alignment.centerRight,
                            child: Container(
                              margin: const EdgeInsets.only(right: 32),
                              padding: const EdgeInsets.all(16),
                              decoration: const BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.fast_forward_rounded, color: Colors.white, size: 32),
                                  Text(
                                    '+${_skipForwardValue}s',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
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
                                              child: IgnorePointer(
                                                child: Container(
                                                  width: previewWidth,
                                                  decoration: BoxDecoration(
                                                    color: Colors.black,
                                                    borderRadius: BorderRadius.circular(8),
                                                    border: Border.all(color: Colors.white70),
                                                    boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 8)],
                                                  ),
                                                  clipBehavior: Clip.antiAlias,
                                                  child: Column(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      AspectRatio(
                                                        aspectRatio: 16 / 9,
                                                        child: _buildThumbnailPreview(controller, previewWidth),
                                                      ),
                                                      Padding(
                                                        padding: const EdgeInsets.symmetric(vertical: 3),
                                                        child: Text(
                                                          _formatDuration(_dragPosition),
                                                          style: const TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 11,
                                                            fontWeight: FontWeight.w600,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
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
                                            '${_formatDuration(currentPos)} / ${_formatDuration(value.duration)}',
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
                              child: _buildCenterControlButton(
                                icon: _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                size: 64,
                                onPressed: _togglePlayback,
                              ),
                            ),

                          if (_showVolumeControl)
                            Positioned(
                              right: 12 + (isFullScreen ? MediaQuery.paddingOf(context).right : 0),
                              bottom: 58 + (isFullScreen ? MediaQuery.paddingOf(context).bottom : 0),
                              child: Material(
                                color: Colors.transparent,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black87,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.white24),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        tooltip: _volume == 0 ? l10n.unmute : l10n.mute,
                                        icon: Icon(_volumeIcon, color: Colors.white),
                                        onPressed: _toggleMute,
                                      ),
                                      SizedBox(
                                        width: 120,
                                        child: Slider(
                                          value: _volume,
                                          onChangeStart: (_) => _controlsTimer?.cancel(),
                                          onChanged: _setVolume,
                                          onChangeEnd: (_) {},
                                          activeColor: Colors.pinkAccent,
                                          inactiveColor: Colors.white30,
                                        ),
                                      ),
                                      SizedBox(
                                        width: 38,
                                        child: Text(
                                          '${(_volume * 100).round()}%',
                                          textAlign: TextAlign.right,
                                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                          // Top bar with back icon and settings
                          Positioned(
                            top: 12 + (isFullScreen ? MediaQuery.paddingOf(context).top : 0),
                            left: 12 + (isFullScreen ? MediaQuery.paddingOf(context).left : 0),
                            right: 12 + (isFullScreen ? MediaQuery.paddingOf(context).right : 0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                if (isFullScreen)
                                  Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: _toggleFullScreen,
                                      borderRadius: BorderRadius.circular(32),
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: const BoxDecoration(color: Colors.black26, shape: BoxShape.circle),
                                        child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 28),
                                      ),
                                    ),
                                  )
                                else
                                  const SizedBox.shrink(),
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: _showSettingsBottomSheet,
                                    borderRadius: BorderRadius.circular(32),
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: const BoxDecoration(color: Colors.black26, shape: BoxShape.circle),
                                      child: const Icon(Icons.settings_rounded, color: Colors.white, size: 24),
                                    ),
                                  ),
                                ),
                              ],
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
    );

    if (isFullScreen) {
      return SizedBox.expand(child: playerWidget);
    }
    return playerWidget;
  }

  Widget _buildCenterControlButton({required IconData icon, required VoidCallback onPressed, double size = 48}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(size),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.black38,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white24, width: 1.5),
          ),
          child: Icon(icon, color: Colors.white, size: size * 0.6),
        ),
      ),
    );
  }
}

class _ThumbnailCue {
  const _ThumbnailCue({
    required this.start,
    required this.end,
    required this.imageUrl,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final Duration start;
  final Duration end;
  final String imageUrl;
  final double x;
  final double y;
  final double width;
  final double height;
}

class _ThumbnailTrack {
  const _ThumbnailTrack({required this.cues, required this.spriteUrl, required this.spriteWidth, required this.spriteHeight});

  final List<_ThumbnailCue> cues;
  final String spriteUrl;
  final double spriteWidth;
  final double spriteHeight;

  _ThumbnailCue? cueAt(Duration position) {
    for (final cue in cues) {
      if (position >= cue.start && position < cue.end) return cue;
    }
    if (cues.isNotEmpty && position >= cues.last.end) return cues.last;
    return null;
  }

  static _ThumbnailTrack? parse(String trackUrl, String source) {
    final cuePattern = RegExp(
      r'^(\d{2}:\d{2}:\d{2}\.\d{3})\s+-->\s+'
      r'(\d{2}:\d{2}:\d{2}\.\d{3})\s*\r?\n'
      r'([^\r\n#]+)#xywh=(\d+),(\d+),(\d+),(\d+)',
      multiLine: true,
    );
    final cues = <_ThumbnailCue>[];
    var spriteWidth = 0.0;
    var spriteHeight = 0.0;

    for (final match in cuePattern.allMatches(source)) {
      final x = double.parse(match.group(4)!);
      final y = double.parse(match.group(5)!);
      final width = double.parse(match.group(6)!);
      final height = double.parse(match.group(7)!);
      final imageUrl = Uri.parse(trackUrl).resolve(match.group(3)!.trim()).toString();
      cues.add(
        _ThumbnailCue(
          start: _parseTimestamp(match.group(1)!),
          end: _parseTimestamp(match.group(2)!),
          imageUrl: imageUrl,
          x: x,
          y: y,
          width: width,
          height: height,
        ),
      );
      spriteWidth = spriteWidth < x + width ? x + width : spriteWidth;
      spriteHeight = spriteHeight < y + height ? y + height : spriteHeight;
    }

    if (cues.isEmpty) return null;
    return _ThumbnailTrack(cues: cues, spriteUrl: cues.first.imageUrl, spriteWidth: spriteWidth, spriteHeight: spriteHeight);
  }

  static Duration _parseTimestamp(String timestamp) {
    final parts = timestamp.split(RegExp(r'[:.]'));
    return Duration(
      hours: int.parse(parts[0]),
      minutes: int.parse(parts[1]),
      seconds: int.parse(parts[2]),
      milliseconds: int.parse(parts[3]),
    );
  }
}

class _SettingsBottomSheet extends StatelessWidget {
  const _SettingsBottomSheet({
    required this.selectedQuality,
    required this.availableQualities,
    required this.playbackSpeed,
    required this.isRotationLocked,
    required this.supportsOrientationManager,
    required this.onQualityChanged,
    required this.onSpeedChanged,
    required this.onRotationLockToggled,
  });

  final String selectedQuality;
  final List<MovieStreamVariant> availableQualities;
  final double playbackSpeed;
  final bool isRotationLocked;
  final bool supportsOrientationManager;
  final ValueChanged<String> onQualityChanged;
  final ValueChanged<double> onSpeedChanged;
  final VoidCallback onRotationLockToggled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.high_quality_rounded),
              title: Text(l10n.resolutionQuality),
              subtitle: Text(selectedQuality),
              onTap: () {
                Navigator.pop(context);
                _showSelectionSheet<String>(
                  context,
                  l10n.resolutionQuality,
                  ['Auto', ...availableQualities.map((e) => e.label)],
                  selectedQuality,
                  onQualityChanged,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.speed_rounded),
              title: Text(l10n.playbackSpeed),
              subtitle: Text('${playbackSpeed}x'),
              onTap: () {
                Navigator.pop(context);
                _showSelectionSheet<double>(
                  context,
                  l10n.playbackSpeed,
                  const [0.5, 0.75, 1.0, 1.25, 1.5, 2.0],
                  playbackSpeed,
                  onSpeedChanged,
                  labelBuilder: (v) => v == 1.0 ? '1x' : '${v}x',
                );
              },
            ),
            if (supportsOrientationManager)
              ListTile(
                leading: Icon(isRotationLocked ? Icons.screen_lock_rotation_rounded : Icons.screen_rotation_rounded),
                title: Text(l10n.lockRotation),
                subtitle: Text(isRotationLocked ? l10n.lockRotation : l10n.unlockRotation),
                trailing: Switch(
                  value: isRotationLocked,
                  onChanged: (_) {
                    onRotationLockToggled();
                    Navigator.pop(context);
                  },
                ),
                onTap: () {
                  onRotationLockToggled();
                  Navigator.pop(context);
                },
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showSelectionSheet<T>(
    BuildContext context,
    String title,
    List<T> options,
    T selectedValue,
    ValueChanged<T> onSelected, {
    String Function(T)? labelBuilder,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const Divider(),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: options.length,
                  itemBuilder: (context, index) {
                    final option = options[index];
                    final isSelected = option == selectedValue;
                    return ListTile(
                      title: Text(
                        labelBuilder?.call(option) ?? option.toString(),
                        style: TextStyle(color: isSelected ? Colors.pinkAccent : null, fontWeight: isSelected ? FontWeight.bold : null),
                      ),
                      trailing: isSelected ? const Icon(Icons.check, color: Colors.pinkAccent) : null,
                      onTap: () {
                        onSelected(option);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
