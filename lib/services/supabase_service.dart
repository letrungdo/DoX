import 'package:do_x/constants/env.dart';
import 'package:do_x/utils/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> initSupabase() {
  return Supabase.initialize(
    url: Envs.supabaseUrl,
    publishableKey: Envs.supabaseKey,
    // Recovery is completed on the website, which cannot access the PKCE
    // verifier stored by the mobile app. The implicit flow returns the
    // recovery session in the URL fragment for the web page to consume.
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.implicit,
    ),
  );
}

SupabaseClient get supabase => Supabase.instance.client;

/// Gets the client past an access token the server will not take any more.
///
/// A session refreshes itself while the app is running, but not while it is
/// not: a phone left alone for long enough — or a television box suspended
/// between evenings — comes back holding a token that expired hours ago, and
/// every read fails with `PGRST303` until something clears it. Nothing did,
/// so the pages that need no account at all — the news, the exchange rates,
/// the channel list — sat behind an error dialog for a signed-in user that a
/// signed-out one could read fine.
///
/// Returns whether the caller should try its request again.
Future<bool> recoverExpiredSupabaseSession() async {
  if (supabase.auth.currentSession == null) return false;
  try {
    await supabase.auth.refreshSession();
    return true;
  } on Object catch (e, st) {
    logger.d('Supabase session refresh failed', error: e, stackTrace: st);
    // The refresh token is spent too, so there is no session to be had. Drop
    // it locally — not on the server, which is exactly what cannot be
    // reached — and the client goes back to the publishable key, which is
    // all the public tables ever needed.
    try {
      await supabase.auth.signOut(scope: SignOutScope.local);
    } on Object catch (e, st) {
      logger.d('Supabase local sign out failed', error: e, stackTrace: st);
    }
    return true;
  }
}

/// Whether [error] is the server refusing a token rather than the request.
bool isExpiredSessionError(Object error) {
  if (error is AuthException) return true;
  if (error is! PostgrestException) return false;
  // Reported two ways depending on how far the request got: as the code
  // itself, or as a 401 whose message carries the code inside it.
  return error.code == _expiredJwtCode ||
      error.message.contains(_expiredJwtCode) ||
      error.message.contains('JWT expired');
}

const _expiredJwtCode = 'PGRST303';
