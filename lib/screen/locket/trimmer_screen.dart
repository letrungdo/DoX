import 'dart:io';
import 'dart:typed_data';

import 'package:auto_route/auto_route.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/widgets/app_bar/app_bar_base.dart';
import 'package:easy_video_editor/easy_video_editor.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:video_editor/video_editor.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

@RoutePage()
class TrimmerScreen extends StatefulWidget {
  final File file;

  const TrimmerScreen(this.file, {super.key});
  @override
  State<TrimmerScreen> createState() => _TrimmerScreenState();
}

class _TrimmerScreenState extends State<TrimmerScreen> {
  final _exportingProgress = ValueNotifier<double>(0.0);
  final _isExporting = ValueNotifier<bool>(false);
  final double height = 60;

  // Locket's storage rules reject videos >= 6 MiB with a 403 on the finalize
  // upload. Keep a small margin under the hard limit.
  static const int _maxVideoBytes = 6 * 1024 * 1024;

  late VideoEditorController _controller = _createController(widget.file);

  VideoEditorController _createController(File file) => VideoEditorController.file(
    file,
    minDuration: const Duration(milliseconds: 500),
    maxDuration: const Duration(seconds: 10),
    trimThumbnailsQuality: 20,
    coverThumbnailsQuality: 20,
  );

  @override
  void initState() {
    super.initState();
    _initController();
  }

  Future<void> _initController({bool allowNormalize = true}) async {
    try {
      await _controller.initialize(aspectRatio: 1);
      if (!mounted) return;
      setState(() {});
    } catch (error, stack) {
      debugPrint('TrimmerScreen initialize failed: $error\n$stack');
      // Some iPhone-edited/cropped videos can't be read by AVPlayer (err=-12860).
      // Re-encoding via AVAssetExportSession usually produces a playable file.
      // VideoMinDurationError means the video is genuinely too short -> can't fix by re-encoding.
      if (allowNormalize && error is! VideoMinDurationError) {
        final normalized = await _normalizeVideo(widget.file);
        if (!mounted) return;
        if (normalized != null) {
          await _controller.dispose();
          _controller = _createController(File(normalized));
          return _initController(allowNormalize: false);
        }
      }
      if (!mounted) return;
      _showErrorSnackBar("Can't open this video :(");
      context.pop();
    }
  }

  Future<String?> _normalizeVideo(File file) async {
    try {
      return await VideoEditorBuilder(videoPath: file.path).compress(resolution: VideoResolution.p720).export();
    } catch (e) {
      debugPrint('TrimmerScreen normalize failed: $e');
      return null;
    }
  }

  @override
  void dispose() async {
    _controller.dispose();
    _isExporting.dispose();

    super.dispose();
  }

  void _showErrorSnackBar(String message) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 1)));

  Future<void> _exportVideo() async {
    _exportingProgress.value = 0;
    _isExporting.value = true;
    final [videoPath, thumbnailData] = await Future.wait([_trimVideo(), _getThumbnail()]);
    _isExporting.value = false;
    if (videoPath == null || thumbnailData == null) {
      return;
    }

    var path = videoPath as String;
    // Video still over Locket's 6 MiB limit after the default p720 compress ->
    // ask the user to downscale to 480p or go back and shorten the clip.
    if (await File(path).length() > _maxVideoBytes) {
      final reduced = await _handleOversizeVideo(path);
      if (reduced == null) return; // user chose to shorten, or re-export failed
      path = reduced;
    }

    if (!mounted) return;
    context.pop([path, thumbnailData]);
  }

  /// Returns a path to a video that fits under [_maxVideoBytes], or null if the
  /// user opted to adjust the trim duration (stay on screen) or it still fails.
  Future<String?> _handleOversizeVideo(String oversizePath) async {
    final sizeMb = await File(oversizePath).length() / 1024 / 1024;
    if (!mounted) return null;
    final l10n = context.l10n;
    final downscale = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.videoTooLargeTitle),
        content: Text(l10n.videoTooLargeMessage(sizeMb.toStringAsFixed(1))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.shortenVideo)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.reduceTo480p)),
        ],
      ),
    );
    if (downscale != true) return null; // user will adjust the trim slider

    _exportingProgress.value = 0;
    _isExporting.value = true;
    final reduced = await _trimVideo(resolution: VideoResolution.p480);
    _isExporting.value = false;
    if (reduced == null) return null;

    if (await File(reduced).length() > _maxVideoBytes) {
      if (!mounted) return null;
      _showErrorSnackBar(context.l10n.videoStillTooLargeAt480p);
      return null;
    }
    return reduced;
  }

  Future<String?> _trimVideo({VideoResolution resolution = VideoResolution.p720}) async {
    try {
      final editor = VideoEditorBuilder(videoPath: _controller.file.path).trim(
        startTimeMs: _controller.startTrim.inMilliseconds, //
        endTimeMs: _controller.endTrim.inMilliseconds,
      );
      // Center-crop to a 1:1 square to match Locket's square format.
      editor.crop(aspectRatio: VideoAspectRatio.ratio1x1);
      // Compress on all platforms: iOS-trimmed videos at full resolution can be
      // large enough to exceed Locket's storage-rule size limit, which surfaces
      // as a 403 "Permission denied" on the finalize PUT.
      editor.compress(resolution: resolution);
      return editor.export(
        onProgress: (progress) {
          _exportingProgress.value = progress;
        },
      );
    } catch (e) {
      _showErrorSnackBar("Error on export video :(");
    }
    return null;
  }

  Future<Uint8List?> _getThumbnail() async {
    try {
      final data = await VideoThumbnail.thumbnailData(
        video: _controller.file.path,
        imageFormat: ImageFormat.JPEG,
        timeMs: _controller.selectedCoverVal?.timeMs ?? _controller.startTrim.inMilliseconds,
        quality: 100,
      );
      if (data == null) return null;
      final image = img.decodeImage(data);
      if (image == null) return data; // can't crop, fall back to original thumbnail

      // No crop selected -> return the thumbnail as-is.
      if (_controller.minCrop <= minOffset && _controller.maxCrop >= maxOffset) {
        return data;
      }

      // crop fractions (0..1) applied to the ACTUAL decoded image size, clamped to bounds.
      final x = (image.width * _controller.minCrop.dx).round().clamp(0, image.width - 1);
      final y = (image.height * _controller.minCrop.dy).round().clamp(0, image.height - 1);
      final w = (image.width * (_controller.maxCrop.dx - _controller.minCrop.dx)).round().clamp(1, image.width - x);
      final h = (image.height * (_controller.maxCrop.dy - _controller.minCrop.dy)).round().clamp(1, image.height - y);

      final cropped = img.copyCrop(image, x: x, y: y, width: w, height: h);
      return Uint8List.fromList(img.encodeJpg(cropped));
    } catch (e) {
      debugPrint('TrimmerScreen getThumbnail failed: $e');
      _showErrorSnackBar("Error on cover exportation :(");
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          context.pop();
        }
      },
      child: Scaffold(
        appBar: DoAppBar(
          actions: [
            IconButton(
              onPressed: () => _controller.rotate90Degrees(RotateDirection.left),
              icon: const Icon(Icons.rotate_left),
              tooltip: 'Rotate unclockwise',
            ),
            IconButton(
              onPressed: () => _controller.rotate90Degrees(RotateDirection.right),
              icon: const Icon(Icons.rotate_right),
              tooltip: 'Rotate clockwise',
            ),
            const SizedBox(width: 22),
            ValueListenableBuilder(
              valueListenable: _isExporting,
              builder: (context, value, _) {
                return IconButton(onPressed: value ? null : _exportVideo, icon: const Icon(Icons.save));
              },
            ),
          ],
        ),
        body: SafeArea(child: _buildBody()),
      ),
    );
  }

  Widget _buildBody() {
    return _controller.initialized
        ? DefaultTabController(
          length: 2,
          child: Column(
            children: [
              Expanded(
                child: TabBarView(
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        CropGridViewer.preview(controller: _controller),
                        AnimatedBuilder(
                          animation: _controller.video,
                          builder:
                              (_, _) => AnimatedOpacity(
                                opacity: _controller.isPlaying ? 0 : 1,
                                duration: kThemeAnimationDuration,
                                child: GestureDetector(
                                  onTap: _controller.video.play,
                                  child: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                    child: const Icon(Icons.play_arrow, color: Colors.black),
                                  ),
                                ),
                              ),
                        ),
                      ],
                    ),
                    CoverViewer(controller: _controller),
                  ],
                ),
              ),
              Container(
                height: 200,
                margin: const EdgeInsets.only(top: 10),
                child: Column(
                  children: [
                    TabBar(
                      tabs: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [Padding(padding: EdgeInsets.all(5), child: Icon(Icons.content_cut)), Text('Trim')],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [Padding(padding: EdgeInsets.all(5), child: Icon(Icons.video_label)), Text('Cover')],
                        ),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        physics: const NeverScrollableScrollPhysics(),
                        children: [Column(mainAxisAlignment: MainAxisAlignment.center, children: _trimSlider()), _coverSelection()],
                      ),
                    ),
                  ],
                ),
              ),
              ValueListenableBuilder(
                valueListenable: _isExporting,
                builder: (_, bool export, Widget? child) => AnimatedSize(duration: kThemeAnimationDuration, child: export ? child : null),
                child: AlertDialog(
                  title: ValueListenableBuilder(
                    valueListenable: _exportingProgress,
                    builder:
                        (_, double value, _) => Text("Exporting video ${(value * 100).ceil()}%", style: const TextStyle(fontSize: 12)),
                  ),
                ),
              ),
            ],
          ),
        )
        : const Center(child: CircularProgressIndicator());
  }

  String formatter(Duration duration) => [
    duration.inMinutes.remainder(60).toString().padLeft(2, '0'), //
    duration.inSeconds.remainder(60).toString().padLeft(2, '0'),
  ].join(":");

  List<Widget> _trimSlider() {
    return [
      AnimatedBuilder(
        animation: Listenable.merge([_controller, _controller.video]),
        builder: (_, _) {
          final int duration = _controller.videoDuration.inSeconds;
          final double pos = _controller.trimPosition * duration;

          return Padding(
            padding: EdgeInsets.symmetric(horizontal: height / 4),
            child: Row(
              children: [
                Text(formatter(Duration(seconds: pos.toInt()))),
                const Expanded(child: SizedBox()),
                AnimatedOpacity(
                  opacity: _controller.isTrimming ? 1 : 0,
                  duration: kThemeAnimationDuration,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(formatter(_controller.startTrim)), //
                      const SizedBox(width: 10), Text(formatter(_controller.endTrim)),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
      Container(
        width: MediaQuery.of(context).size.width,
        margin: EdgeInsets.symmetric(vertical: height / 4),
        child: TrimSlider(
          controller: _controller,
          height: height,
          horizontalMargin: height / 4,
          child: TrimTimeline(controller: _controller, padding: const EdgeInsets.only(top: 10)),
        ),
      ),
    ];
  }

  Widget _coverSelection() {
    return SingleChildScrollView(
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(15),
          child: CoverSelection(
            controller: _controller,
            size: height + 10,
            quantity: 8,
            selectedCoverBuilder: (cover, size) {
              return Stack(
                alignment: Alignment.center,
                children: [cover, Icon(Icons.check_circle, color: const CoverSelectionStyle().selectedBorderColor)],
              );
            },
          ),
        ),
      ),
    );
  }
}
