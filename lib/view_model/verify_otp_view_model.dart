import 'package:do_x/constants/auth_links.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/services/supabase_service.dart';
import 'package:do_x/utils/auth_error.dart';
import 'package:do_x/view_model/core/core_view_model.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Which email the code came out of. The two differ in the OTP type Supabase
/// expects and in how a fresh code is asked for.
enum OtpPurpose { recovery, signup }

/// Backs the "type the code from the email" screen.
///
/// Every auth email carries a one-time code beside its button, and it is the
/// only way through when the link cannot come back to this device — the mail
/// was opened on a laptop, or the deep link lost the fragment on the way.
class VerifyOtpViewModel extends CoreViewModel {
  VerifyOtpViewModel({required this.email, required this.purpose});

  final String email;
  final OtpPurpose purpose;

  String _code = '';

  void onCodeChanged(String value) => _code = value;

  Future<void> submit() async {
    setBusy(true);
    try {
      await supabase.auth.verifyOTP(
        email: email,
        token: _code.trim(),
        type: purpose == OtpPurpose.recovery
            ? OtpType.recovery
            : OtpType.signup,
      );
      // No navigation here on purpose. Verifying emits the same auth event the
      // link in the email would have, and `authFlowService` answers it — so
      // the code and the link land the user in exactly the same place.
    } catch (e) {
      _showMessage(authErrorMessage(_l10n, e), isError: true);
    } finally {
      setBusy(false);
    }
  }

  Future<void> resend() async {
    final sentMessage = _l10n.codeSent;
    setBusy(true);
    try {
      switch (purpose) {
        case OtpPurpose.recovery:
          await supabase.auth.resetPasswordForEmail(
            email,
            redirectTo: AuthLinks.passwordRecovery,
          );
        case OtpPurpose.signup:
          await supabase.auth.resend(
            type: OtpType.signup,
            email: email,
            emailRedirectTo: AuthLinks.emailConfirmation,
          );
      }
      _showMessage(sentMessage);
    } catch (e) {
      _showMessage(authErrorMessage(_l10n, e), isError: true);
    } finally {
      setBusy(false);
    }
  }

  AppLocalizations get _l10n => context.l10n;

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
