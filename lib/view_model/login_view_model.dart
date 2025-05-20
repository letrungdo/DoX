import 'package:auto_route/auto_route.dart';
import 'package:do_x/model/response/user_model.dart';
import 'package:do_x/router/app_router.gr.dart';
import 'package:do_x/services/locket/auth_service.dart';
import 'package:do_x/services/secure_storage_service.dart';
import 'package:do_x/store/app_data.dart';
import 'package:do_x/utils/logger.dart';
import 'package:do_x/view_model/core/core_view_model.dart';
import 'package:provider/provider.dart';

class LoginViewModel extends CoreViewModel {
  AuthService get _authService => context.read<AuthService>();

  String? _username = appData.user?.email;
  String get username => _username ?? "";

  String? _password = appData.user?.password;
  String get password => _password ?? "";

  void onUsernameChanged(String value) {
    _username = value;
  }

  void onPasswordChanged(String value) {
    _password = value;
  }

  void onLogin() async {
    setBusy(true);
    final result = await _authService.login(email: username, password: password);
    setBusy(false);

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
    secureStorage.saveAccount(
      result.data?.copyWith(
        password: password, //
      ),
    );

    if (!context.mounted) return;

    context.replaceRoute(const LocketRoute());
  }
}
