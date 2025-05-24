import 'dart:io';

import 'package:auto_route/auto_route.dart';
import 'package:camera/camera.dart';
import 'package:carousel_slider/carousel_controller.dart';
import 'package:collection/collection.dart';
import 'package:do_x/constants/enum/overlay_type.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/router/app_router.gr.dart';
import 'package:do_x/screen/modal/crop_image_modal.dart';
import 'package:do_x/services/locket/locket_service.dart';
import 'package:do_x/services/locket/upload_service.dart';
import 'package:do_x/store/app_data.dart';
import 'package:do_x/utils/logger.dart';
import 'package:do_x/view_model/core/core_view_model.dart';
import 'package:do_x/view_model/locket/overlays.mixin.dart';
import 'package:do_x/widgets/do_camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_sficon/flutter_sficon.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

class LocketViewModel extends CoreViewModel with LocketOverlays {
  LocketService get _locketService => context.read<LocketService>();
  UploadService get _uploadService => context.read<UploadService>();

  final cameraKey = GlobalKey();

  DoCameraState? get _cameraState => cameraKey.currentState as DoCameraState?;

  Uint8List? _croppedImage;
  Uint8List? get croppedImage => _croppedImage;

  late final carouselController = CarouselSliderController();

  bool _isPickingFile = false;
  bool get isPickingFile => _isPickingFile;

  late final _picker = ImagePicker();

  Uint8List? _videoCroped;
  Uint8List? get videoCroped => _videoCroped;

  FlashMode get flashMode => _cameraState?.flashMode ?? FlashMode.off;

  void _setPickingFile(bool value) {
    _isPickingFile = value;
    notifyListenersSafe();
  }

  Future<void> pickPhoto() async {
    _setPickingFile(true);
    final xFile = await _picker.pickImage(source: ImageSource.gallery);
    _setPickingFile(false);
    if (xFile == null) return;

    final imageData = await xFile.readAsBytes();
    if (!context.mounted) return;
    _videoCroped = null;
    _openCropImage(imageData);
  }

  Future<void> pickVideo() async {
    _setPickingFile(true);
    final xFile = await _picker.pickVideo(source: ImageSource.gallery);
    _setPickingFile(false);
    if (xFile == null) return;
    if (!context.mounted) return;

    final result = await context.router.push<List<String?>?>(TrimmerRoute(file: File(xFile.path)));
    if (result == null) return;
    final [videoPath, coverPath] = result;
    if (videoPath == null) {
      if (!context.mounted) return;
      showErrorMessage(context, message: "Can't export video!");
      return;
    }
    if (coverPath == null) {
      if (!context.mounted) return;
      showErrorMessage(context, message: "Can't get video thumbnail!");
      return;
    }
    await Future.wait([
      File(videoPath).readAsBytes().then((data) => _videoCroped = data),
      File(coverPath).readAsBytes().then((data) => _croppedImage = data),
    ]);
    notifyListenersSafe();
  }

  void _openCropImage(Uint8List image) {
    showModalBottomSheet<void>(
      backgroundColor: context.theme.scaffoldBackgroundColor,
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      enableDrag: false,
      builder: (BuildContext context) {
        return CropImageModal(onCropped: _onCropped, image: image);
      },
    );
  }

  void startUpload() async {
    if (_croppedImage == null) {
      showErrorMessage(context, message: "Thumbnail is not set!");
      return;
    }
    if (_videoCroped != null) {
      _postVideo();
      return;
    }
    _postImage();
  }

  void cancelUpload() {
    _clearInput();
  }

  void showOverlaysModal() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.theme.scaffoldBackgroundColor,
      showDragHandle: true,
      // isScrollControlled: true,
      enableDrag: true,
      builder: (BuildContext context) {
        return Container(
          alignment: Alignment.topCenter,
          padding: EdgeInsets.only(top: 20),
          child: Wrap(
            runSpacing: 15,
            spacing: 8,
            children: [
              ...OverlayType.values.mapIndexed((index, type) {
                return TextButton(
                  style: ButtonStyle(
                    backgroundColor: WidgetStatePropertyAll(context.theme.colorScheme.primaryContainer), //
                  ),
                  onPressed: () {
                    carouselController.jumpToPage(index);
                    context.pop();
                  },
                  child: switch (type) {
                    OverlayType.standard => Text("Aa Text"),
                    OverlayType.review => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SFIcon(
                          SFIcons.sf_star_fill,
                          fontSize: 16,
                          color: Colors.amber, //
                        ),
                        SizedBox(width: 4),
                        Text("Review"),
                      ],
                    ),
                    // OverlayType.music =>
                    OverlayType.location => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [Icon(Icons.location_on), SizedBox(width: 4), Text("Location")],
                    ),
                    OverlayType.weather => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [SFIcon(SFIcons.sf_sun_max_fill, fontSize: 16), SizedBox(width: 4), Text("Weather")],
                    ),
                    OverlayType.time => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [SFIcon(SFIcons.sf_clock, fontSize: 16), SizedBox(width: 4), Text("Time")],
                    ),
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Future<String?> _uploadImage() async {
    final imgData = await FlutterImageCompress.compressWithList(
      _croppedImage!, //
      minWidth: 1020,
      minHeight: 1020,
      format: CompressFormat.webp,
    );
    final uploadRes = await _uploadService.uploadImage(
      data: imgData, //
      user: appData.user!,
      cancelToken: cancelToken,
    );
    if (uploadRes.isError) {
      return null;
    }
    final thumbnailUrl = uploadRes.data!;
    logger.d("thumbnailUrl: $thumbnailUrl");
    return thumbnailUrl;
  }

  Future<String?> _uploadVideo(Uint8List videoCompressed) async {
    final uploadRes = await _uploadService.uploadVideo(
      data: videoCompressed, //
      user: appData.user!,
      cancelToken: cancelToken,
    );
    if (uploadRes.isError) {
      return null;
    }
    final videoUrl = uploadRes.data!;
    logger.d("videoUrl: $videoUrl");
    return videoUrl;
  }

  Future<void> _postImage() async {
    renewCancelToken("upload image");
    setBusy(true);

    final thumbnailUrl = await _uploadImage();

    final resPost = await _locketService.postImage(
      thumbnailUrl, //
      overlayType: OverlayType.options[overlayIndex],
      user: appData.user!,
      cancelToken: cancelToken,
      caption: caption,
      reviewCaption: reviewCaption,
      reviewRating: reviewRating,
      currentTime: currentTime,
      weather: weatherData,
      locationName: currentLocation,
      textColor: overlayTextColor,
      bgColors: [overlayBgColor, overlayBgColor],
    );
    setBusy(false);
    if (resPost.isError) {
      showAppError(
        // ignore: use_build_context_synchronously
        context,
        resPost.error,
        onRetry: () => _postImage(),
      );
      return;
    }
    if (!context.mounted) return;
    _clearInput();
    showErrorMessage(context, message: "Post photo success!");
  }

  Future<void> _postVideo() async {
    if (videoCroped == null) {
      return;
    }
    renewCancelToken("upload video");
    setBusy(true);

    final [thumbnailUrl, videoUrl] = await Future.wait([
      _uploadImage(), //
      _uploadVideo(videoCroped!),
    ]);

    final resPost = await _locketService.postVideo(
      overlayType: OverlayType.values[overlayIndex],
      user: appData.user!,
      cancelToken: cancelToken,
      thumbnailUrl: thumbnailUrl, //
      videoUrl: videoUrl,
      caption: caption,
      reviewCaption: reviewCaption,
      reviewRating: reviewRating,
      currentTime: currentTime,
      weather: weatherData,
      locationName: currentLocation,
      textColor: overlayTextColor,
      bgColors: [overlayBgColor, overlayBgColor],
    );
    setBusy(false);
    if (resPost.isError) {
      showAppError(
        // ignore: use_build_context_synchronously
        context,
        resPost.error,
        onRetry: () => _postVideo(),
      );
      return;
    }
    if (!context.mounted) return;
    _clearInput();
    showErrorMessage(context, message: "Post video success!");
  }

  void _clearInput() {
    _croppedImage = null;
    clearOverlayInput();
    _videoCroped = null;
    notifyListenersSafe();
  }

  void _onCropped(Uint8List imgData) async {
    _croppedImage = imgData;
    notifyListenersSafe();
  }

  void capture() async {
    final dataImg = await _cameraState?.takePicture();
    _croppedImage = dataImg;
    notifyListenersSafe();
  }

  void toggleFlash() async {
    await _cameraState?.toggleFlashMode();
    notifyListenersSafe();
  }

  void switchCamera() {
    _cameraState?.switchCamera();
  }
}
