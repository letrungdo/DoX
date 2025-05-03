import 'package:auto_route/auto_route.dart';
import 'package:do_x/router/app_router.gr.dart';
import 'package:do_x/store/app_data.dart';
import 'package:do_x/view_model/core/core_view_model.dart';

class InitViewModel extends CoreViewModel {
  @override
  void initData() {
    super.initData();
    if (appData.user?.idToken == null) {
      context.replaceRoute(const LoginRoute());
    } else {
      context.replaceRoute(const MainRoute());
    }
  }
}
