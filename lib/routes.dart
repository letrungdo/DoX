import 'package:do_ai/screen/init_screen.dart';
import 'package:do_ai/screen/login_screen.dart';
import 'package:do_ai/screen/main_screen.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

CustomTransitionPage _defaultTransition<T>(
  BuildContext context, {
  required GoRouterState state, //
  required Widget child,
}) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) => FadeTransition(opacity: animation, child: child),
  );
}

final routerConfig = GoRouter(
  routes: <RouteBase>[
    GoRoute(
      path: InitScreen.path,
      builder: (context, state) {
        return const InitScreen().providerWrapper();
      },
    ),
    GoRoute(
      path: LoginScreen.path,
      pageBuilder: (context, state) {
        return _defaultTransition(
          context, //
          state: state,
          child: const LoginScreen().providerWrapper(),
        );
      },
    ),
    GoRoute(
      path: MainScreen.path,
      pageBuilder: (context, state) {
        return _defaultTransition(
          context, //
          state: state,
          child: const MainScreen().providerWrapper(),
        );
      },
    ),
  ],
);
