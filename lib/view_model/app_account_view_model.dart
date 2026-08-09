import 'package:auto_route/auto_route.dart';
import 'package:do_x/constants/auth_links.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/router/app_router.gr.dart';
import 'package:do_x/services/secure_storage_service.dart';
import 'package:do_x/services/supabase_service.dart';
import 'package:do_x/utils/auth_error.dart';
import 'package:do_x/view_model/core/core_view_model.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppAccountViewModel extends CoreViewModel {
  User? get user => supabase.auth.currentUser;

  Future<void> signOut() async {
    setBusy(true);
    try {
      await supabase.auth.signOut();
      await secureStorage.clearSupabaseAccount();
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
      await secureStorage.clearSupabaseAccount();
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
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        isError
            ? context.errorSnackBar(message)
            : SnackBar(content: Text(message)),
      );
  }
}
