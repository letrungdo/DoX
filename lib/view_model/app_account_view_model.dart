import 'dart:typed_data';

import 'package:auto_route/auto_route.dart';
import 'package:do_x/constants/auth_links.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/repository/avatar_repository.dart';
import 'package:do_x/router/app_router.gr.dart';
import 'package:do_x/services/secure_storage_service.dart';
import 'package:do_x/services/supabase_service.dart';
import 'package:do_x/utils/auth_error.dart';
import 'package:do_x/utils/logger.dart';
import 'package:do_x/view_model/core/core_view_model.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppAccountViewModel extends CoreViewModel {
  final _avatarRepository = AvatarRepository();
  final _picker = ImagePicker();

  User? get user => supabase.auth.currentUser;

  String? get avatarUrl =>
      user?.userMetadata?[AvatarRepository.metadataKey] as String?;

  /// Picks a picture, hands it to the cropper, and uploads what comes back.
  ///
  /// Returns the cropped bytes to the caller rather than uploading straight
  /// away, because the cropper is a modal the screen owns.
  Future<Uint8List?> pickAvatar(ImageSource source) async {
    final file = await _picker.pickImage(source: source);
    if (file == null) return null;
    return file.readAsBytes();
  }

  Future<void> uploadAvatar(Uint8List cropped) async {
    final successMessage = _l10n.avatarUpdated;
    setBusy(true);
    try {
      // 512 square is what the largest circle in the app asks for at 3x, and
      // webp keeps it under a hundred kilobytes.
      final compressed = await FlutterImageCompress.compressWithList(
        cropped,
        minWidth: 512,
        minHeight: 512,
        quality: 85,
        format: CompressFormat.webp,
      );
      await _avatarRepository.upload(compressed);
      _showMessage(successMessage);
    } catch (e) {
      logger.e('avatar upload failed', error: e);
      _showMessage(_l10n.avatarUploadFailed, isError: true);
    } finally {
      setBusy(false);
    }
  }

  Future<void> removeAvatar() async {
    final removedMessage = _l10n.avatarRemoved;
    setBusy(true);
    try {
      await _avatarRepository.remove();
      _showMessage(removedMessage);
    } catch (e) {
      _showError(e);
    } finally {
      setBusy(false);
    }
  }

  Future<void> signOut() async {
    setBusy(true);
    try {
      await supabase.auth.signOut();
      _leaveAccountScreen();
    } catch (e) {
      _showError(e);
    } finally {
      setBusy(false);
    }
  }

  Future<void> resendConfirmationEmail() async {
    final email = user?.email;
    if (email == null) return;

    final sentMessage = _l10n.confirmationEmailSent;
    setBusy(true);
    try {
      await supabase.auth.resend(
        type: OtpType.signup,
        email: email,
        emailRedirectTo: AuthLinks.emailConfirmation,
      );
      _showMessage(sentMessage);
    } catch (e) {
      _showError(e);
    } finally {
      setBusy(false);
    }
  }

  /// Deletes the account for good. [password] is checked first: the session
  /// alone is enough for Supabase, but a phone left unlocked is not enough for
  /// something this final.
  ///
  /// Returns true when the account is gone.
  Future<bool> deleteAccount(String password) async {
    final email = user?.email;
    if (email == null) return false;

    final deletedMessage = _l10n.accountDeleted;
    setBusy(true);
    try {
      await supabase.auth.signInWithPassword(email: email, password: password);
      // Runs with the service role: a client may not delete its own auth user.
      // Everything the account owns goes with it via `on delete cascade`.
      await supabase.functions.invoke('delete-account');
      await supabase.auth.signOut();
      await secureStorage.removeSupabaseAccount(email);
      _showMessage(deletedMessage);
      _leaveAccountScreen();
      return true;
    } catch (e) {
      _showError(e);
      return false;
    } finally {
      setBusy(false);
    }
  }

  /// The account screen is only reachable while signed in, so it has to go as
  /// soon as the session does.
  void _leaveAccountScreen() {
    if (!context.mounted) return;
    final router = context.router;
    if (router.canPop()) {
      router.maybePop();
    } else {
      router.replaceAll([const MainRoute()]);
    }
  }

  AppLocalizations get _l10n => context.l10n;

  void _showError(Object error) {
    _showMessage(authErrorMessage(_l10n, error), isError: true);
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!context.mounted) return;
    context.showToast(message, isError: isError);
  }
}
