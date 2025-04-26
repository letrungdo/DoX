import 'dart:io';

import 'package:do_ai/services/locket_service.dart';
import 'package:do_ai/utils/logger.dart';
import 'package:do_ai/view_model/core/core_view_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:provider/provider.dart';

class HomeViewModel extends CoreViewModel {
  LocketService get _locketService => context.read<LocketService>();

  XFile? _media;
  XFile? get media => _media;

  late final _picker = ImagePicker();

  Future<void> pickMedia() async {
    final xFile = await _picker.pickMedia(maxHeight: 2000, maxWidth: 2000);
    _media = xFile;
    notifyListeners();
  }

  void upload() async {
    final m = media;
    if (m == null) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final mime = lookupMimeType(m.path);
    if (mime == null) return;

    if (mime.startsWith("image/")) {
      final imageFile = File(m.path);
      final originalImage = img.decodeImage(await imageFile.readAsBytes());

      if (originalImage == null) return;
      final targetWidth = 600;
      final newHeight = (originalImage.height * targetWidth / originalImage.width).round();
      final resizedImage = img.copyResize(originalImage, width: targetWidth, height: newHeight);
      final resizedImageData = img.encodeJpg(resizedImage);

      final thumbnailUrl = await _locketService.uploadImage(
        data: resizedImageData, //
        userId: user.uid,
      );
      logger.d("thumbnailUrl: $thumbnailUrl");
      if (thumbnailUrl == null) return;
      _locketService.postImage(thumbnailUrl, "test");
    }
  }
}
