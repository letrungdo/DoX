import 'dart:convert';

import 'package:do_x/constants/storage.dart';
import 'package:do_x/services/secure_storage_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('reads the legacy single Supabase account format', () async {
    FlutterSecureStorage.setMockInitialValues({
      StorageKey.supabaseAccount: jsonEncode({
        'email': 'old@example.com',
        'password': 'old-password',
      }),
    });

    final accounts = await secureStorage.getSupabaseAccounts();

    expect(accounts, hasLength(1));
    expect(accounts.single.email, 'old@example.com');
    expect(accounts.single.password, 'old-password');
  });

  test('upserts Supabase accounts without duplicating email case', () async {
    await secureStorage.saveSupabaseAccount(
      email: 'first@example.com',
      password: 'first-password',
    );
    await secureStorage.saveSupabaseAccount(
      email: 'second@example.com',
      password: 'second-password',
    );
    await secureStorage.saveSupabaseAccount(
      email: 'FIRST@example.com',
      password: 'updated-password',
    );

    final accounts = await secureStorage.getSupabaseAccounts();

    expect(accounts.map((account) => account.email), [
      'second@example.com',
      'FIRST@example.com',
    ]);
    expect(accounts.last.password, 'updated-password');
  });

  test('removes only the requested Supabase account', () async {
    await secureStorage.saveSupabaseAccount(
      email: 'first@example.com',
      password: 'first-password',
    );
    await secureStorage.saveSupabaseAccount(
      email: 'second@example.com',
      password: 'second-password',
    );

    await secureStorage.removeSupabaseAccount('FIRST@example.com');

    final accounts = await secureStorage.getSupabaseAccounts();
    expect(accounts.map((account) => account.email), ['second@example.com']);
  });
}
