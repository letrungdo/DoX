import 'dart:async';
import 'dart:io';

import 'package:auto_route/auto_route.dart';
import 'package:do_x/services/export_service.dart';
import 'package:do_x/utils/logger.dart';
import 'package:do_x/widgets/app_bar/app_bar_base.dart';
import 'package:flutter/material.dart';
import 'package:video_editor/video_editor.dart';

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
    trimThumbnailsQuality: 50,
    coverThumbnailsQuality: 50,
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
    _exportingProgress.dispose();
    _isExporting.dispose();
    _controller.dispose();
    ExportService.dispose();
    super.dispose();
  }

  void _showErrorSnackBar(String message) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 1)));

  void _exportVideo() async {
    _exportingProgress.value = 0;
    _isExporting.value = true;

    final config = VideoFFmpegVideoEditorConfig(
      _controller,
      isFiltersEnabled: false, // TODO:
      // commandBuilder: (config, videoPath, outputPath) {
      //   String filtersCmd(List<String> filters) {
      //     filters.removeWhere((item) => item.isEmpty);
      //     return filters.isNotEmpty ? "-vf '${filters.join(",")}'" : "";
      //   }

      //   final filters = config.getExportFilters();
      //   final startTrimCmd = "-ss ${_controller.startTrim}";
      //   final toTrimCmd = "-t ${_controller.trimmedDuration}";

      //   final cmd = "$startTrimCmd -i '$videoPath' $toTrimCmd ${filtersCmd(filters)} ${filters.isEmpty ? '-c copy' : ''} -y '$outputPath'";

      //   // -c:v libx264 → use the widely-supported H.264 encoder
      //   // -crf 18   → quality level (lower = better; 18–23 is a good sweet-spot)
      //   // -preset veryfast → controls speed vs. compression (try medium or slow for even smaller files)
      //   // -pix_fmt yuv420p → ensures broad compatibility (iOS players, web)
      //   // -movflags +faststart → moves metadata to the front so videos start immediately when streaming
      //   return cmd;
      // },
    );
    final coverConfig = CoverFFmpegVideoEditorConfig(_controller);

    FFmpegVideoEditorExecute? cover;

    try {
      cover = await coverConfig.getExecuteConfig();
    } catch (e) {
      logger.e(e.toString(), error: e);
    }
    if (cover == null) {
      _showErrorSnackBar("Please select cover!");
      return;
    }

    final [videoPath, coverPath] = await Future.wait([
      ExportService.runFFmpegCommand(
        await config.getExecuteConfig(),
        onProgress: (stats) {
          _exportingProgress.value = config.getFFmpegProgress(stats.getTime().toInt());
        },
        onError: (e, s) => _showErrorSnackBar("Error on export video :("),
        onCompleted: (file) {
          _isExporting.value = false;
        },
      ),
      ExportService.runFFmpegCommand(
        cover,
        onError: (e, s) => _showErrorSnackBar("Error on cover exportation :("),
        onCompleted: (cover) {
          if (!mounted) return;
        },
      ),
    ]);

    if (!mounted) return;
    context.pop([videoPath, coverPath]);
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
        backgroundColor: Colors.black,
        appBar: DoAppBar(
          backgroundColor: Colors.black,
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
            IconButton(onPressed: _exportVideo, icon: const Icon(Icons.save)),
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
                              (_, __) => AnimatedOpacity(
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
                        (_, double value, __) => Text("Exporting video ${(value * 100).ceil()}%", style: const TextStyle(fontSize: 12)),
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
        builder: (_, __) {
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
