import 'package:supabase_flutter/supabase_flutter.dart';

const _supabaseUrl = 'https://fyyrgwohjgvsmwqgxiga.supabase.co';
const _supabaseKey = 'sb_publishable_INnX8-J4b0vgHJlkD5lE3A_xG1S1SDs';

Future<void> initSupabase() {
  return Supabase.initialize(url: _supabaseUrl, publishableKey: _supabaseKey);
}

SupabaseClient get supabase => Supabase.instance.client;
