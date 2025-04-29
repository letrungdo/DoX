import 'package:do_x/services/locket_service.dart';
import 'package:do_x/services/upload_service.dart';
import 'package:do_x/store/app_data.dart';
import 'package:do_x/utils/logger.dart';
import 'package:do_x/view_model/core/core_view_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:provider/provider.dart';

class HomeViewModel extends CoreViewModel {
  LocketService get _locketService => context.read<LocketService>();
  UploadService get _uploadService => context.read<UploadService>();

  XFile? _media;
  XFile? get media => _media;

  late final _picker = ImagePicker();

  Future<void> pickMedia() async {
    final xFile = await _picker.pickMedia(maxHeight: 2000, maxWidth: 2000);
    _media = xFile;
    notifyListeners();
  }

  void upload({String? caption = "test"}) async {
    final m = media;
    if (m == null) return;
    final user = appData.user;
    if (user == null) return;

    final mime = kIsWeb ? m.mimeType : lookupMimeType(m.path);
    if (mime == null) return;
    if (mime.startsWith("image/")) {
      final imgData = await FlutterImageCompress.compressWithList(
        await m.readAsBytes(),
        minWidth: 800,
        minHeight: 800,
        format: CompressFormat.webp,
      );
      final uploadRes = await _uploadService.uploadImage(
        data: imgData, //
        user: user,
      );
      if (uploadRes.isError) {
        showAppError(
          // ignore: use_build_context_synchronously
          context,
          uploadRes.error,
          onRetry: () => upload(),
        );
        return;
      }
      final thumbnailUrl = uploadRes.data;
      logger.d("thumbnailUrl: $thumbnailUrl");
      if (thumbnailUrl == null) return;
      _locketService.postImage(thumbnailUrl, caption: caption, user: user);
    }
  }
}
