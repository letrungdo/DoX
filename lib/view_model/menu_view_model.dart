import 'package:do_ai/services/auth_service.dart';
import 'package:do_ai/view_model/core/core_view_model.dart';
import 'package:provider/provider.dart';

class MenuViewModel extends CoreViewModel {
  AuthService get _authService => context.read<AuthService>();

  void onLogout() async {
    _authService.logout();
  }
}
