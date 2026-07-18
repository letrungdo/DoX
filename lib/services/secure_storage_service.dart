import 'dart:convert';

import 'package:do_x/constants/storage.dart';
import 'package:do_x/model/electric/electric_account.dart';
import 'package:do_x/model/response/user_model.dart';
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
    final expiryTime = DateTime.now().millisecondsSinceEpoch + ((value?.expiresIn ?? 0) * 1000);
    value = value?.copyWith(expiryTime: expiryTime);
    appData.setUser(value);

    final encode = jsonEncode(value?.toJson());
    return _secureStorage.write(key: StorageKey.accountInfo, value: encode);
  }

  Future<({String email, String password})?> getSupabaseAccount() async {
    try {
      final raw = await _secureStorage.read(key: StorageKey.supabaseAccount);
      final json = jsonDecode(raw ?? "");
      return (email: json['email'] as String, password: json['password'] as String);
    } catch (e) {
      return null;
    }
  }

  Future<void> saveSupabaseAccount({required String email, required String password}) {
    return _secureStorage.write(key: StorageKey.supabaseAccount, value: jsonEncode({'email': email, 'password': password}));
  }

  Future<List<ElectricAccount>> getCpcAccounts() async {
    try {
      final raw = await _secureStorage.read(key: StorageKey.cpcAccounts);
      if (raw == null) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => ElectricAccount.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> saveCpcAccounts(List<ElectricAccount> accounts) {
    return _secureStorage.write(
      key: StorageKey.cpcAccounts,
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
