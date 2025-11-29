import 'dart:io';
import 'dart:typed_data';

import 'package:auto_route/auto_route.dart';
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

  late final VideoEditorController _controller = VideoEditorController.file(
    widget.file,
    minDuration: const Duration(milliseconds: 500),
    maxDuration: const Duration(seconds: 10),
    trimThumbnailsQuality: 20,
    coverThumbnailsQuality: 20,
  );

  @override
  void initState() {
    super.initState();
    _controller.initialize(aspectRatio: 1).then((_) => setState(() {})).catchError((error) {
      // handle minumum duration bigger than video duration error
      if (!mounted) return;
      context.pop();
    });
  }

  @override
  void dispose() async {
    _controller.dispose();
    _isExporting.dispose();

    super.dispose();
  }

  void _showErrorSnackBar(String message) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 1)));

  Rect get cropRect {
    if (_controller.minCrop <= minOffset && _controller.maxCrop >= maxOffset) {
      return Rect.zero;
    }
    final enddx = _controller.videoWidth * _controller.maxCrop.dx;
    final enddy = _controller.videoHeight * _controller.maxCrop.dy;
    final startdx = _controller.videoWidth * _controller.minCrop.dx;
    final startdy = _controller.videoHeight * _controller.minCrop.dy;

    return Rect.fromLTWH(startdx, startdy, enddx - startdx, enddy - startdy);
  }

  Future<void> _exportVideo() async {
    _exportingProgress.value = 0;
    _isExporting.value = true;
    final [videoPath, thumbnailData] = await Future.wait([_trimVideo(), _getThumbnail()]);
    _isExporting.value = false;
    if (videoPath == null || thumbnailData == null) {
      return;
    }
    if (!mounted) return;
    context.pop([videoPath, thumbnailData]);
  }

  Future<String?> _trimVideo() async {
    try {
      final editor = VideoEditorBuilder(videoPath: _controller.file.path).trim(
        startTimeMs: _controller.startTrim.inMilliseconds, //
        endTimeMs: _controller.endTrim.inMilliseconds,
      );
      // .crop(aspectRatio: VideoAspectRatio.ratio1x1);
      if (Platform.isAndroid) {
        editor.compress(resolution: VideoResolution.p720);
      }
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
      final image = img.decodeJpg(data!);
      img.Image cropped = img.copyCrop(
        image!,
        x: cropRect.left.toInt(),
        y: cropRect.top.toInt(),
        width: cropRect.width.toInt(),
        height: cropRect.height.toInt(),
      );
      return Uint8List.fromList(img.encodeJpg(cropped));
    } catch (e) {
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
