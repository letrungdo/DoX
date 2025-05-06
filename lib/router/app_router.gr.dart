// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AutoRouterGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:auto_route/auto_route.dart' as _i7;
import 'package:do_x/screen/account_screen.dart' as _i1;
import 'package:do_x/screen/init_screen.dart' as _i2;
import 'package:do_x/screen/locket_screen.dart' as _i3;
import 'package:do_x/screen/login_screen.dart' as _i4;
import 'package:do_x/screen/main_screen.dart' as _i5;
import 'package:do_x/screen/news_screen.dart' as _i6;

/// generated route for
/// [_i1.AccountScreen]
class AccountRoute extends _i7.PageRouteInfo<void> {
  const AccountRoute({List<_i7.PageRouteInfo>? children})
    : super(AccountRoute.name, initialChildren: children);

  static const String name = 'AccountRoute';

  static _i7.PageInfo page = _i7.PageInfo(
    name,
    builder: (data) {
      return _i7.WrappedRoute(child: const _i1.AccountScreen());
    },
  );
}

/// generated route for
/// [_i2.InitScreen]
class InitRoute extends _i7.PageRouteInfo<void> {
  const InitRoute({List<_i7.PageRouteInfo>? children})
    : super(InitRoute.name, initialChildren: children);

  static const String name = 'InitRoute';

  static _i7.PageInfo page = _i7.PageInfo(
    name,
    builder: (data) {
      return _i7.WrappedRoute(child: const _i2.InitScreen());
    },
  );
}

/// generated route for
/// [_i3.LocketScreen]
class LocketRoute extends _i7.PageRouteInfo<void> {
  const LocketRoute({List<_i7.PageRouteInfo>? children})
    : super(LocketRoute.name, initialChildren: children);

  static const String name = 'LocketRoute';

  static _i7.PageInfo page = _i7.PageInfo(
    name,
    builder: (data) {
      return _i7.WrappedRoute(child: const _i3.LocketScreen());
    },
  );
}

/// generated route for
/// [_i4.LoginScreen]
class LoginRoute extends _i7.PageRouteInfo<void> {
  const LoginRoute({List<_i7.PageRouteInfo>? children})
    : super(LoginRoute.name, initialChildren: children);

  static const String name = 'LoginRoute';

  static _i7.PageInfo page = _i7.PageInfo(
    name,
    builder: (data) {
      return _i7.WrappedRoute(child: const _i4.LoginScreen());
    },
  );
}

/// generated route for
/// [_i5.MainScreen]
class MainRoute extends _i7.PageRouteInfo<void> {
  const MainRoute({List<_i7.PageRouteInfo>? children})
    : super(MainRoute.name, initialChildren: children);

  static const String name = 'MainRoute';

  static _i7.PageInfo page = _i7.PageInfo(
    name,
    builder: (data) {
      return _i7.WrappedRoute(child: const _i5.MainScreen());
    },
  );
}

/// generated route for
/// [_i6.NewsScreen]
class NewsRoute extends _i7.PageRouteInfo<void> {
  const NewsRoute({List<_i7.PageRouteInfo>? children})
    : super(NewsRoute.name, initialChildren: children);

  static const String name = 'NewsRoute';

  static _i7.PageInfo page = _i7.PageInfo(
    name,
    builder: (data) {
      return _i7.WrappedRoute(child: const _i6.NewsScreen());
    },
  );
}
