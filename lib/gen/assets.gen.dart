// dart format width=80

/// GENERATED CODE - DO NOT MODIFY BY HAND
/// *****************************************************
///  FlutterGen
/// *****************************************************

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: deprecated_member_use,directives_ordering,implicit_dynamic_list_literal,unnecessary_import

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart' as _svg;
import 'package:vector_graphics/vector_graphics.dart' as _vg;

class $AssetsAnimationGen {
  const $AssetsAnimationGen();

  /// File path: assets/animation/loading.json
  String get loading => 'assets/animation/loading.json';

  /// List of all assets
  List<String> get values => [loading];
}

class $AssetsImagesGen {
  const $AssetsImagesGen();

  /// File path: assets/images/app_icon.png
  AssetGenImage get appIcon =>
      const AssetGenImage('assets/images/app_icon.png');

  /// File path: assets/images/bnb.png
  AssetGenImage get bnb => const AssetGenImage('assets/images/bnb.png');

  /// File path: assets/images/btc.png
  AssetGenImage get btc => const AssetGenImage('assets/images/btc.png');

  /// File path: assets/images/chick_cute.svg
  SvgGenImage get chickCute =>
      const SvgGenImage('assets/images/chick_cute.svg');

  /// File path: assets/images/chicken.svg
  SvgGenImage get chicken => const SvgGenImage('assets/images/chicken.svg');

  /// File path: assets/images/coin_cute.svg
  SvgGenImage get coinCute => const SvgGenImage('assets/images/coin_cute.svg');

  /// File path: assets/images/drumstick_cute.svg
  SvgGenImage get drumstickCute =>
      const SvgGenImage('assets/images/drumstick_cute.svg');

  /// File path: assets/images/egg_cute.svg
  SvgGenImage get eggCute => const SvgGenImage('assets/images/egg_cute.svg');

  /// File path: assets/images/eth.png
  AssetGenImage get eth => const AssetGenImage('assets/images/eth.png');

  /// File path: assets/images/feed_cute.svg
  SvgGenImage get feedCute => const SvgGenImage('assets/images/feed_cute.svg');

  /// File path: assets/images/gold.png
  AssetGenImage get gold => const AssetGenImage('assets/images/gold.png');

  /// File path: assets/images/heart_cute.svg
  SvgGenImage get heartCute =>
      const SvgGenImage('assets/images/heart_cute.svg');

  /// File path: assets/images/hen_cute.svg
  SvgGenImage get henCute => const SvgGenImage('assets/images/hen_cute.svg');

  /// File path: assets/images/lamp_cute.svg
  SvgGenImage get lampCute => const SvgGenImage('assets/images/lamp_cute.svg');

  /// File path: assets/images/medicine_cute.svg
  SvgGenImage get medicineCute =>
      const SvgGenImage('assets/images/medicine_cute.svg');

  /// File path: assets/images/menu_cute.svg
  SvgGenImage get menuCute => const SvgGenImage('assets/images/menu_cute.svg');

  /// File path: assets/images/news_cute.svg
  SvgGenImage get newsCute => const SvgGenImage('assets/images/news_cute.svg');

  /// File path: assets/images/rooster.svg
  SvgGenImage get rooster => const SvgGenImage('assets/images/rooster.svg');

  /// File path: assets/images/rooster_cute.svg
  SvgGenImage get roosterCute =>
      const SvgGenImage('assets/images/rooster_cute.svg');

  /// File path: assets/images/silver.png
  AssetGenImage get silver => const AssetGenImage('assets/images/silver.png');

  /// File path: assets/images/star_cute.svg
  SvgGenImage get starCute => const SvgGenImage('assets/images/star_cute.svg');

  /// File path: assets/images/water_cute.svg
  SvgGenImage get waterCute =>
      const SvgGenImage('assets/images/water_cute.svg');

  /// List of all assets
  List<dynamic> get values => [
    appIcon,
    bnb,
    btc,
    chickCute,
    chicken,
    coinCute,
    drumstickCute,
    eggCute,
    eth,
    feedCute,
    gold,
    heartCute,
    henCute,
    lampCute,
    medicineCute,
    menuCute,
    newsCute,
    rooster,
    roosterCute,
    silver,
    starCute,
    waterCute,
  ];
}

class Assets {
  const Assets._();

  static const $AssetsAnimationGen animation = $AssetsAnimationGen();
  static const $AssetsImagesGen images = $AssetsImagesGen();
}

class AssetGenImage {
  const AssetGenImage(
    this._assetName, {
    this.size,
    this.flavors = const {},
    this.animation,
  });

  final String _assetName;

  final Size? size;
  final Set<String> flavors;
  final AssetGenImageAnimation? animation;

  Image image({
    Key? key,
    AssetBundle? bundle,
    ImageFrameBuilder? frameBuilder,
    ImageErrorWidgetBuilder? errorBuilder,
    String? semanticLabel,
    bool excludeFromSemantics = false,
    double? scale,
    double? width,
    double? height,
    Color? color,
    Animation<double>? opacity,
    BlendMode? colorBlendMode,
    BoxFit? fit,
    AlignmentGeometry alignment = Alignment.center,
    ImageRepeat repeat = ImageRepeat.noRepeat,
    Rect? centerSlice,
    bool matchTextDirection = false,
    bool gaplessPlayback = true,
    bool isAntiAlias = false,
    String? package,
    FilterQuality filterQuality = FilterQuality.medium,
    int? cacheWidth,
    int? cacheHeight,
  }) {
    return Image.asset(
      _assetName,
      key: key,
      bundle: bundle,
      frameBuilder: frameBuilder,
      errorBuilder: errorBuilder,
      semanticLabel: semanticLabel,
      excludeFromSemantics: excludeFromSemantics,
      scale: scale,
      width: width,
      height: height,
      color: color,
      opacity: opacity,
      colorBlendMode: colorBlendMode,
      fit: fit,
      alignment: alignment,
      repeat: repeat,
      centerSlice: centerSlice,
      matchTextDirection: matchTextDirection,
      gaplessPlayback: gaplessPlayback,
      isAntiAlias: isAntiAlias,
      package: package,
      filterQuality: filterQuality,
      cacheWidth: cacheWidth,
      cacheHeight: cacheHeight,
    );
  }

  ImageProvider provider({AssetBundle? bundle, String? package}) {
    return AssetImage(_assetName, bundle: bundle, package: package);
  }

  String get path => _assetName;

  String get keyName => _assetName;
}

class AssetGenImageAnimation {
  const AssetGenImageAnimation({
    required this.isAnimation,
    required this.duration,
    required this.frames,
  });

  final bool isAnimation;
  final Duration duration;
  final int frames;
}

class SvgGenImage {
  const SvgGenImage(this._assetName, {this.size, this.flavors = const {}})
    : _isVecFormat = false;

  const SvgGenImage.vec(this._assetName, {this.size, this.flavors = const {}})
    : _isVecFormat = true;

  final String _assetName;
  final Size? size;
  final Set<String> flavors;
  final bool _isVecFormat;

  _svg.SvgPicture svg({
    Key? key,
    bool matchTextDirection = false,
    AssetBundle? bundle,
    String? package,
    double? width,
    double? height,
    BoxFit fit = BoxFit.contain,
    AlignmentGeometry alignment = Alignment.center,
    bool allowDrawingOutsideViewBox = false,
    WidgetBuilder? placeholderBuilder,
    String? semanticsLabel,
    bool excludeFromSemantics = false,
    _svg.SvgTheme? theme,
    _svg.ColorMapper? colorMapper,
    ColorFilter? colorFilter,
    Clip clipBehavior = Clip.hardEdge,
    @deprecated Color? color,
    @deprecated BlendMode colorBlendMode = BlendMode.srcIn,
    @deprecated bool cacheColorFilter = false,
  }) {
    final _svg.BytesLoader loader;
    if (_isVecFormat) {
      loader = _vg.AssetBytesLoader(
        _assetName,
        assetBundle: bundle,
        packageName: package,
      );
    } else {
      loader = _svg.SvgAssetLoader(
        _assetName,
        assetBundle: bundle,
        packageName: package,
        theme: theme,
        colorMapper: colorMapper,
      );
    }
    return _svg.SvgPicture(
      loader,
      key: key,
      matchTextDirection: matchTextDirection,
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
      allowDrawingOutsideViewBox: allowDrawingOutsideViewBox,
      placeholderBuilder: placeholderBuilder,
      semanticsLabel: semanticsLabel,
      excludeFromSemantics: excludeFromSemantics,
      colorFilter:
          colorFilter ??
          (color == null ? null : ColorFilter.mode(color, colorBlendMode)),
      clipBehavior: clipBehavior,
      cacheColorFilter: cacheColorFilter,
    );
  }

  String get path => _assetName;

  String get keyName => _assetName;
}
