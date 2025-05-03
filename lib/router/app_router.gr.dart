// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AutoRouterGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:auto_route/auto_route.dart' as _i6;
import 'package:do_x/screen/init_screen.dart' as _i1;
import 'package:do_x/screen/locket_screen.dart' as _i2;
import 'package:do_x/screen/login_screen.dart' as _i3;
import 'package:do_x/screen/main_screen.dart' as _i4;
import 'package:do_x/screen/menu_screen.dart' as _i5;

/// generated route for
/// [_i1.InitScreen]
class InitRoute extends _i6.PageRouteInfo<void> {
  const InitRoute({List<_i6.PageRouteInfo>? children})
    : super(InitRoute.name, initialChildren: children);

  static const String name = 'InitRoute';

  static _i6.PageInfo page = _i6.PageInfo(
    name,
    builder: (data) {
      return _i6.WrappedRoute(child: const _i1.InitScreen());
    },
  );
}

/// generated route for
/// [_i2.LocketScreen]
class LocketRoute extends _i6.PageRouteInfo<void> {
  const LocketRoute({List<_i6.PageRouteInfo>? children})
    : super(LocketRoute.name, initialChildren: children);

  static const String name = 'LocketRoute';

  static _i6.PageInfo page = _i6.PageInfo(
    name,
    builder: (data) {
      return _i6.WrappedRoute(child: const _i2.LocketScreen());
    },
  );
}

/// generated route for
/// [_i3.LoginScreen]
class LoginRoute extends _i6.PageRouteInfo<void> {
  const LoginRoute({List<_i6.PageRouteInfo>? children})
    : super(LoginRoute.name, initialChildren: children);

  static const String name = 'LoginRoute';

  static _i6.PageInfo page = _i6.PageInfo(
    name,
    builder: (data) {
      return _i6.WrappedRoute(child: const _i3.LoginScreen());
    },
  );
}

/// generated route for
/// [_i4.MainScreen]
class MainRoute extends _i6.PageRouteInfo<void> {
  const MainRoute({List<_i6.PageRouteInfo>? children})
    : super(MainRoute.name, initialChildren: children);

  static const String name = 'MainRoute';

  static _i6.PageInfo page = _i6.PageInfo(
    name,
    builder: (data) {
      return _i6.WrappedRoute(child: const _i4.MainScreen());
    },
  );
}

/// generated route for
/// [_i5.MenuScreen]
class MenuRoute extends _i6.PageRouteInfo<void> {
  const MenuRoute({List<_i6.PageRouteInfo>? children})
    : super(MenuRoute.name, initialChildren: children);

  static const String name = 'MenuRoute';

  static _i6.PageInfo page = _i6.PageInfo(
    name,
    builder: (data) {
      return _i6.WrappedRoute(child: const _i5.MenuScreen());
    },
  );
}
