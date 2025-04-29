import 'package:do_x/screen/login_screen.dart';
import 'package:do_x/view_model/core/core_view_model.dart';
import 'package:go_router/go_router.dart';

class InitViewModel extends CoreViewModel {
  @override
  void initData() {
    super.initData();
    context.replace(LoginScreen.path);
  }
}
