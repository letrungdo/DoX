import 'package:do_x/constants/env.dart';
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
