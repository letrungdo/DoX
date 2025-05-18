// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AutoRouterGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:io' as _i10;

import 'package:auto_route/auto_route.dart' as _i9;
import 'package:do_x/screen/account_screen.dart' as _i1;
import 'package:do_x/screen/init_screen.dart' as _i2;
import 'package:do_x/screen/locket_screen/locket_screen.dart' as _i3;
import 'package:do_x/screen/login_screen.dart' as _i4;
import 'package:do_x/screen/main_screen.dart' as _i5;
import 'package:do_x/screen/menu_screen.dart' as _i6;
import 'package:do_x/screen/news_screen.dart' as _i7;
import 'package:do_x/screen/trimmer_screen.dart' as _i8;
import 'package:flutter/material.dart' as _i11;

/// generated route for
/// [_i1.AccountScreen]
class AccountRoute extends _i9.PageRouteInfo<void> {
  const AccountRoute({List<_i9.PageRouteInfo>? children})
    : super(AccountRoute.name, initialChildren: children);

  static const String name = 'AccountRoute';

  static _i9.PageInfo page = _i9.PageInfo(
    name,
    builder: (data) {
      return _i9.WrappedRoute(child: const _i1.AccountScreen());
    },
  );
}

/// generated route for
/// [_i2.InitScreen]
class InitRoute extends _i9.PageRouteInfo<void> {
  const InitRoute({List<_i9.PageRouteInfo>? children})
    : super(InitRoute.name, initialChildren: children);

  static const String name = 'InitRoute';

  static _i9.PageInfo page = _i9.PageInfo(
    name,
    builder: (data) {
      return _i9.WrappedRoute(child: const _i2.InitScreen());
    },
  );
}

/// generated route for
/// [_i3.LocketScreen]
class LocketRoute extends _i9.PageRouteInfo<void> {
  const LocketRoute({List<_i9.PageRouteInfo>? children})
    : super(LocketRoute.name, initialChildren: children);

  static const String name = 'LocketRoute';

  static _i9.PageInfo page = _i9.PageInfo(
    name,
    builder: (data) {
      return _i9.WrappedRoute(child: const _i3.LocketScreen());
    },
  );
}

/// generated route for
/// [_i4.LoginScreen]
class LoginRoute extends _i9.PageRouteInfo<void> {
  const LoginRoute({List<_i9.PageRouteInfo>? children})
    : super(LoginRoute.name, initialChildren: children);

  static const String name = 'LoginRoute';

  static _i9.PageInfo page = _i9.PageInfo(
    name,
    builder: (data) {
      return _i9.WrappedRoute(child: const _i4.LoginScreen());
    },
  );
}

/// generated route for
/// [_i5.MainScreen]
class MainRoute extends _i9.PageRouteInfo<void> {
  const MainRoute({List<_i9.PageRouteInfo>? children})
    : super(MainRoute.name, initialChildren: children);

  static const String name = 'MainRoute';

  static _i9.PageInfo page = _i9.PageInfo(
    name,
    builder: (data) {
      return _i9.WrappedRoute(child: const _i5.MainScreen());
    },
  );
}

/// generated route for
/// [_i6.MenuScreen]
class MenuRoute extends _i9.PageRouteInfo<void> {
  const MenuRoute({List<_i9.PageRouteInfo>? children})
    : super(MenuRoute.name, initialChildren: children);

  static const String name = 'MenuRoute';

  static _i9.PageInfo page = _i9.PageInfo(
    name,
    builder: (data) {
      return _i9.WrappedRoute(child: const _i6.MenuScreen());
    },
  );
}

/// generated route for
/// [_i7.NewsScreen]
class NewsRoute extends _i9.PageRouteInfo<void> {
  const NewsRoute({List<_i9.PageRouteInfo>? children})
    : super(NewsRoute.name, initialChildren: children);

  static const String name = 'NewsRoute';

  static _i9.PageInfo page = _i9.PageInfo(
    name,
    builder: (data) {
      return _i9.WrappedRoute(child: const _i7.NewsScreen());
    },
  );
}

/// generated route for
/// [_i8.TrimmerScreen]
class TrimmerRoute extends _i9.PageRouteInfo<TrimmerRouteArgs> {
  TrimmerRoute({
    required _i10.File file,
    _i11.Key? key,
    List<_i9.PageRouteInfo>? children,
  }) : super(
         TrimmerRoute.name,
         args: TrimmerRouteArgs(file: file, key: key),
         initialChildren: children,
       );

  static const String name = 'TrimmerRoute';

  static _i9.PageInfo page = _i9.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<TrimmerRouteArgs>();
      return _i8.TrimmerScreen(args.file, key: args.key);
    },
  );
}

class TrimmerRouteArgs {
  const TrimmerRouteArgs({required this.file, this.key});

  final _i10.File file;

  final _i11.Key? key;

  @override
  String toString() {
    return 'TrimmerRouteArgs{file: $file, key: $key}';
  }
}
