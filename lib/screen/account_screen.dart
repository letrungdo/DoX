import 'package:auto_route/auto_route.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/screen/core/screen_state.dart';
import 'package:do_x/store/app_data.dart';
import 'package:do_x/view_model/account_view_model.dart';
import 'package:do_x/widgets/app_bar/app_bar_base.dart';
import 'package:do_x/widgets/button.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

@RoutePage()
class AccountScreen extends StatefulScreen implements AutoRouteWrapper {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();

  @override
  Widget wrappedRoute(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AccountViewModel(), //
      child: this,
    );
  }
}

class _AccountScreenState<V extends AccountViewModel> extends ScreenState<AccountScreen, V> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: DoAppBar(title: appData.user?.displayName),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(15), //
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        SizedBox(height: 50),
        Align(
          alignment: Alignment.center,
          child: DoButton(
            onPressed: () => vm.onLogout(),
            text: context.l10n.logout, //
          ),
        ),
      ],
    );
  }
}
