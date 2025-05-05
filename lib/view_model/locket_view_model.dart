import 'package:crop_your_image/crop_your_image.dart';
import 'package:do_x/constants/enum/overlay_type.dart';
import 'package:do_x/extensions/string_extensions.dart';
import 'package:do_x/screen/modal/crop_image_modal.dart';
import 'package:do_x/services/locket_service.dart';
import 'package:do_x/services/upload_service.dart';
import 'package:do_x/store/app_data.dart';
import 'package:do_x/utils/logger.dart';
import 'package:do_x/view_model/core/core_view_model.dart';
import 'package:do_x/view_model/mixin/compress_video.mixin.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:provider/provider.dart';

class LocketViewModel extends CoreViewModel with CompressVideoMixin {
  LocketService get _locketService => context.read<LocketService>();
  UploadService get _uploadService => context.read<UploadService>();

  XFile? _media;

  Uint8List? _croppedImage;
  Uint8List? get croppedImage => _croppedImage;

  late final cropController = CropController();

  bool _isPickingFile = false;
  bool get isPickingFile => _isPickingFile;

  String? _caption;
  String get caption => _caption ?? "";

  String? _reviewCaption;
  String get reviewCaption => _reviewCaption ?? "";
  double _reviewRating = 0;
  double get reviewRating => _reviewRating;

  DateTime? _currentTime;
  DateTime? get currentTime => _currentTime;

  int _overlayIndex = 0;
  int get overlayIndex => _overlayIndex;

  void setOverlayIndex(int index) {
    _overlayIndex = index;
    if (OverlayType.values[index] == OverlayType.time) {
      _currentTime = DateTime.now();
    }
    notifyListenersSafe();
  }

  void setReviewRating(double rating) {
    _reviewRating = rating;
    notifyListenersSafe();
  }

  late final _picker = ImagePicker();

  void _setPickingFile(bool value) {
    _isPickingFile = value;
    notifyListenersSafe();
  }

  void onCaptionChanged(String value) {
    _caption = value;
    notifyListenersSafe();
  }

  void onReviewCaptionChanged(String value) {
    _reviewCaption = value;
    notifyListenersSafe();
  }

  Future<void> pickMedia() async {
    _setPickingFile(true);
    final xFile = await _picker.pickMedia(maxHeight: 2000, maxWidth: 2000);
    _setPickingFile(false);
    if (xFile == null) return;

    final imageData = await xFile.readAsBytes();
    if (!context.mounted) return;
    _media = xFile;
    final mime = kIsWeb ? xFile.mimeType : lookupMimeType(xFile.path);
    if (mime == null) return;
    if (mime.isImage()) {
      clearCacheVideo();
      _openCropImage(imageData);
    } else if (mime.isVideo()) {
      final videoThumbnail = await getVideoThumbnail(xFile.path);
      if (!context.mounted) return;

      if (videoThumbnail == null) {
        showErrorMessage(context, message: "Can't get video thumbnail!");
        return;
      }
      _openCropImage(videoThumbnail);
      compressVideo(xFile.path);
    }
  }

  void _openCropImage(Uint8List image) {
    showModalBottomSheet<void>(
      context: context,
      // useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      enableDrag: false,
      builder: (BuildContext context) {
        return CropImageModal(
          controller: cropController,
          onCropped: _onCropped,
          image: image,
          onCrop: () {
            cropController.crop();
          },
        );
      },
    );
  }

  void startUpload() async {
    final m = _media;
    if (m == null) return;

    final mime = kIsWeb ? m.mimeType : lookupMimeType(m.path);
    if (mime == null || _croppedImage == null) return;

    if (mime.isImage()) {
      _postImage();
    } else if (mime.isVideo()) {
      _postVideo();
    }
  }

  Future<String?> _uploadImage() async {
    final imgData = await FlutterImageCompress.compressWithList(
      _croppedImage!, //
      minWidth: 800,
      minHeight: 800,
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
      caption: caption,
      reviewCaption: reviewCaption,
      reviewRating: reviewRating,
      currentTime: currentTime,
      overlayType: OverlayType.values[overlayIndex],
      user: appData.user!,
      cancelToken: cancelToken,
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
    if (videoCompressed == null) {
      return;
    }
    renewCancelToken("upload video");
    setBusy(true);

    final [thumbnailUrl, videoUrl] = await Future.wait([
      _uploadImage(), //
      _uploadVideo(videoCompressed!),
    ]);

    final resPost = await _locketService.postVideo(
      thumbnailUrl: thumbnailUrl, //
      videoUrl: videoUrl,
      caption: caption,
      reviewCaption: reviewCaption,
      reviewRating: reviewRating,
      currentTime: currentTime,
      overlayType: OverlayType.values[overlayIndex],
      user: appData.user!,
      cancelToken: cancelToken,
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
    _media = null;
    _caption = null;
    _reviewCaption = null;
    _reviewRating = 0;
    clearCacheVideo();
    notifyListenersSafe();
  }

  void _onCropped(CropResult result) {
    if (result is CropSuccess) {
      _croppedImage = result.croppedImage;
    } else if (result is CropFailure) {
      showErrorMessage(context, message: result.cause.toString());
    }
    notifyListenersSafe();
  }
}
