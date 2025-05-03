import 'package:crop_your_image/crop_your_image.dart';
import 'package:do_x/screen/modal/crop_image_modal.dart';
import 'package:do_x/services/auth_service.dart';
import 'package:do_x/services/locket_service.dart';
import 'package:do_x/services/upload_service.dart';
import 'package:do_x/store/app_data.dart';
import 'package:do_x/utils/logger.dart';
import 'package:do_x/view_model/core/core_view_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:provider/provider.dart';

class LocketViewModel extends CoreViewModel {
  LocketService get _locketService => context.read<LocketService>();
  UploadService get _uploadService => context.read<UploadService>();
  AuthService get _authService => context.read<AuthService>();

  XFile? _media;

  Uint8List? _croppedImage;
  Uint8List? get croppedImage => _croppedImage;

  late final cropController = CropController();

  bool _isUploading = false;
  bool get isUploading => _isUploading;

  String? _caption;
  String? get caption => _caption ?? "";

  late final _picker = ImagePicker();

  void _setUploading(bool value) {
    _isUploading = value;
    notifyListenersSafe();
  }

  void onCaptionChanged(String value) {
    _caption = value;
  }

  Future<void> pickMedia() async {
    final xFile = await _picker.pickMedia(maxHeight: 2000, maxWidth: 2000);
    if (xFile == null) return;

    final imageData = await xFile.readAsBytes();
    if (!context.mounted) return;
    _media = xFile;
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
          image: imageData,
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
    renewCancelToken("upload");
    _setUploading(true);

    await _authService.refreshToken(cancelToken: cancelToken);

    if (mime.startsWith("image/")) {
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
        _setUploading(false);

        showAppError(
          // ignore: use_build_context_synchronously
          context,
          uploadRes.error,
          onRetry: () => startUpload(),
        );
        return;
      }
      final thumbnailUrl = uploadRes.data!;
      logger.d("thumbnailUrl: $thumbnailUrl");

      final resPost = await _locketService.postImage(
        thumbnailUrl, //
        caption: caption,
        user: appData.user!,
        cancelToken: cancelToken,
      );
      _setUploading(false);
      if (resPost.isError) {
        showAppError(
          // ignore: use_build_context_synchronously
          context,
          resPost.error,
          onRetry: () => startUpload(),
        );
        return;
      }
      if (!context.mounted) return;
      _clearInput();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Post photo success!"), //
        ),
      );
    }
  }

  void _clearInput() {
    _croppedImage = null;
    _media = null;
    _caption = null;
    notifyListenersSafe();
  }

  void _onCropped(CropResult result) {
    if (result is CropSuccess) {
      _croppedImage = result.croppedImage;
    } else if (result is CropFailure) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.cause.toString()), //
        ),
      );
    }
    notifyListenersSafe();
  }
}
