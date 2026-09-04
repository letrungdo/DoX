// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AutoRouterGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:io' as _i38;

import 'package:auto_route/auto_route.dart' as _i30;
import 'package:do_x/constants/enum/market_code.dart' as _i34;
import 'package:do_x/model/movie_model.dart' as _i36;
import 'package:do_x/screen/account/app_account_screen.dart' deferred as _i2;
import 'package:do_x/screen/account/app_login_screen.dart' deferred as _i3;
import 'package:do_x/screen/account/update_password_screen.dart'
    deferred as _i27;
import 'package:do_x/screen/account/verify_otp_screen.dart' deferred as _i28;
import 'package:do_x/screen/asset/asset_screen.dart' deferred as _i4;
import 'package:do_x/screen/asset/asset_summary_screen.dart' deferred as _i5;
import 'package:do_x/screen/chicken/chicken_batch_detail_screen.dart'
    deferred as _i6;
import 'package:do_x/screen/chicken/chicken_screen.dart' deferred as _i7;
import 'package:do_x/screen/chicken/chicken_settings_screen.dart'
    deferred as _i8;
import 'package:do_x/screen/chicken/chicken_statistics_screen.dart'
    deferred as _i9;
import 'package:do_x/screen/chicken/cock_sales_screen.dart' deferred as _i10;
import 'package:do_x/screen/chicken/global_expenses_screen.dart'
    deferred as _i14;
import 'package:do_x/screen/electric_screen.dart' deferred as _i11;
import 'package:do_x/screen/electric_settings_screen.dart' deferred as _i12;
import 'package:do_x/screen/feng_shui_compass_screen.dart' deferred as _i13;
import 'package:do_x/screen/image_editor/image_editor_screen.dart'
    deferred as _i15;
import 'package:do_x/screen/lunar_screen.dart' deferred as _i17;
import 'package:do_x/screen/main_screen.dart' deferred as _i18;
import 'package:do_x/screen/menu_screen.dart' deferred as _i20;
import 'package:do_x/screen/movie/movie_detail_controller.dart' as _i37;
import 'package:do_x/screen/movie/movie_detail_screen.dart' deferred as _i21;
import 'package:do_x/screen/movie/movie_screen.dart' deferred as _i22;
import 'package:do_x/screen/my_life/account_screen.dart' deferred as _i1;
import 'package:do_x/screen/my_life/login_screen.dart' deferred as _i16;
import 'package:do_x/screen/my_life/my_life_screen.dart' deferred as _i23;
import 'package:do_x/screen/my_life/trimmer_screen.dart' deferred as _i26;
import 'package:do_x/screen/network/wifi_management_screen.dart'
    deferred as _i29;
import 'package:do_x/screen/news/market_detail_screen.dart' deferred as _i19;
import 'package:do_x/screen/news/news_screen.dart' deferred as _i24;
import 'package:do_x/screen/settings_screen.dart' deferred as _i25;
import 'package:do_x/view_model/asset_view_model.dart' as _i32;
import 'package:do_x/view_model/electric_view_model.dart' as _i33;
import 'package:do_x/view_model/verify_otp_view_model.dart' as _i39;
import 'package:flutter/foundation.dart' as _i35;
import 'package:flutter/material.dart' as _i31;

/// generated route for
/// [_i1.AccountScreen]
class AccountRoute extends _i30.PageRouteInfo<void> {
  const AccountRoute({List<_i30.PageRouteInfo>? children})
    : super(AccountRoute.name, initialChildren: children);

  static const String name = 'AccountRoute';

  static _i30.PageInfo page = _i30.PageInfo(
    name,
    builder: (data) {
      return _i30.DeferredWidget(
        _i1.loadLibrary,
        () => _i30.WrappedRoute(child: _i1.AccountScreen()),
      );
    },
  );
}

/// generated route for
/// [_i2.AppAccountScreen]
class AppAccountRoute extends _i30.PageRouteInfo<void> {
  const AppAccountRoute({List<_i30.PageRouteInfo>? children})
    : super(AppAccountRoute.name, initialChildren: children);

  static const String name = 'AppAccountRoute';

  static _i30.PageInfo page = _i30.PageInfo(
    name,
    builder: (data) {
      return _i30.DeferredWidget(
        _i2.loadLibrary,
        () => _i30.WrappedRoute(child: _i2.AppAccountScreen()),
      );
    },
  );
}

/// generated route for
/// [_i3.AppLoginScreen]
class AppLoginRoute extends _i30.PageRouteInfo<void> {
  const AppLoginRoute({List<_i30.PageRouteInfo>? children})
    : super(AppLoginRoute.name, initialChildren: children);

  static const String name = 'AppLoginRoute';

  static _i30.PageInfo page = _i30.PageInfo(
    name,
    builder: (data) {
      return _i30.DeferredWidget(
        _i3.loadLibrary,
        () => _i30.WrappedRoute(child: _i3.AppLoginScreen()),
      );
    },
  );
}

/// generated route for
/// [_i4.AssetScreen]
class AssetRoute extends _i30.PageRouteInfo<void> {
  const AssetRoute({List<_i30.PageRouteInfo>? children})
    : super(AssetRoute.name, initialChildren: children);

  static const String name = 'AssetRoute';

  static _i30.PageInfo page = _i30.PageInfo(
    name,
    builder: (data) {
      return _i30.DeferredWidget(
        _i4.loadLibrary,
        () => _i30.WrappedRoute(child: _i4.AssetScreen()),
      );
    },
  );
}

/// generated route for
/// [_i5.AssetSummaryScreen]
class AssetSummaryRoute extends _i30.PageRouteInfo<AssetSummaryRouteArgs> {
  AssetSummaryRoute({
    _i31.Key? key,
    required _i32.AssetViewModel assetVm,
    List<_i30.PageRouteInfo>? children,
  }) : super(
         AssetSummaryRoute.name,
         args: AssetSummaryRouteArgs(key: key, assetVm: assetVm),
         initialChildren: children,
       );

  static const String name = 'AssetSummaryRoute';

  static _i30.PageInfo page = _i30.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<AssetSummaryRouteArgs>();
      return _i30.DeferredWidget(
        _i5.loadLibrary,
        () => _i30.WrappedRoute(
          child: _i5.AssetSummaryScreen(key: args.key, assetVm: args.assetVm),
        ),
      );
    },
  );
}

class AssetSummaryRouteArgs {
  const AssetSummaryRouteArgs({this.key, required this.assetVm});

  final _i31.Key? key;

  final _i32.AssetViewModel assetVm;

  @override
  String toString() {
    return 'AssetSummaryRouteArgs{key: $key, assetVm: $assetVm}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! AssetSummaryRouteArgs) return false;
    return key == other.key && assetVm == other.assetVm;
  }

  @override
  int get hashCode => key.hashCode ^ assetVm.hashCode;
}

/// generated route for
/// [_i6.ChickenBatchDetailScreen]
class ChickenBatchDetailRoute
    extends _i30.PageRouteInfo<ChickenBatchDetailRouteArgs> {
  ChickenBatchDetailRoute({
    _i31.Key? key,
    required String batchId,
    List<_i30.PageRouteInfo>? children,
  }) : super(
         ChickenBatchDetailRoute.name,
         args: ChickenBatchDetailRouteArgs(key: key, batchId: batchId),
         initialChildren: children,
       );

  static const String name = 'ChickenBatchDetailRoute';

  static _i30.PageInfo page = _i30.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<ChickenBatchDetailRouteArgs>();
      return _i30.DeferredWidget(
        _i6.loadLibrary,
        () => _i30.WrappedRoute(
          child: _i6.ChickenBatchDetailScreen(
            key: args.key,
            batchId: args.batchId,
          ),
        ),
      );
    },
  );
}

class ChickenBatchDetailRouteArgs {
  const ChickenBatchDetailRouteArgs({this.key, required this.batchId});

  final _i31.Key? key;

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
/// [_i7.ChickenScreen]
class ChickenRoute extends _i30.PageRouteInfo<void> {
  const ChickenRoute({List<_i30.PageRouteInfo>? children})
    : super(ChickenRoute.name, initialChildren: children);

  static const String name = 'ChickenRoute';

  static _i30.PageInfo page = _i30.PageInfo(
    name,
    builder: (data) {
      return _i30.DeferredWidget(
        _i7.loadLibrary,
        () => _i30.WrappedRoute(child: _i7.ChickenScreen()),
      );
    },
  );
}

/// generated route for
/// [_i8.ChickenSettingsScreen]
class ChickenSettingsRoute extends _i30.PageRouteInfo<void> {
  const ChickenSettingsRoute({List<_i30.PageRouteInfo>? children})
    : super(ChickenSettingsRoute.name, initialChildren: children);

  static const String name = 'ChickenSettingsRoute';

  static _i30.PageInfo page = _i30.PageInfo(
    name,
    builder: (data) {
      return _i30.DeferredWidget(
        _i8.loadLibrary,
        () => _i30.WrappedRoute(child: _i8.ChickenSettingsScreen()),
      );
    },
  );
}

/// generated route for
/// [_i9.ChickenStatisticsScreen]
class ChickenStatisticsRoute extends _i30.PageRouteInfo<void> {
  const ChickenStatisticsRoute({List<_i30.PageRouteInfo>? children})
    : super(ChickenStatisticsRoute.name, initialChildren: children);

  static const String name = 'ChickenStatisticsRoute';

  static _i30.PageInfo page = _i30.PageInfo(
    name,
    builder: (data) {
      return _i30.DeferredWidget(
        _i9.loadLibrary,
        () => _i30.WrappedRoute(child: _i9.ChickenStatisticsScreen()),
      );
    },
  );
}

/// generated route for
/// [_i10.CockSalesScreen]
class CockSalesRoute extends _i30.PageRouteInfo<void> {
  const CockSalesRoute({List<_i30.PageRouteInfo>? children})
    : super(CockSalesRoute.name, initialChildren: children);

  static const String name = 'CockSalesRoute';

  static _i30.PageInfo page = _i30.PageInfo(
    name,
    builder: (data) {
      return _i30.DeferredWidget(
        _i10.loadLibrary,
        () => _i30.WrappedRoute(child: _i10.CockSalesScreen()),
      );
    },
  );
}

/// generated route for
/// [_i11.ElectricScreen]
class ElectricRoute extends _i30.PageRouteInfo<void> {
  const ElectricRoute({List<_i30.PageRouteInfo>? children})
    : super(ElectricRoute.name, initialChildren: children);

  static const String name = 'ElectricRoute';

  static _i30.PageInfo page = _i30.PageInfo(
    name,
    builder: (data) {
      return _i30.DeferredWidget(
        _i11.loadLibrary,
        () => _i30.WrappedRoute(child: _i11.ElectricScreen()),
      );
    },
  );
}

/// generated route for
/// [_i12.ElectricSettingsScreen]
class ElectricSettingsRoute
    extends _i30.PageRouteInfo<ElectricSettingsRouteArgs> {
  ElectricSettingsRoute({
    _i31.Key? key,
    required _i33.ElectricViewModel electricVm,
    List<_i30.PageRouteInfo>? children,
  }) : super(
         ElectricSettingsRoute.name,
         args: ElectricSettingsRouteArgs(key: key, electricVm: electricVm),
         initialChildren: children,
       );

  static const String name = 'ElectricSettingsRoute';

  static _i30.PageInfo page = _i30.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<ElectricSettingsRouteArgs>();
      return _i30.DeferredWidget(
        _i12.loadLibrary,
        () => _i30.WrappedRoute(
          child: _i12.ElectricSettingsScreen(
            key: args.key,
            electricVm: args.electricVm,
          ),
        ),
      );
    },
  );
}

class ElectricSettingsRouteArgs {
  const ElectricSettingsRouteArgs({this.key, required this.electricVm});

  final _i31.Key? key;

  final _i33.ElectricViewModel electricVm;

  @override
  String toString() {
    return 'ElectricSettingsRouteArgs{key: $key, electricVm: $electricVm}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ElectricSettingsRouteArgs) return false;
    return key == other.key && electricVm == other.electricVm;
  }

  @override
  int get hashCode => key.hashCode ^ electricVm.hashCode;
}

/// generated route for
/// [_i13.FengShuiCompassScreen]
class FengShuiCompassRoute extends _i30.PageRouteInfo<void> {
  const FengShuiCompassRoute({List<_i30.PageRouteInfo>? children})
    : super(FengShuiCompassRoute.name, initialChildren: children);

  static const String name = 'FengShuiCompassRoute';

  static _i30.PageInfo page = _i30.PageInfo(
    name,
    builder: (data) {
      return _i30.DeferredWidget(
        _i13.loadLibrary,
        () => _i13.FengShuiCompassScreen(),
      );
    },
  );
}

/// generated route for
/// [_i14.GlobalExpensesScreen]
class GlobalExpensesRoute extends _i30.PageRouteInfo<void> {
  const GlobalExpensesRoute({List<_i30.PageRouteInfo>? children})
    : super(GlobalExpensesRoute.name, initialChildren: children);

  static const String name = 'GlobalExpensesRoute';

  static _i30.PageInfo page = _i30.PageInfo(
    name,
    builder: (data) {
      return _i30.DeferredWidget(
        _i14.loadLibrary,
        () => _i30.WrappedRoute(child: _i14.GlobalExpensesScreen()),
      );
    },
  );
}

/// generated route for
/// [_i15.ImageEditorScreen]
class ImageEditorRoute extends _i30.PageRouteInfo<void> {
  const ImageEditorRoute({List<_i30.PageRouteInfo>? children})
    : super(ImageEditorRoute.name, initialChildren: children);

  static const String name = 'ImageEditorRoute';

  static _i30.PageInfo page = _i30.PageInfo(
    name,
    builder: (data) {
      return _i30.DeferredWidget(
        _i15.loadLibrary,
        () => _i30.WrappedRoute(child: _i15.ImageEditorScreen()),
      );
    },
  );
}

/// generated route for
/// [_i16.LoginScreen]
class LoginRoute extends _i30.PageRouteInfo<void> {
  const LoginRoute({List<_i30.PageRouteInfo>? children})
    : super(LoginRoute.name, initialChildren: children);

  static const String name = 'LoginRoute';

  static _i30.PageInfo page = _i30.PageInfo(
    name,
    builder: (data) {
      return _i30.DeferredWidget(
        _i16.loadLibrary,
        () => _i30.WrappedRoute(child: _i16.LoginScreen()),
      );
    },
  );
}

/// generated route for
/// [_i17.LunarScreen]
class LunarRoute extends _i30.PageRouteInfo<void> {
  const LunarRoute({List<_i30.PageRouteInfo>? children})
    : super(LunarRoute.name, initialChildren: children);

  static const String name = 'LunarRoute';

  static _i30.PageInfo page = _i30.PageInfo(
    name,
    builder: (data) {
      return _i30.DeferredWidget(_i17.loadLibrary, () => _i17.LunarScreen());
    },
  );
}

/// generated route for
/// [_i18.MainScreen]
class MainRoute extends _i30.PageRouteInfo<void> {
  const MainRoute({List<_i30.PageRouteInfo>? children})
    : super(MainRoute.name, initialChildren: children);

  static const String name = 'MainRoute';

  static _i30.PageInfo page = _i30.PageInfo(
    name,
    builder: (data) {
      return _i30.DeferredWidget(
        _i18.loadLibrary,
        () => _i30.WrappedRoute(child: _i18.MainScreen()),
      );
    },
  );
}

/// generated route for
/// [_i19.MarketDetailScreen]
class MarketDetailRoute extends _i30.PageRouteInfo<MarketDetailRouteArgs> {
  MarketDetailRoute({
    _i31.Key? key,
    required _i34.MarketCode code,
    List<_i30.PageRouteInfo>? children,
  }) : super(
         MarketDetailRoute.name,
         args: MarketDetailRouteArgs(key: key, code: code),
         initialChildren: children,
       );

  static const String name = 'MarketDetailRoute';

  static _i30.PageInfo page = _i30.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<MarketDetailRouteArgs>();
      return _i30.DeferredWidget(
        _i19.loadLibrary,
        () => _i30.WrappedRoute(
          child: _i19.MarketDetailScreen(key: args.key, code: args.code),
        ),
      );
    },
  );
}

class MarketDetailRouteArgs {
  const MarketDetailRouteArgs({this.key, required this.code});

  final _i31.Key? key;

  final _i34.MarketCode code;

  @override
  String toString() {
    return 'MarketDetailRouteArgs{key: $key, code: $code}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! MarketDetailRouteArgs) return false;
    return key == other.key && code == other.code;
  }

  @override
  int get hashCode => key.hashCode ^ code.hashCode;
}

/// generated route for
/// [_i20.MenuScreen]
class MenuRoute extends _i30.PageRouteInfo<void> {
  const MenuRoute({List<_i30.PageRouteInfo>? children})
    : super(MenuRoute.name, initialChildren: children);

  static const String name = 'MenuRoute';

  static _i30.PageInfo page = _i30.PageInfo(
    name,
    builder: (data) {
      return _i30.DeferredWidget(
        _i20.loadLibrary,
        () => _i30.WrappedRoute(child: _i20.MenuScreen()),
      );
    },
  );
}

/// generated route for
/// [_i21.MovieDetailScreen]
class MovieDetailRoute extends _i30.PageRouteInfo<MovieDetailRouteArgs> {
  MovieDetailRoute({
    _i35.Key? key,
    required String movieUrl,
    required String movieId,
    _i36.Movie? initialMovie,
    bool embedded = false,
    double minimizeProgress = 1,
    _i35.ValueChanged<bool>? onFullScreenChanged,
    _i37.MovieDetailController? controller,
    _i35.ValueChanged<_i36.Movie>? onRelatedMovieTap,
    _i35.VoidCallback? onClose,
    _i35.VoidCallback? onMinimize,
    _i31.GestureDragStartCallback? onPlayerDragStart,
    _i31.GestureDragUpdateCallback? onPlayerDragUpdate,
    _i31.GestureDragEndCallback? onPlayerDragEnd,
    List<_i30.PageRouteInfo>? children,
  }) : super(
         MovieDetailRoute.name,
         args: MovieDetailRouteArgs(
           key: key,
           movieUrl: movieUrl,
           movieId: movieId,
           initialMovie: initialMovie,
           embedded: embedded,
           minimizeProgress: minimizeProgress,
           onFullScreenChanged: onFullScreenChanged,
           controller: controller,
           onRelatedMovieTap: onRelatedMovieTap,
           onClose: onClose,
           onMinimize: onMinimize,
           onPlayerDragStart: onPlayerDragStart,
           onPlayerDragUpdate: onPlayerDragUpdate,
           onPlayerDragEnd: onPlayerDragEnd,
         ),
         initialChildren: children,
       );

  static const String name = 'MovieDetailRoute';

  static _i30.PageInfo page = _i30.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<MovieDetailRouteArgs>();
      return _i30.DeferredWidget(
        _i21.loadLibrary,
        () => _i30.WrappedRoute(
          child: _i21.MovieDetailScreen(
            key: args.key,
            movieUrl: args.movieUrl,
            movieId: args.movieId,
            initialMovie: args.initialMovie,
            embedded: args.embedded,
            minimizeProgress: args.minimizeProgress,
            onFullScreenChanged: args.onFullScreenChanged,
            controller: args.controller,
            onRelatedMovieTap: args.onRelatedMovieTap,
            onClose: args.onClose,
            onMinimize: args.onMinimize,
            onPlayerDragStart: args.onPlayerDragStart,
            onPlayerDragUpdate: args.onPlayerDragUpdate,
            onPlayerDragEnd: args.onPlayerDragEnd,
          ),
        ),
      );
    },
  );
}

class MovieDetailRouteArgs {
  const MovieDetailRouteArgs({
    this.key,
    required this.movieUrl,
    required this.movieId,
    this.initialMovie,
    this.embedded = false,
    this.minimizeProgress = 1,
    this.onFullScreenChanged,
    this.controller,
    this.onRelatedMovieTap,
    this.onClose,
    this.onMinimize,
    this.onPlayerDragStart,
    this.onPlayerDragUpdate,
    this.onPlayerDragEnd,
  });

  final _i35.Key? key;

  final String movieUrl;

  final String movieId;

  final _i36.Movie? initialMovie;

  final bool embedded;

  final double minimizeProgress;

  final _i35.ValueChanged<bool>? onFullScreenChanged;

  final _i37.MovieDetailController? controller;

  final _i35.ValueChanged<_i36.Movie>? onRelatedMovieTap;

  final _i35.VoidCallback? onClose;

  final _i35.VoidCallback? onMinimize;

  final _i31.GestureDragStartCallback? onPlayerDragStart;

  final _i31.GestureDragUpdateCallback? onPlayerDragUpdate;

  final _i31.GestureDragEndCallback? onPlayerDragEnd;

  @override
  String toString() {
    return 'MovieDetailRouteArgs{key: $key, movieUrl: $movieUrl, movieId: $movieId, initialMovie: $initialMovie, embedded: $embedded, minimizeProgress: $minimizeProgress, onFullScreenChanged: $onFullScreenChanged, controller: $controller, onRelatedMovieTap: $onRelatedMovieTap, onClose: $onClose, onMinimize: $onMinimize, onPlayerDragStart: $onPlayerDragStart, onPlayerDragUpdate: $onPlayerDragUpdate, onPlayerDragEnd: $onPlayerDragEnd}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! MovieDetailRouteArgs) return false;
    return key == other.key &&
        movieUrl == other.movieUrl &&
        movieId == other.movieId &&
        initialMovie == other.initialMovie &&
        embedded == other.embedded &&
        minimizeProgress == other.minimizeProgress &&
        onFullScreenChanged == other.onFullScreenChanged &&
        controller == other.controller &&
        onRelatedMovieTap == other.onRelatedMovieTap &&
        onClose == other.onClose &&
        onMinimize == other.onMinimize &&
        onPlayerDragStart == other.onPlayerDragStart &&
        onPlayerDragUpdate == other.onPlayerDragUpdate &&
        onPlayerDragEnd == other.onPlayerDragEnd;
  }

  @override
  int get hashCode =>
      key.hashCode ^
      movieUrl.hashCode ^
      movieId.hashCode ^
      initialMovie.hashCode ^
      embedded.hashCode ^
      minimizeProgress.hashCode ^
      onFullScreenChanged.hashCode ^
      controller.hashCode ^
      onRelatedMovieTap.hashCode ^
      onClose.hashCode ^
      onMinimize.hashCode ^
      onPlayerDragStart.hashCode ^
      onPlayerDragUpdate.hashCode ^
      onPlayerDragEnd.hashCode;
}

/// generated route for
/// [_i22.MovieScreen]
class MovieRoute extends _i30.PageRouteInfo<void> {
  const MovieRoute({List<_i30.PageRouteInfo>? children})
    : super(MovieRoute.name, initialChildren: children);

  static const String name = 'MovieRoute';

  static _i30.PageInfo page = _i30.PageInfo(
    name,
    builder: (data) {
      return _i30.DeferredWidget(
        _i22.loadLibrary,
        () => _i30.WrappedRoute(child: _i22.MovieScreen()),
      );
    },
  );
}

/// generated route for
/// [_i23.MyLifeScreen]
class MyLifeRoute extends _i30.PageRouteInfo<void> {
  const MyLifeRoute({List<_i30.PageRouteInfo>? children})
    : super(MyLifeRoute.name, initialChildren: children);

  static const String name = 'MyLifeRoute';

  static _i30.PageInfo page = _i30.PageInfo(
    name,
    builder: (data) {
      return _i30.DeferredWidget(
        _i23.loadLibrary,
        () => _i30.WrappedRoute(child: _i23.MyLifeScreen()),
      );
    },
  );
}

/// generated route for
/// [_i24.NewsScreen]
class NewsRoute extends _i30.PageRouteInfo<void> {
  const NewsRoute({List<_i30.PageRouteInfo>? children})
    : super(NewsRoute.name, initialChildren: children);

  static const String name = 'NewsRoute';

  static _i30.PageInfo page = _i30.PageInfo(
    name,
    builder: (data) {
      return _i30.DeferredWidget(
        _i24.loadLibrary,
        () => _i30.WrappedRoute(child: _i24.NewsScreen()),
      );
    },
  );
}

/// generated route for
/// [_i25.SettingsScreen]
class SettingsRoute extends _i30.PageRouteInfo<void> {
  const SettingsRoute({List<_i30.PageRouteInfo>? children})
    : super(SettingsRoute.name, initialChildren: children);

  static const String name = 'SettingsRoute';

  static _i30.PageInfo page = _i30.PageInfo(
    name,
    builder: (data) {
      return _i30.DeferredWidget(_i25.loadLibrary, () => _i25.SettingsScreen());
    },
  );
}

/// generated route for
/// [_i26.TrimmerScreen]
class TrimmerRoute extends _i30.PageRouteInfo<TrimmerRouteArgs> {
  TrimmerRoute({
    required _i38.File file,
    _i31.Key? key,
    List<_i30.PageRouteInfo>? children,
  }) : super(
         TrimmerRoute.name,
         args: TrimmerRouteArgs(file: file, key: key),
         initialChildren: children,
       );

  static const String name = 'TrimmerRoute';

  static _i30.PageInfo page = _i30.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<TrimmerRouteArgs>();
      return _i30.DeferredWidget(
        _i26.loadLibrary,
        () => _i26.TrimmerScreen(args.file, key: args.key),
      );
    },
  );
}

class TrimmerRouteArgs {
  const TrimmerRouteArgs({required this.file, this.key});

  final _i38.File file;

  final _i31.Key? key;

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

/// generated route for
/// [_i27.UpdatePasswordScreen]
class UpdatePasswordRoute extends _i30.PageRouteInfo<UpdatePasswordRouteArgs> {
  UpdatePasswordRoute({
    _i31.Key? key,
    bool isRecovery = false,
    List<_i30.PageRouteInfo>? children,
  }) : super(
         UpdatePasswordRoute.name,
         args: UpdatePasswordRouteArgs(key: key, isRecovery: isRecovery),
         initialChildren: children,
       );

  static const String name = 'UpdatePasswordRoute';

  static _i30.PageInfo page = _i30.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<UpdatePasswordRouteArgs>(
        orElse: () => const UpdatePasswordRouteArgs(),
      );
      return _i30.DeferredWidget(
        _i27.loadLibrary,
        () => _i30.WrappedRoute(
          child: _i27.UpdatePasswordScreen(
            key: args.key,
            isRecovery: args.isRecovery,
          ),
        ),
      );
    },
  );
}

class UpdatePasswordRouteArgs {
  const UpdatePasswordRouteArgs({this.key, this.isRecovery = false});

  final _i31.Key? key;

  final bool isRecovery;

  @override
  String toString() {
    return 'UpdatePasswordRouteArgs{key: $key, isRecovery: $isRecovery}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! UpdatePasswordRouteArgs) return false;
    return key == other.key && isRecovery == other.isRecovery;
  }

  @override
  int get hashCode => key.hashCode ^ isRecovery.hashCode;
}

/// generated route for
/// [_i28.VerifyOtpScreen]
class VerifyOtpRoute extends _i30.PageRouteInfo<VerifyOtpRouteArgs> {
  VerifyOtpRoute({
    _i31.Key? key,
    required String email,
    required _i39.OtpPurpose purpose,
    List<_i30.PageRouteInfo>? children,
  }) : super(
         VerifyOtpRoute.name,
         args: VerifyOtpRouteArgs(key: key, email: email, purpose: purpose),
         initialChildren: children,
       );

  static const String name = 'VerifyOtpRoute';

  static _i30.PageInfo page = _i30.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<VerifyOtpRouteArgs>();
      return _i30.DeferredWidget(
        _i28.loadLibrary,
        () => _i30.WrappedRoute(
          child: _i28.VerifyOtpScreen(
            key: args.key,
            email: args.email,
            purpose: args.purpose,
          ),
        ),
      );
    },
  );
}

class VerifyOtpRouteArgs {
  const VerifyOtpRouteArgs({
    this.key,
    required this.email,
    required this.purpose,
  });

  final _i31.Key? key;

  final String email;

  final _i39.OtpPurpose purpose;

  @override
  String toString() {
    return 'VerifyOtpRouteArgs{key: $key, email: $email, purpose: $purpose}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! VerifyOtpRouteArgs) return false;
    return key == other.key && email == other.email && purpose == other.purpose;
  }

  @override
  int get hashCode => key.hashCode ^ email.hashCode ^ purpose.hashCode;
}

/// generated route for
/// [_i29.WifiManagementScreen]
class WifiManagementRoute extends _i30.PageRouteInfo<void> {
  const WifiManagementRoute({List<_i30.PageRouteInfo>? children})
    : super(WifiManagementRoute.name, initialChildren: children);

  static const String name = 'WifiManagementRoute';

  static _i30.PageInfo page = _i30.PageInfo(
    name,
    builder: (data) {
      return _i30.DeferredWidget(
        _i29.loadLibrary,
        () => _i30.WrappedRoute(child: _i29.WifiManagementScreen()),
      );
    },
  );
}
