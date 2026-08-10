import 'package:auto_route/auto_route.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/router/app_router.gr.dart';
import 'package:do_x/services/auth_flow_service.dart';
import 'package:do_x/services/secure_storage_service.dart';
import 'package:do_x/services/supabase_service.dart';
import 'package:do_x/utils/auth_error.dart';
import 'package:do_x/view_model/core/core_view_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UpdatePasswordViewModel extends CoreViewModel {
  UpdatePasswordViewModel({required this.isRecovery});

  /// True when the session came from a password-reset email. Supabase already
  /// proved the user owns the mailbox, so there is no current password to ask
  /// for — and asking for one would lock out exactly the people who forgot it.
  final bool isRecovery;

  String _currentPassword = '';
  String _newPassword = '';

  String get newPassword => _newPassword;

  void onCurrentPasswordChanged(String value) => _currentPassword = value;
  void onNewPasswordChanged(String value) => _newPassword = value;

  String? validateConfirmation(String? value) {
    if (value != _newPassword) return _l10n.passwordMismatch;
    return null;
  }

  Future<void> submit() async {
    final email = supabase.auth.currentUser?.email;
    if (email == null) return;

    final successMessage = _l10n.passwordUpdated;
    setBusy(true);
    try {
      if (!isRecovery) {
        // Supabase happily changes the password on the strength of the session
        // alone. That is one unlocked phone away from a stolen account, so the
        // current password is checked first.
        await supabase.auth.signInWithPassword(
          email: email,
          password: _currentPassword,
        );
      }
      await supabase.auth.updateUser(UserAttributes(password: _newPassword));
      await secureStorage.saveSupabaseAccount(
        email: email,
        password: _newPassword,
      );
      _showMessage(successMessage);
      _close();
    } catch (e) {
      _showMessage(authErrorMessage(_l10n, e), isError: true);
    } finally {
      setBusy(false);
    }
  }

  Future<void> _close() async {
    if (!context.mounted) return;
    final router = context.router;
    // Reached from the recovery email, this page can be the whole stack.
    if (!router.canPop()) {
      router.replaceAll([const MainRoute()]);
      return;
    }
    await router.maybePop();
    // A recovery leaves the login form — and the code screen, when the user
    // typed the code instead of following the link — sitting underneath. The
    // password is set and the session is live, so neither has anything left to
    // ask for.
    await authFlowService.unwindAuthScreens();
  }

  AppLocalizations get _l10n => context.l10n;

  void _showMessage(String message, {bool isError = false}) {
    if (!context.mounted) return;
    context.showToast(message, isError: isError);
  }
}
