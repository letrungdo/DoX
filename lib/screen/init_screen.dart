import 'package:do_x/screen/core/app_scaffold.dart';
import 'package:do_x/screen/core/screen_state.dart';
import 'package:do_x/view_model/init_view_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class InitScreen extends StatefulScreen implements ProviderWrapper {
  const InitScreen({super.key});

  static const path = "/";

  @override
  State<InitScreen> createState() => _InitScreenState();

  @override
  Widget providerWrapper() {
    return ChangeNotifierProvider(
      create: (_) => InitViewModel(), //
      child: this,
    );
  }
}

class _InitScreenState extends ScreenState<InitScreen, InitViewModel> {
  @override
  Widget build(BuildContext context) {
    return AppScaffold();
  }
}
