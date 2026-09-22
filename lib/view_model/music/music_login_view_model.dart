import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/services/music_auth_service.dart';
import 'package:do_x/utils/logger.dart';
import 'package:do_x/view_model/core/core_view_model.dart';

class MusicLoginViewModel extends CoreViewModel {
  /// What went wrong with the last attempt, already translated. Shown above
  /// the sign-in page, which is where the user would try again.
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool get isSignedIn => musicAuth.isSignedIn;

  String get accountName => musicAuth.account?.username ?? '';

  /// Redeems the authorization code the sign-in page came back with. Returns
  /// true once the account is stored, so the screen can leave.
  Future<bool> signInWithCode({
    required String code,
    required String verifier,
  }) {
    return _signIn(
      () => musicAuth.signInWithCode(code: code, verifier: verifier),
    );
  }

  /// The fallback: the token the site leaves in its own cookie once the
  /// sign-in has gone through.
  Future<bool> signInWithToken(String token) {
    return _signIn(() => musicAuth.signInWithToken(token));
  }

  Future<bool> _signIn(Future<void> Function() attempt) async {
    if (isBusy) return false;
    final l10n = context.l10n;
    _errorMessage = null;
    setBusy(true);
    try {
      await attempt();
      return true;
    } on MusicAuthException catch (e) {
      _errorMessage = _messageFor(l10n, e.kind);
      return false;
    } catch (e, st) {
      logger.e('MusicLoginViewModel sign-in failed', error: e, stackTrace: st);
      _errorMessage = l10n.musicLoginFailed;
      return false;
    } finally {
      setBusy(false);
    }
  }

  Future<void> signOut() async {
    await musicAuth.signOut();
    notifyListenersSafe();
  }

  String _messageFor(AppLocalizations l10n, MusicAuthError kind) {
    return switch (kind) {
      MusicAuthError.rejected => l10n.musicLoginRejected,
      MusicAuthError.network => l10n.musicLoginNetwork,
      MusicAuthError.unknown => l10n.musicLoginFailed,
    };
  }
}
