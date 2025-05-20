import 'package:auto_route/auto_route.dart';
import 'package:do_x/router/app_router.gr.dart';
import 'package:do_x/services/myLife/auth_service.dart';
import 'package:do_x/services/myLife/my_life_service.dart';
import 'package:do_x/services/secure_storage_service.dart';
import 'package:do_x/store/app_data.dart';
import 'package:do_x/view_model/core/core_view_model.dart';
import 'package:provider/provider.dart';

class AccountViewModel extends CoreViewModel {
  AuthService get _authService => context.read<AuthService>();
  MyLifeService get _myLifeService => context.read<MyLifeService>();

  @override
  void initData() {
    super.initData();
    _myLifeService.fetchUserV2(user: appData.user);
  }

  void onLogout() async {
    _authService.logout();
    secureStorage.saveAccount(appData.user);
    context.replaceRoute(const LoginRoute());
  }
}
