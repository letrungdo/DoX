import 'package:do_x/model/response/user_model.dart';

class _AppData {
  UserModel? _user;
  UserModel? get user => _user;

  void setUser(UserModel? value) {
    _user = value;
  }

  void clearSession() {
    _user = null;
  }
}

/// Memory Stored Value
final appData = _AppData();
