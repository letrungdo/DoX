import 'package:do_x/screen/login_screen.dart';
import 'package:do_x/services/auth_service.dart';
import 'package:do_x/view_model/core/core_view_model.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class MenuViewModel extends CoreViewModel {
  AuthService get _authService => context.read<AuthService>();

  void onLogout() async {
    _authService.logout();
    context.replace(LoginScreen.path);
  }
}
