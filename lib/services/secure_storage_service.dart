import 'dart:convert';

import 'package:do_x/constants/storage.dart';
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
    appData.setUser(value);

    final encode = jsonEncode(value?.toJson());
    return _secureStorage.write(key: StorageKey.accountInfo, value: encode);
  }
}

final secureStorage = _SecureStorageService();
