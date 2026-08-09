// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AutoRouterGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:io' as _i33;

import 'package:auto_route/auto_route.dart' as _i27;
import 'package:do_x/constants/enum/market_code.dart' as _i30;
import 'package:do_x/model/movie_model.dart' as _i32;
import 'package:do_x/screen/account/app_account_screen.dart' as _i2;
import 'package:do_x/screen/account/app_login_screen.dart' as _i3;
import 'package:do_x/screen/account/update_password_screen.dart' as _i24;
import 'package:do_x/screen/account/verify_otp_screen.dart' as _i25;
import 'package:do_x/screen/chicken/chicken_batch_detail_screen.dart' as _i4;
import 'package:do_x/screen/chicken/chicken_screen.dart' as _i5;
import 'package:do_x/screen/chicken/chicken_settings_screen.dart' as _i6;
import 'package:do_x/screen/chicken/chicken_statistics_screen.dart' as _i7;
import 'package:do_x/screen/chicken/cock_sales_screen.dart' as _i8;
import 'package:do_x/screen/chicken/global_expenses_screen.dart' as _i12;
import 'package:do_x/screen/electric_screen.dart' as _i9;
import 'package:do_x/screen/electric_settings_screen.dart' as _i10;
import 'package:do_x/screen/feng_shui_compass_screen.dart' as _i11;
import 'package:do_x/screen/lunar_screen.dart' as _i14;
import 'package:do_x/screen/main_screen.dart' as _i15;
import 'package:do_x/screen/menu_screen.dart' as _i17;
import 'package:do_x/screen/movie/movie_detail_screen.dart' as _i18;
import 'package:do_x/screen/movie/movie_screen.dart' as _i19;
import 'package:do_x/screen/my_life/account_screen.dart' as _i1;
import 'package:do_x/screen/my_life/login_screen.dart' as _i13;
import 'package:do_x/screen/my_life/my_life_screen.dart' as _i20;
import 'package:do_x/screen/my_life/trimmer_screen.dart' as _i23;
import 'package:do_x/screen/network/wifi_management_screen.dart' as _i26;
import 'package:do_x/screen/news/market_detail_screen.dart' as _i16;
import 'package:do_x/screen/news/news_screen.dart' as _i21;
import 'package:do_x/screen/settings_screen.dart' as _i22;
import 'package:do_x/view_model/electric_view_model.dart' as _i29;
import 'package:do_x/view_model/verify_otp_view_model.dart' as _i34;
import 'package:flutter/foundation.dart' as _i31;
import 'package:flutter/material.dart' as _i28;

/// generated route for
/// [_i1.AccountScreen]
class AccountRoute extends _i27.PageRouteInfo<void> {
  const AccountRoute({List<_i27.PageRouteInfo>? children})
    : super(AccountRoute.name, initialChildren: children);

  static const String name = 'AccountRoute';

  static _i27.PageInfo page = _i27.PageInfo(
    name,
    builder: (data) {
      return _i27.WrappedRoute(child: const _i1.AccountScreen());
    },
  );
}

/// generated route for
/// [_i2.AppAccountScreen]
class AppAccountRoute extends _i27.PageRouteInfo<void> {
  const AppAccountRoute({List<_i27.PageRouteInfo>? children})
    : super(AppAccountRoute.name, initialChildren: children);

  static const String name = 'AppAccountRoute';

  static _i27.PageInfo page = _i27.PageInfo(
    name,
    builder: (data) {
      return _i27.WrappedRoute(child: const _i2.AppAccountScreen());
    },
  );
}

/// generated route for
/// [_i3.AppLoginScreen]
class AppLoginRoute extends _i27.PageRouteInfo<void> {
  const AppLoginRoute({List<_i27.PageRouteInfo>? children})
    : super(AppLoginRoute.name, initialChildren: children);

  static const String name = 'AppLoginRoute';

  static _i27.PageInfo page = _i27.PageInfo(
    name,
    builder: (data) {
      return _i27.WrappedRoute(child: const _i3.AppLoginScreen());
    },
  );
}

/// generated route for
/// [_i4.ChickenBatchDetailScreen]
class ChickenBatchDetailRoute
    extends _i27.PageRouteInfo<ChickenBatchDetailRouteArgs> {
  ChickenBatchDetailRoute({
    _i28.Key? key,
    required String batchId,
    List<_i27.PageRouteInfo>? children,
  }) : super(
         ChickenBatchDetailRoute.name,
         args: ChickenBatchDetailRouteArgs(key: key, batchId: batchId),
         initialChildren: children,
       );

  static const String name = 'ChickenBatchDetailRoute';

  static _i27.PageInfo page = _i27.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<ChickenBatchDetailRouteArgs>();
      return _i27.WrappedRoute(
        child: _i4.ChickenBatchDetailScreen(
          key: args.key,
          batchId: args.batchId,
        ),
      );
    },
  );
}

class ChickenBatchDetailRouteArgs {
  const ChickenBatchDetailRouteArgs({this.key, required this.batchId});

  final _i28.Key? key;

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
/// [_i5.ChickenScreen]
class ChickenRoute extends _i27.PageRouteInfo<void> {
  const ChickenRoute({List<_i27.PageRouteInfo>? children})
    : super(ChickenRoute.name, initialChildren: children);

  static const String name = 'ChickenRoute';

  static _i27.PageInfo page = _i27.PageInfo(
    name,
    builder: (data) {
      return _i27.WrappedRoute(child: const _i5.ChickenScreen());
    },
  );
}

/// generated route for
/// [_i6.ChickenSettingsScreen]
class ChickenSettingsRoute extends _i27.PageRouteInfo<void> {
  const ChickenSettingsRoute({List<_i27.PageRouteInfo>? children})
    : super(ChickenSettingsRoute.name, initialChildren: children);

  static const String name = 'ChickenSettingsRoute';

  static _i27.PageInfo page = _i27.PageInfo(
    name,
    builder: (data) {
      return _i27.WrappedRoute(child: const _i6.ChickenSettingsScreen());
    },
  );
}

/// generated route for
/// [_i7.ChickenStatisticsScreen]
class ChickenStatisticsRoute extends _i27.PageRouteInfo<void> {
  const ChickenStatisticsRoute({List<_i27.PageRouteInfo>? children})
    : super(ChickenStatisticsRoute.name, initialChildren: children);

  static const String name = 'ChickenStatisticsRoute';

  static _i27.PageInfo page = _i27.PageInfo(
    name,
    builder: (data) {
      return _i27.WrappedRoute(child: const _i7.ChickenStatisticsScreen());
    },
  );
}

/// generated route for
/// [_i8.CockSalesScreen]
class CockSalesRoute extends _i27.PageRouteInfo<void> {
  const CockSalesRoute({List<_i27.PageRouteInfo>? children})
    : super(CockSalesRoute.name, initialChildren: children);

  static const String name = 'CockSalesRoute';

  static _i27.PageInfo page = _i27.PageInfo(
    name,
    builder: (data) {
      return _i27.WrappedRoute(child: const _i8.CockSalesScreen());
    },
  );
}

/// generated route for
/// [_i9.ElectricScreen]
class ElectricRoute extends _i27.PageRouteInfo<void> {
  const ElectricRoute({List<_i27.PageRouteInfo>? children})
    : super(ElectricRoute.name, initialChildren: children);

  static const String name = 'ElectricRoute';

  static _i27.PageInfo page = _i27.PageInfo(
    name,
    builder: (data) {
      return _i27.WrappedRoute(child: const _i9.ElectricScreen());
    },
  );
}

/// generated route for
/// [_i10.ElectricSettingsScreen]
class ElectricSettingsRoute
    extends _i27.PageRouteInfo<ElectricSettingsRouteArgs> {
  ElectricSettingsRoute({
    _i28.Key? key,
    required _i29.ElectricViewModel electricVm,
    List<_i27.PageRouteInfo>? children,
  }) : super(
         ElectricSettingsRoute.name,
         args: ElectricSettingsRouteArgs(key: key, electricVm: electricVm),
         initialChildren: children,
       );

  static const String name = 'ElectricSettingsRoute';

  static _i27.PageInfo page = _i27.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<ElectricSettingsRouteArgs>();
      return _i27.WrappedRoute(
        child: _i10.ElectricSettingsScreen(
          key: args.key,
          electricVm: args.electricVm,
        ),
      );
    },
  );
}

class ElectricSettingsRouteArgs {
  const ElectricSettingsRouteArgs({this.key, required this.electricVm});

  final _i28.Key? key;

  final _i29.ElectricViewModel electricVm;

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
/// [_i11.FengShuiCompassScreen]
class FengShuiCompassRoute extends _i27.PageRouteInfo<void> {
  const FengShuiCompassRoute({List<_i27.PageRouteInfo>? children})
    : super(FengShuiCompassRoute.name, initialChildren: children);

  static const String name = 'FengShuiCompassRoute';

  static _i27.PageInfo page = _i27.PageInfo(
    name,
    builder: (data) {
      return const _i11.FengShuiCompassScreen();
    },
  );
}

/// generated route for
/// [_i12.GlobalExpensesScreen]
class GlobalExpensesRoute extends _i27.PageRouteInfo<void> {
  const GlobalExpensesRoute({List<_i27.PageRouteInfo>? children})
    : super(GlobalExpensesRoute.name, initialChildren: children);

  static const String name = 'GlobalExpensesRoute';

  static _i27.PageInfo page = _i27.PageInfo(
    name,
    builder: (data) {
      return _i27.WrappedRoute(child: const _i12.GlobalExpensesScreen());
    },
  );
}

/// generated route for
/// [_i13.LoginScreen]
class LoginRoute extends _i27.PageRouteInfo<void> {
  const LoginRoute({List<_i27.PageRouteInfo>? children})
    : super(LoginRoute.name, initialChildren: children);

  static const String name = 'LoginRoute';

  static _i27.PageInfo page = _i27.PageInfo(
    name,
    builder: (data) {
      return _i27.WrappedRoute(child: const _i13.LoginScreen());
    },
  );
}

/// generated route for
/// [_i14.LunarScreen]
class LunarRoute extends _i27.PageRouteInfo<void> {
  const LunarRoute({List<_i27.PageRouteInfo>? children})
    : super(LunarRoute.name, initialChildren: children);

  static const String name = 'LunarRoute';

  static _i27.PageInfo page = _i27.PageInfo(
    name,
    builder: (data) {
      return const _i14.LunarScreen();
    },
  );
}

/// generated route for
/// [_i15.MainScreen]
class MainRoute extends _i27.PageRouteInfo<void> {
  const MainRoute({List<_i27.PageRouteInfo>? children})
    : super(MainRoute.name, initialChildren: children);

  static const String name = 'MainRoute';

  static _i27.PageInfo page = _i27.PageInfo(
    name,
    builder: (data) {
      return _i27.WrappedRoute(child: const _i15.MainScreen());
    },
  );
}

/// generated route for
/// [_i16.MarketDetailScreen]
class MarketDetailRoute extends _i27.PageRouteInfo<MarketDetailRouteArgs> {
  MarketDetailRoute({
    _i28.Key? key,
    required _i30.MarketCode code,
    List<_i27.PageRouteInfo>? children,
  }) : super(
         MarketDetailRoute.name,
         args: MarketDetailRouteArgs(key: key, code: code),
         initialChildren: children,
       );

  static const String name = 'MarketDetailRoute';

  static _i27.PageInfo page = _i27.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<MarketDetailRouteArgs>();
      return _i27.WrappedRoute(
        child: _i16.MarketDetailScreen(key: args.key, code: args.code),
      );
    },
  );
}

class MarketDetailRouteArgs {
  const MarketDetailRouteArgs({this.key, required this.code});

  final _i28.Key? key;

  final _i30.MarketCode code;

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
/// [_i17.MenuScreen]
class MenuRoute extends _i27.PageRouteInfo<void> {
  const MenuRoute({List<_i27.PageRouteInfo>? children})
    : super(MenuRoute.name, initialChildren: children);

  static const String name = 'MenuRoute';

  static _i27.PageInfo page = _i27.PageInfo(
    name,
    builder: (data) {
      return _i27.WrappedRoute(child: const _i17.MenuScreen());
    },
  );
}

/// generated route for
/// [_i18.MovieDetailScreen]
class MovieDetailRoute extends _i27.PageRouteInfo<MovieDetailRouteArgs> {
  MovieDetailRoute({
    _i31.Key? key,
    required String movieUrl,
    required String movieId,
    _i32.Movie? initialMovie,
    bool embedded = false,
    double minimizeProgress = 1,
    _i31.ValueChanged<bool>? onFullScreenChanged,
    _i18.MovieDetailController? controller,
    _i31.ValueChanged<_i32.Movie>? onRelatedMovieTap,
    _i31.VoidCallback? onClose,
    _i31.VoidCallback? onMinimize,
    _i28.GestureDragStartCallback? onPlayerDragStart,
    _i28.GestureDragUpdateCallback? onPlayerDragUpdate,
    _i28.GestureDragEndCallback? onPlayerDragEnd,
    List<_i27.PageRouteInfo>? children,
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

  static _i27.PageInfo page = _i27.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<MovieDetailRouteArgs>();
      return _i18.MovieDetailScreen(
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

  final _i31.Key? key;

  final String movieUrl;

  final String movieId;

  final _i32.Movie? initialMovie;

  final bool embedded;

  final double minimizeProgress;

  final _i31.ValueChanged<bool>? onFullScreenChanged;

  final _i18.MovieDetailController? controller;

  final _i31.ValueChanged<_i32.Movie>? onRelatedMovieTap;

  final _i31.VoidCallback? onClose;

  final _i31.VoidCallback? onMinimize;

  final _i28.GestureDragStartCallback? onPlayerDragStart;

  final _i28.GestureDragUpdateCallback? onPlayerDragUpdate;

  final _i28.GestureDragEndCallback? onPlayerDragEnd;

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
/// [_i19.MovieScreen]
class MovieRoute extends _i27.PageRouteInfo<void> {
  const MovieRoute({List<_i27.PageRouteInfo>? children})
    : super(MovieRoute.name, initialChildren: children);

  static const String name = 'MovieRoute';

  static _i27.PageInfo page = _i27.PageInfo(
    name,
    builder: (data) {
      return const _i19.MovieScreen();
    },
  );
}

/// generated route for
/// [_i20.MyLifeScreen]
class MyLifeRoute extends _i27.PageRouteInfo<void> {
  const MyLifeRoute({List<_i27.PageRouteInfo>? children})
    : super(MyLifeRoute.name, initialChildren: children);

  static const String name = 'MyLifeRoute';

  static _i27.PageInfo page = _i27.PageInfo(
    name,
    builder: (data) {
      return _i27.WrappedRoute(child: const _i20.MyLifeScreen());
    },
  );
}

/// generated route for
/// [_i21.NewsScreen]
class NewsRoute extends _i27.PageRouteInfo<void> {
  const NewsRoute({List<_i27.PageRouteInfo>? children})
    : super(NewsRoute.name, initialChildren: children);

  static const String name = 'NewsRoute';

  static _i27.PageInfo page = _i27.PageInfo(
    name,
    builder: (data) {
      return _i27.WrappedRoute(child: const _i21.NewsScreen());
    },
  );
}

/// generated route for
/// [_i22.SettingsScreen]
class SettingsRoute extends _i27.PageRouteInfo<void> {
  const SettingsRoute({List<_i27.PageRouteInfo>? children})
    : super(SettingsRoute.name, initialChildren: children);

  static const String name = 'SettingsRoute';

  static _i27.PageInfo page = _i27.PageInfo(
    name,
    builder: (data) {
      return const _i22.SettingsScreen();
    },
  );
}

/// generated route for
/// [_i23.TrimmerScreen]
class TrimmerRoute extends _i27.PageRouteInfo<TrimmerRouteArgs> {
  TrimmerRoute({
    required _i33.File file,
    _i28.Key? key,
    List<_i27.PageRouteInfo>? children,
  }) : super(
         TrimmerRoute.name,
         args: TrimmerRouteArgs(file: file, key: key),
         initialChildren: children,
       );

  static const String name = 'TrimmerRoute';

  static _i27.PageInfo page = _i27.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<TrimmerRouteArgs>();
      return _i23.TrimmerScreen(args.file, key: args.key);
    },
  );
}

class TrimmerRouteArgs {
  const TrimmerRouteArgs({required this.file, this.key});

  final _i33.File file;

  final _i28.Key? key;

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
/// [_i24.UpdatePasswordScreen]
class UpdatePasswordRoute extends _i27.PageRouteInfo<UpdatePasswordRouteArgs> {
  UpdatePasswordRoute({
    _i28.Key? key,
    bool isRecovery = false,
    List<_i27.PageRouteInfo>? children,
  }) : super(
         UpdatePasswordRoute.name,
         args: UpdatePasswordRouteArgs(key: key, isRecovery: isRecovery),
         initialChildren: children,
       );

  static const String name = 'UpdatePasswordRoute';

  static _i27.PageInfo page = _i27.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<UpdatePasswordRouteArgs>(
        orElse: () => const UpdatePasswordRouteArgs(),
      );
      return _i27.WrappedRoute(
        child: _i24.UpdatePasswordScreen(
          key: args.key,
          isRecovery: args.isRecovery,
        ),
      );
    },
  );
}

class UpdatePasswordRouteArgs {
  const UpdatePasswordRouteArgs({this.key, this.isRecovery = false});

  final _i28.Key? key;

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
/// [_i25.VerifyOtpScreen]
class VerifyOtpRoute extends _i27.PageRouteInfo<VerifyOtpRouteArgs> {
  VerifyOtpRoute({
    _i28.Key? key,
    required String email,
    required _i34.OtpPurpose purpose,
    List<_i27.PageRouteInfo>? children,
  }) : super(
         VerifyOtpRoute.name,
         args: VerifyOtpRouteArgs(key: key, email: email, purpose: purpose),
         initialChildren: children,
       );

  static const String name = 'VerifyOtpRoute';

  static _i27.PageInfo page = _i27.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<VerifyOtpRouteArgs>();
      return _i27.WrappedRoute(
        child: _i25.VerifyOtpScreen(
          key: args.key,
          email: args.email,
          purpose: args.purpose,
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

  final _i28.Key? key;

  final String email;

  final _i34.OtpPurpose purpose;

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
/// [_i26.WifiManagementScreen]
class WifiManagementRoute extends _i27.PageRouteInfo<void> {
  const WifiManagementRoute({List<_i27.PageRouteInfo>? children})
    : super(WifiManagementRoute.name, initialChildren: children);

  static const String name = 'WifiManagementRoute';

  static _i27.PageInfo page = _i27.PageInfo(
    name,
    builder: (data) {
      return _i27.WrappedRoute(child: const _i26.WifiManagementScreen());
    },
  );
}
