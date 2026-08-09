import 'dart:convert';

import 'package:do_x/constants/storage.dart';
import 'package:do_x/model/electric/electric_account.dart';
import 'package:do_x/model/response/user_model.dart';
import 'package:do_x/model/supabase_account.dart';
import 'package:do_x/store/app_data.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class _SecureStorageService {
  final _secureStorage = const FlutterSecureStorage();

  Future<UserModel?> getAccount() async {
    try {
      final raw = await _secureStorage.read(key: StorageKey.accountInfo);
      final account = UserModel.fromJson(jsonDecode(raw ?? "{}"));
      appData.setUser(account);
      return account;
    } catch (e) {
      return null;
    }
  }

  Future<void> saveAccount(UserModel? value) {
    final expiryTime =
        DateTime.now().millisecondsSinceEpoch +
        ((value?.expiresIn ?? 0) * 1000);
    value = value?.copyWith(expiryTime: expiryTime);
    appData.setUser(value);

    final encode = jsonEncode(value?.toJson());
    return _secureStorage.write(key: StorageKey.accountInfo, value: encode);
  }

  /// Every Do X account that has signed in successfully on this device.
  ///
  /// Older releases stored one account as a JSON object. Accepting both shapes
  /// migrates it into the list on the next write without losing credentials.
  Future<List<SupabaseAccount>> getSupabaseAccounts() async {
    try {
      final raw = await _secureStorage.read(key: StorageKey.supabaseAccount);
      if (raw == null) return [];
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .map(
              (item) => SupabaseAccount.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList();
      }
      return [
        SupabaseAccount.fromJson(Map<String, dynamic>.from(decoded as Map)),
      ];
    } catch (_) {
      return [];
    }
  }

  /// Upserts one successful login, keeping the latest password and ordering it
  /// last so the most recently used account appears last in the picker.
  Future<void> saveSupabaseAccount({
    required String email,
    required String password,
  }) async {
    final normalized = email.trim().toLowerCase();
    final accounts = await getSupabaseAccounts();
    final updated = [
      ...accounts.where((account) => account.email.toLowerCase() != normalized),
      SupabaseAccount(email: email.trim(), password: password),
    ];
    await _writeSupabaseAccounts(updated);
  }

  Future<void> removeSupabaseAccount(String email) async {
    final normalized = email.trim().toLowerCase();
    final accounts = await getSupabaseAccounts();
    await _writeSupabaseAccounts(
      accounts
          .where((account) => account.email.toLowerCase() != normalized)
          .toList(),
    );
  }

  Future<void> _writeSupabaseAccounts(List<SupabaseAccount> accounts) {
    return _secureStorage.write(
      key: StorageKey.supabaseAccount,
      value: jsonEncode(accounts.map((account) => account.toJson()).toList()),
    );
  }

  /// Drops every saved Do X login. Prefer [removeSupabaseAccount] when the
  /// operation concerns only one account.
  Future<void> clearSupabaseAccount() {
    return _secureStorage.delete(key: StorageKey.supabaseAccount);
  }

  Future<List<ElectricAccount>> getCpcAccounts() =>
      _readCpcAccounts(StorageKey.cpcAccounts);

  Future<void> saveCpcAccounts(List<ElectricAccount> accounts) {
    return _writeCpcAccounts(StorageKey.cpcAccounts, accounts);
  }

  /// Accounts kept after logout so they can be signed in again with one tap.
  Future<List<ElectricAccount>> getCpcSavedAccounts() =>
      _readCpcAccounts(StorageKey.cpcSavedAccounts);

  Future<void> saveCpcSavedAccounts(List<ElectricAccount> accounts) {
    return _writeCpcAccounts(StorageKey.cpcSavedAccounts, accounts);
  }

  Future<List<ElectricAccount>> _readCpcAccounts(String key) async {
    try {
      final raw = await _secureStorage.read(key: key);
      if (raw == null) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => ElectricAccount.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> _writeCpcAccounts(String key, List<ElectricAccount> accounts) {
    return _secureStorage.write(
      key: key,
      value: jsonEncode(accounts.map((e) => e.toJson()).toList()),
    );
  }

  Future<String?> getRouterPassword() {
    return _secureStorage.read(key: StorageKey.routerPassword);
  }

  Future<void> saveRouterPassword(String value) {
    return _secureStorage.write(key: StorageKey.routerPassword, value: value);
  }
}

final secureStorage = _SecureStorageService();
