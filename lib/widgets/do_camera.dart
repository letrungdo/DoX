import 'dart:async';
import 'dart:io';

import 'package:auto_route/auto_route.dart';
import 'package:camera/camera.dart';
import 'package:collection/collection.dart';
import 'package:do_x/utils/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:visibility_detector/visibility_detector.dart';

class DoCamera extends StatefulWidget {
  const DoCamera({super.key, this.imgData, required this.parentSize});
  final Uint8List? imgData;
  final double parentSize;

  @override
  State<DoCamera> createState() => DoCameraState();
}

class DoCameraState extends State<DoCamera> with WidgetsBindingObserver {
  List<CameraDescription>? _cameras;
  CameraController? controller;
  double _minAvailableZoom = 1.0;
  double _maxAvailableZoom = 1.0;
  double _currentScale = 1.0;
  double _baseScale = 1.0;
  FlashMode _flashMode = FlashMode.off;
  FlashMode get flashMode => _flashMode;

  // Counting pointers (number of user fingers on screen)
  int _pointers = 0;

  CameraDescription? _camera;

  bool _isRunning = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera().then((_) {
      _camera =
          _cameras?.firstWhereOrNull(
            (c) => c.lensDirection == CameraLensDirection.front, //
          ) ??
          _cameras?.firstOrNull;
      _initializeCameraController(_camera);
    });
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
    } catch (e) {
      logger.e(e.toString(), error: e);
    }
  }

  @override
  void didUpdateWidget(covariant DoCamera oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.imgData != oldWidget.imgData) {
      if (widget.imgData == null) {
        _initializeCameraController(_camera);
      } else {
        _stopCamera();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final tabsRouter = AutoTabsRouter.of(context);
    if (tabsRouter.currentPath != "/locket") {
      return;
    }
    // App state changed before we got the chance to initialize.
    if (controller == null || !controller!.value.isInitialized) {
      return;
    }

    switch (state) {
      case AppLifecycleState.inactive:
        _stopCamera();
        break;
      case AppLifecycleState.resumed:
        _initializeCameraController(_camera);
        break;
      default:
        break;
    }
  }

  Future<CameraImage> _startImageStream() async {
    if (controller!.value.isStreamingImages) {
      await controller!.stopImageStream();
    }
    final completer = Completer<CameraImage>();
    controller!.startImageStream((image) {
      controller!.stopImageStream();
      completer.complete(image);
    });
    return completer.future;
  }

  Future<void> _initializeCameraController(CameraDescription? cameraDescription) async {
    if (cameraDescription == null) return;
    if (_isRunning || !mounted) {
      return;
    }
    _isRunning = true;
    controller = CameraController(
      cameraDescription,
      ResolutionPreset.veryHigh, //
      enableAudio: false,
      imageFormatGroup: Platform.isIOS ? ImageFormatGroup.bgra8888 : ImageFormatGroup.yuv420,
    );
    try {
      await controller!.initialize();
      if (mounted) {
        setState(() {});
      }
      if (!kIsWeb) {
        await controller!.lockCaptureOrientation();
        controller!.setFlashMode(flashMode);
        await Future.wait(<Future<Object?>>[
          controller!.getMaxZoomLevel().then((double value) => _maxAvailableZoom = value),
          controller!.getMinZoomLevel().then((double value) => _minAvailableZoom = value),
        ]);
      }
    } on CameraException catch (e) {
      switch (e.code) {
        case 'CameraAccessDenied':
          showInSnackBar('You have denied camera access.');
        case 'CameraAccessDeniedWithoutPrompt':
          // iOS only
          showInSnackBar('Please go to Settings app to enable camera access.');
        case 'CameraAccessRestricted':
          // iOS only
          showInSnackBar('Camera access is restricted.');
        case 'AudioAccessDenied':
          showInSnackBar('You have denied audio access.');
        case 'AudioAccessDeniedWithoutPrompt':
          // iOS only
          showInSnackBar('Please go to Settings app to enable audio access.');
        case 'AudioAccessRestricted':
          // iOS only
          showInSnackBar('Audio access is restricted.');
        default:
          _showCameraException(e);
      }
    } catch (e) {
      logger.e(e.toString(), error: e);
    }
  }

  void _showCameraException(CameraException e) {
    _logError(e.code, e.description);
    showInSnackBar('Error: ${e.code}\n${e.description}');
  }

  void _logError(String code, String? message) {
    // ignore: avoid_print
    print('Error: $code${message == null ? '' : '\nError Message: $message'}');
  }

  void showInSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopCamera();
    super.dispose();
  }

  void _stopCamera() async {
    _isRunning = false;
    await controller?.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return VisibilityDetector(
      key: Key('do_camera_widget'),
      onVisibilityChanged: (info) {
        if (widget.imgData != null) return;
        final visibleFraction = info.visibleFraction;
        if (visibleFraction > 0 && visibleFraction < 1) return;
        final isVisible = visibleFraction == 1;
        if (isVisible) {
          _initializeCameraController(_camera);
        } else {
          _stopCamera();
        }
      },
      child: AnimatedSwitcher(
        duration: Durations.medium2,
        child: SizedBox(
          width: size.width,
          height: size.width,
          child:
              widget.imgData == null
                  ? FittedBox(
                    fit: size.width > widget.parentSize ? BoxFit.fitHeight : BoxFit.fitWidth,
                    child: SizedBox(
                      width: size.width, //
                      child: _buildCameraPreview(),
                    ),
                  )
                  : Image.memory(widget.imgData!, fit: BoxFit.fitWidth),
        ),
      ),
    );
  }

  Widget _buildCameraPreview() {
    debugPrint("controller __ ${controller?.value.isInitialized}");

    return controller?.value.isInitialized == true
        ? Listener(
          onPointerDown: (_) => _pointers++,
          onPointerUp: (_) => _pointers--,
          child: CameraPreview(
            controller!,
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onScaleStart: _handleScaleStart,
                  onScaleUpdate: _handleScaleUpdate,
                  onTapDown: (TapDownDetails details) => onViewFinderTap(details, constraints),
                );
              },
            ),
          ),
        )
        : SizedBox.shrink();
  }

  void _handleScaleStart(ScaleStartDetails details) {
    _baseScale = _currentScale;
  }

  Future<void> _handleScaleUpdate(ScaleUpdateDetails details) async {
    // When there are not exactly two fingers on screen don't scale
    if (_pointers != 2) {
      return;
    }

    _currentScale = (_baseScale * details.scale).clamp(_minAvailableZoom, _maxAvailableZoom);

    await controller?.setZoomLevel(_currentScale);
  }

  void onViewFinderTap(TapDownDetails details, BoxConstraints constraints) {
    final offset = Offset(details.localPosition.dx / constraints.maxWidth, details.localPosition.dy / constraints.maxHeight);
    controller?.setExposurePoint(offset);
    controller?.setFocusPoint(offset);
  }

  /// https://stackoverflow.com/questions/57603146/how-to-convert-camera-image-to-image?rq=3
  img.Image? _convertImage(CameraImage? cameraImage) {
    if (cameraImage == null) return null;
    final plane = cameraImage.planes[0];

    return img.Image.fromBytes(
      width: cameraImage.width,
      height: cameraImage.height,
      bytes: plane.bytes.buffer,
      rowStride: plane.bytesPerRow,
      bytesOffset: 28,
      order: img.ChannelOrder.bgra,
    );
  }

  Future<Uint8List?> takePicture() async {
    if (controller == null) return null;

    if (!controller!.value.isInitialized) {
      showInSnackBar('Error: select a camera first.');
      return null;
    }

    try {
      img.Image? image;
      if (flashMode == FlashMode.always || kIsWeb || Platform.isAndroid) {
        final xFile = await controller!.takePicture();
        final bytes = await xFile.readAsBytes();
        image = img.decodeJpg(bytes);
        if (_camera?.lensDirection == CameraLensDirection.front && Platform.isIOS) {
          image = img.flipHorizontal(image!);
        }
      } else {
        final cameraImage = await _startImageStream();
        image = _convertImage(cameraImage);
      }

      if (image == null) {
        return null;
      }
      final [x, y, width, height] = img.findTrim(image, mode: img.TrimMode.transparent);
      final minSize = [width, height].min;
      int x1, y1;
      if (width > height) {
        x1 = ((width - height) / 2).toInt();
        y1 = 0;
      } else {
        x1 = 0;
        y1 = ((height - width) / 2).toInt();
      }
      img.Image cropped = img.copyCrop(image, x: x1, y: y1, width: minSize, height: minSize);

      return Uint8List.fromList(img.encodeJpg(cropped));
      // return file;
    } on CameraException catch (e) {
      _showCameraException(e);
      return null;
    }
  }

  Future<void> toggleFlashMode() async {
    _flashMode = switch (_flashMode) {
      FlashMode.always => FlashMode.off,
      FlashMode.off => FlashMode.always,
      _ => FlashMode.auto,
    };
    await _setFlashMode(flashMode);
  }

  Future<void> _setFlashMode(FlashMode mode) async {
    try {
      await controller?.setFlashMode(mode);
    } on CameraException catch (e) {
      _showCameraException(e);
    }
  }

  Future<void> switchCamera() async {
    for (final camera in _cameras ?? []) {
      if (camera.lensDirection != _camera?.lensDirection) {
        _camera = camera;
        await controller?.setDescription(camera);
        await _setFlashMode(flashMode);
        return;
      }
    }
  }
}
