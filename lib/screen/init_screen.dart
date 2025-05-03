import 'package:auto_route/auto_route.dart';
import 'package:do_x/screen/core/app_scaffold.dart';
import 'package:do_x/screen/core/screen_state.dart';
import 'package:do_x/view_model/init_view_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

@RoutePage()
class InitScreen extends StatefulScreen implements AutoRouteWrapper {
  const InitScreen({super.key});

  @override
  State<InitScreen> createState() => _InitScreenState();

  @override
  Widget wrappedRoute(BuildContext context) {
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
