import 'package:do_ai/services/auth_service.dart';
import 'package:do_ai/utils/logger.dart';
import 'package:do_ai/view_model/core/core_view_model.dart';
import 'package:do_ai/view_model/mixin/auth.mixin.dart';
import 'package:provider/provider.dart';

class LoginViewModel extends CoreViewModel with AuthMixin {
  AuthService get _authService => context.read<AuthService>();

  String _username = "";
  String get username => _username;

  String _password = "";
  String get password => _password;

  void onUsernameChanged(String value) {
    _username = value;
  }

  void onPasswordChanged(String value) {
    _password = value;
  }

  void onLogin() async {
    final result = await _authService.login(email: username, password: password);
    logger.d(result.toString());
  }
}
