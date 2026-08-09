import 'package:do_x/l10n/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Turns a Supabase auth failure into a sentence the user can act on.
///
/// GoTrue's own `message` is English, lowercase and written for developers
/// ("Invalid login credentials"), so the cases a user actually hits are
/// translated here; anything unexpected falls back to the raw message, which
/// is still better than a generic apology when something odd happens.
String authErrorMessage(AppLocalizations l10n, Object error) {
  if (error is! AuthException) return l10n.authUnknownError;

  return switch (error.code) {
    'invalid_credentials' => l10n.authInvalidCredentials,
    'email_not_confirmed' => l10n.authEmailNotConfirmed,
    'user_already_exists' || 'email_exists' => l10n.authUserAlreadyExists,
    'weak_password' => l10n.authWeakPassword,
    'same_password' => l10n.passwordSameAsOld,
    'over_email_send_rate_limit' ||
    'over_request_rate_limit' => l10n.authRateLimited,
    'validation_failed' => l10n.emailInvalid,
    'otp_expired' => l10n.authOtpExpired,
    'session_expired' || 'session_not_found' => l10n.sessionExpired,
    _ => error.message,
  };
}
