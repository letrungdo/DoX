import 'package:do_x/screen/main_screen.dart';
import 'package:do_x/services/auth_service.dart';
import 'package:do_x/store/app_data.dart';
import 'package:do_x/utils/logger.dart';
import 'package:do_x/view_model/core/core_view_model.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class LoginViewModel extends CoreViewModel {
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
    if (result.isError) {
      showAppError(
        // ignore: use_build_context_synchronously
        context,
        result.error,
        onRetry: onLogin,
      );
      return;
    }
    logger.d("idToken: ${result.data?.idToken}");

    appData.setUser(result.data);
    if (!context.mounted) return;

    context.replace(MainScreen.path);
  }
}
