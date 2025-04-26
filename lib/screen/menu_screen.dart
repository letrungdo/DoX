import 'package:do_ai/screen/core/app_scaffold.dart';
import 'package:do_ai/screen/core/screen_state.dart';
import 'package:do_ai/view_model/menu_view_model.dart';
import 'package:do_ai/widgets/app_bar/app_bar_base.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class MenuScreen extends StatefulScreen implements ProviderWrapper {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();

  @override
  Widget providerWrapper() {
    return ChangeNotifierProvider(
      create: (_) => MenuViewModel(), //
      child: this,
    );
  }
}

class _MenuScreenState<V extends MenuViewModel> extends ScreenState<MenuScreen, V> {
  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: DoAppBar(title: "Menu"), //
      child: Padding(
        padding: const EdgeInsets.all(15), //
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        SizedBox(height: 50),
        ElevatedButton(
          onPressed: () => vm.onLogout(),
          child: Text("Logout"), //
        ),
      ],
    );
  }
}
