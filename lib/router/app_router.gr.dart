// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AutoRouterGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:io' as _i14;

import 'package:auto_route/auto_route.dart' as _i12;
import 'package:do_x/screen/chicken/chicken_batch_detail_screen.dart' as _i2;
import 'package:do_x/screen/chicken/chicken_screen.dart' as _i3;
import 'package:do_x/screen/chicken/chicken_statistics_screen.dart' as _i4;
import 'package:do_x/screen/chicken/cock_sales_screen.dart' as _i5;
import 'package:do_x/screen/locket/account_screen.dart' as _i1;
import 'package:do_x/screen/locket/locket_screen.dart' as _i6;
import 'package:do_x/screen/locket/login_screen.dart' as _i7;
import 'package:do_x/screen/locket/trimmer_screen.dart' as _i11;
import 'package:do_x/screen/main_screen.dart' as _i8;
import 'package:do_x/screen/menu_screen.dart' as _i9;
import 'package:do_x/screen/news_screen.dart' as _i10;
import 'package:flutter/material.dart' as _i13;

/// generated route for
/// [_i1.AccountScreen]
class AccountRoute extends _i12.PageRouteInfo<void> {
  const AccountRoute({List<_i12.PageRouteInfo>? children})
    : super(AccountRoute.name, initialChildren: children);

  static const String name = 'AccountRoute';

  static _i12.PageInfo page = _i12.PageInfo(
    name,
    builder: (data) {
      return _i12.WrappedRoute(child: const _i1.AccountScreen());
    },
  );
}

/// generated route for
/// [_i2.ChickenBatchDetailScreen]
class ChickenBatchDetailRoute
    extends _i12.PageRouteInfo<ChickenBatchDetailRouteArgs> {
  ChickenBatchDetailRoute({
    _i13.Key? key,
    required String batchId,
    List<_i12.PageRouteInfo>? children,
  }) : super(
         ChickenBatchDetailRoute.name,
         args: ChickenBatchDetailRouteArgs(key: key, batchId: batchId),
         initialChildren: children,
       );

  static const String name = 'ChickenBatchDetailRoute';

  static _i12.PageInfo page = _i12.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<ChickenBatchDetailRouteArgs>();
      return _i12.WrappedRoute(
        child: _i2.ChickenBatchDetailScreen(
          key: args.key,
          batchId: args.batchId,
        ),
      );
    },
  );
}

class ChickenBatchDetailRouteArgs {
  const ChickenBatchDetailRouteArgs({this.key, required this.batchId});

  final _i13.Key? key;

  final String batchId;

  @override
  String toString() {
    return 'ChickenBatchDetailRouteArgs{key: $key, batchId: $batchId}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ChickenBatchDetailRouteArgs) return false;
    return key == other.key && batchId == other.batchId;
  }

  @override
  int get hashCode => key.hashCode ^ batchId.hashCode;
}

/// generated route for
/// [_i3.ChickenScreen]
class ChickenRoute extends _i12.PageRouteInfo<void> {
  const ChickenRoute({List<_i12.PageRouteInfo>? children})
    : super(ChickenRoute.name, initialChildren: children);

  static const String name = 'ChickenRoute';

  static _i12.PageInfo page = _i12.PageInfo(
    name,
    builder: (data) {
      return _i12.WrappedRoute(child: const _i3.ChickenScreen());
    },
  );
}

/// generated route for
/// [_i4.ChickenStatisticsScreen]
class ChickenStatisticsRoute extends _i12.PageRouteInfo<void> {
  const ChickenStatisticsRoute({List<_i12.PageRouteInfo>? children})
    : super(ChickenStatisticsRoute.name, initialChildren: children);

  static const String name = 'ChickenStatisticsRoute';

  static _i12.PageInfo page = _i12.PageInfo(
    name,
    builder: (data) {
      return _i12.WrappedRoute(child: const _i4.ChickenStatisticsScreen());
    },
  );
}

/// generated route for
/// [_i5.CockSalesScreen]
class CockSalesRoute extends _i12.PageRouteInfo<void> {
  const CockSalesRoute({List<_i12.PageRouteInfo>? children})
    : super(CockSalesRoute.name, initialChildren: children);

  static const String name = 'CockSalesRoute';

  static _i12.PageInfo page = _i12.PageInfo(
    name,
    builder: (data) {
      return _i12.WrappedRoute(child: const _i5.CockSalesScreen());
    },
  );
}

/// generated route for
/// [_i6.LocketScreen]
class LocketRoute extends _i12.PageRouteInfo<void> {
  const LocketRoute({List<_i12.PageRouteInfo>? children})
    : super(LocketRoute.name, initialChildren: children);

  static const String name = 'LocketRoute';

  static _i12.PageInfo page = _i12.PageInfo(
    name,
    builder: (data) {
      return _i12.WrappedRoute(child: const _i6.LocketScreen());
    },
  );
}

/// generated route for
/// [_i7.LoginScreen]
class LoginRoute extends _i12.PageRouteInfo<void> {
  const LoginRoute({List<_i12.PageRouteInfo>? children})
    : super(LoginRoute.name, initialChildren: children);

  static const String name = 'LoginRoute';

  static _i12.PageInfo page = _i12.PageInfo(
    name,
    builder: (data) {
      return _i12.WrappedRoute(child: const _i7.LoginScreen());
    },
  );
}

/// generated route for
/// [_i8.MainScreen]
class MainRoute extends _i12.PageRouteInfo<void> {
  const MainRoute({List<_i12.PageRouteInfo>? children})
    : super(MainRoute.name, initialChildren: children);

  static const String name = 'MainRoute';

  static _i12.PageInfo page = _i12.PageInfo(
    name,
    builder: (data) {
      return _i12.WrappedRoute(child: const _i8.MainScreen());
    },
  );
}

/// generated route for
/// [_i9.MenuScreen]
class MenuRoute extends _i12.PageRouteInfo<void> {
  const MenuRoute({List<_i12.PageRouteInfo>? children})
    : super(MenuRoute.name, initialChildren: children);

  static const String name = 'MenuRoute';

  static _i12.PageInfo page = _i12.PageInfo(
    name,
    builder: (data) {
      return _i12.WrappedRoute(child: const _i9.MenuScreen());
    },
  );
}

/// generated route for
/// [_i10.NewsScreen]
class NewsRoute extends _i12.PageRouteInfo<void> {
  const NewsRoute({List<_i12.PageRouteInfo>? children})
    : super(NewsRoute.name, initialChildren: children);

  static const String name = 'NewsRoute';

  static _i12.PageInfo page = _i12.PageInfo(
    name,
    builder: (data) {
      return _i12.WrappedRoute(child: const _i10.NewsScreen());
    },
  );
}

/// generated route for
/// [_i11.TrimmerScreen]
class TrimmerRoute extends _i12.PageRouteInfo<TrimmerRouteArgs> {
  TrimmerRoute({
    required _i14.File file,
    _i13.Key? key,
    List<_i12.PageRouteInfo>? children,
  }) : super(
         TrimmerRoute.name,
         args: TrimmerRouteArgs(file: file, key: key),
         initialChildren: children,
       );

  static const String name = 'TrimmerRoute';

  static _i12.PageInfo page = _i12.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<TrimmerRouteArgs>();
      return _i11.TrimmerScreen(args.file, key: args.key);
    },
  );
}

class TrimmerRouteArgs {
  const TrimmerRouteArgs({required this.file, this.key});

  final _i14.File file;

  final _i13.Key? key;

  @override
  String toString() {
    return 'TrimmerRouteArgs{file: $file, key: $key}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! TrimmerRouteArgs) return false;
    return file == other.file && key == other.key;
  }

  @override
  int get hashCode => file.hashCode ^ key.hashCode;
}
