import 'package:auto_route/auto_route.dart';
import 'package:do_x/constants/auth_links.dart';
import 'package:do_x/router/app_router.gr.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/services/secure_storage_service.dart';
import 'package:do_x/services/supabase_service.dart';
import 'package:do_x/utils/auth_error.dart';
import 'package:do_x/view_model/verify_otp_view_model.dart';
import 'package:do_x/view_model/core/core_view_model.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Which half of the form the user is on. One screen serves both, because the
/// two differ by a single field and swapping in place is faster than pushing
/// another page.
enum AuthMode { signIn, signUp }

class AppLoginViewModel extends CoreViewModel {
  AuthMode _mode = AuthMode.signIn;
  AuthMode get mode => _mode;

  String _email = '';
  String get email => _email;

  String _password = '';
  String get password => _password;

  String _confirmPassword = '';
  String get confirmPassword => _confirmPassword;

  /// Set once a sign-up went through without a session: the account exists but
  /// is waiting on the link in this address's inbox. The screen swaps the form
  /// for a "check your mail" panel while it is set.
  String? _pendingConfirmationEmail;
  String? get pendingConfirmationEmail => _pendingConfirmationEmail;

  @override
  void initState() async {
    super.initState();
    final saved = await secureStorage.getSupabaseAccount();
    if (saved != null) {
      _email = saved.email;
      _password = saved.password;
      notifyListenersSafe();
    }
  }

  void onEmailChanged(String value) {
    _email = value;
  }

  void onPasswordChanged(String value) {
    _password = value;
  }

  void onConfirmPasswordChanged(String value) {
    _confirmPassword = value;
  }

  void setMode(AuthMode value) {
    if (_mode == value) return;
    _mode = value;
    _confirmPassword = '';
    notifyListenersSafe();
  }

  /// Back to the form from the "check your mail" panel.
  void cancelPendingConfirmation() {
    _pendingConfirmationEmail = null;
    _mode = AuthMode.signIn;
    notifyListenersSafe();
  }

  Future<void> submit() {
    return _mode == AuthMode.signIn ? _signIn() : _signUp();
  }

  Future<void> _signIn() async {
    setBusy(true);
    try {
      await supabase.auth.signInWithPassword(
        email: _email.trim(),
        password: _password,
      );
      // Navigation is `authFlowService`'s job — it has to happen for a session
      // that arrives from an email link too, not just from this form.
      await secureStorage.saveSupabaseAccount(
        email: _email.trim(),
        password: _password,
      );
    } on AuthException catch (e) {
      // The account exists but was never activated: the useful next step is
      // another copy of the email, not the error on its own.
      if (e.code == 'email_not_confirmed') {
        _pendingConfirmationEmail = _email.trim();
        notifyListenersSafe();
      }
      _showError(e);
    } catch (e) {
      _showError(e);
    } finally {
      setBusy(false);
    }
  }

  Future<void> _signUp() async {
    setBusy(true);
    try {
      final result = await supabase.auth.signUp(
        email: _email.trim(),
        password: _password,
        emailRedirectTo: AuthLinks.emailConfirmation,
      );
      // Saved even while the account is unconfirmed: confirming on a desktop
      // browser leaves the phone back on this form, and the credentials it
      // pre-fills are the ones just typed.
      await secureStorage.saveSupabaseAccount(
        email: _email.trim(),
        password: _password,
      );
      // A session here means email confirmation is switched off on the project
      // and the account is usable right away.
      if (result.session != null) return;

      _pendingConfirmationEmail = _email.trim();
      notifyListenersSafe();
    } catch (e) {
      _showError(e);
    } finally {
      setBusy(false);
    }
  }

  Future<void> resendConfirmationEmail() async {
    final email = _pendingConfirmationEmail ?? _email.trim();
    if (email.isEmpty) return;

    setBusy(true);
    try {
      await supabase.auth.resend(
        type: OtpType.signup,
        email: email,
        emailRedirectTo: AuthLinks.emailConfirmation,
      );
      _showMessage(_l10n.confirmationEmailSent);
    } catch (e) {
      _showError(e);
    } finally {
      setBusy(false);
    }
  }

  Future<void> onForgotPassword() async {
    final email = _email.trim();
    if (email.isEmpty) {
      _showMessage(_l10n.emailRequired, isError: true);
      return;
    }

    setBusy(true);
    try {
      await supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: AuthLinks.passwordRecovery,
      );
      _showMessage(_l10n.forgotPasswordSent(email));
      // Straight on to the code screen. Following the link in the email works
      // and is the faster path, but it only comes back to *this* device — and
      // the reader has no way of knowing that until it doesn't.
      if (context.mounted) {
        context.router.push(
          VerifyOtpRoute(email: email, purpose: OtpPurpose.recovery),
        );
      }
    } catch (e) {
      _showError(e);
    } finally {
      setBusy(false);
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
