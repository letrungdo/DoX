import 'package:auto_route/auto_route.dart';
import 'package:do_x/router/app_router.gr.dart';
import 'package:do_x/services/locket/auth_service.dart';
import 'package:do_x/services/locket/locket_service.dart';
import 'package:do_x/services/secure_storage_service.dart';
import 'package:do_x/store/app_data.dart';
import 'package:do_x/view_model/core/core_view_model.dart';
import 'package:provider/provider.dart';

class AccountViewModel extends CoreViewModel {
  AuthService get _authService => context.read<AuthService>();
  LocketService get _locketService => context.read<LocketService>();

  @override
  void initData() {
    super.initData();
    _locketService.fetchUserV2(user: appData.user);
  }

  void onLogout() async {
    _authService.logout();
    secureStorage.saveAccount(appData.user);
    context.replaceRoute(const LoginRoute());
  }
}
