import 'package:supabase_flutter/supabase_flutter.dart';

const _supabaseUrl = 'https://fyyrgwohjgvsmwqgxiga.supabase.co';
const _supabaseKey = 'sb_publishable_INnX8-J4b0vgHJlkD5lE3A_xG1S1SDs';

Future<void> initSupabase() {
  return Supabase.initialize(
    url: _supabaseUrl,
    publishableKey: _supabaseKey,
    // Recovery is completed on the website, which cannot access the PKCE
    // verifier stored by the mobile app. The implicit flow returns the
    // recovery session in the URL fragment for the web page to consume.
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.implicit,
    ),
  );
}

SupabaseClient get supabase => Supabase.instance.client;
