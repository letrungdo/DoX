import 'package:dio/dio.dart';
import 'package:do_x/constants/enum/overlay_type.dart';
import 'package:do_x/extensions/color_extensions.dart';
import 'package:do_x/model/weather_data.dart';
import 'package:do_x/services/location_service.dart';
import 'package:do_x/services/weather_service.dart';
import 'package:do_x/utils/logger.dart';
import 'package:do_x/view_model/core/core_view_model.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

mixin LocketOverlays on CoreViewModel {
  LocationService get _locationService => context.read<LocationService>();
  WeatherService get _weatherService => context.read<WeatherService>();

  String? _currentLocation;
  String? get currentLocation => _currentLocation;

  CurrentWeather? _weatherData;
  CurrentWeather? get weatherData => _weatherData;

  CancelToken? _cancelTokenWeather;

  String? _reviewCaption;
  String get reviewCaption => _reviewCaption ?? "";
  double _reviewRating = 0;
  double get reviewRating => _reviewRating;

  String? _caption;
  String get caption => _caption ?? "";

  DateTime? _currentTime;
  DateTime? get currentTime => _currentTime;

  int _overlayIndex = 0;
  int get overlayIndex => _overlayIndex;

  Color overlayTextColor = Colors.white.withAlpha(230).getTextColor()!;
  Color? overlayBgColor;

  void setOverlayIndex(int index) async {
    _overlayIndex = index;
    switch (OverlayType.values[index]) {
      case OverlayType.time:
        _currentTime = DateTime.now();
        break;
      case OverlayType.location:
        _getLocation();
        break;
      case OverlayType.weather:
        _getWeather();
        break;
      default:
        break;
    }
    notifyListenersSafe();
  }

  void onCaptionChanged(String value) {
    _caption = value;
    notifyListenersSafe();
  }

  void setReviewRating(double rating) {
    _reviewRating = rating;
    notifyListenersSafe();
  }

  void onReviewCaptionChanged(String value) {
    _reviewCaption = value;
    notifyListenersSafe();
  }

  void clearOverlayInput() {
    _reviewCaption = null;
    _reviewRating = 0;
    _caption = null;
  }

  void _getLocation() async {
    try {
      final position = await _locationService.getCurrentPosition();
      if (position == null) throw "can't get position";
      _currentLocation = await _locationService.getLocationName(position);
      notifyListenersSafe();
    } catch (e) {
      logger.e(e.toString());
    }
  }

  void _getWeather() async {
    _cancelTokenWeather?.cancel();
    _cancelTokenWeather = CancelToken();
    final position = await _locationService.getCurrentPosition();
    final result = await _weatherService.getCurrentWeather(
      latitude: position?.latitude, //
      longitude: position?.longitude,
      timezone: await _locationService.getCurrentTimeZone(),
      cancelToken: _cancelTokenWeather,
    );
    if (result.isError) {
      showAppError(
        // ignore: use_build_context_synchronously
        context,
        result.error,
        onRetry: () => _getWeather(),
      );
    }
    _weatherData = result.data?.current;
    notifyListenersSafe();
  }

  // Define custom colors. The 'guide' color values are from
  // https://material.io/design/color/the-color-system.html#color-theme-creation
  static const Color guidePrimary = Color(0xFF6200EE);
  static const Color guidePrimaryVariant = Color(0xFF3700B3);
  static const Color guideSecondary = Color(0xFF03DAC6);
  static const Color guideSecondaryVariant = Color(0xFF018786);
  static const Color guideError = Color(0xFFB00020);
  static const Color guideErrorDark = Color(0xFFCF6679);
  static const Color blueBlues = Color(0xFF174378);

  // Make a custom ColorSwatch to name map from the above custom colors.
  final Map<ColorSwatch<Object>, String> colorsNameMap = <ColorSwatch<Object>, String>{
    ColorTools.createPrimarySwatch(guidePrimary): 'Guide Purple',
    ColorTools.createPrimarySwatch(guidePrimaryVariant): 'Guide Purple Variant',
    ColorTools.createAccentSwatch(guideSecondary): 'Guide Teal',
    ColorTools.createAccentSwatch(guideSecondaryVariant): 'Guide Teal Variant',
    ColorTools.createPrimarySwatch(guideError): 'Guide Error',
    ColorTools.createPrimarySwatch(guideErrorDark): 'Guide Error Dark',
    ColorTools.createPrimarySwatch(blueBlues): 'Blue blues',
  };

  Future<bool> colorPickerDialog() async {
    return ColorPicker(
      color: overlayBgColor ?? Colors.pink,
      onColorChanged: (Color color) {
        overlayBgColor = color;
        overlayTextColor = color.getTextColor()!;
        notifyListeners();
      },
      width: 40,
      height: 40,
      borderRadius: 4,
      spacing: 5,
      runSpacing: 5,
      wheelDiameter: 155,
      heading: Text('Select color', style: Theme.of(context).textTheme.titleSmall),
      subheading: Text('Select color shade', style: Theme.of(context).textTheme.titleSmall),
      wheelSubheading: Text('Selected color and its shades', style: Theme.of(context).textTheme.titleSmall),
      copyPasteBehavior: const ColorPickerCopyPasteBehavior(longPressMenu: true),
      materialNameTextStyle: Theme.of(context).textTheme.bodySmall,
      colorNameTextStyle: Theme.of(context).textTheme.bodySmall,
      colorCodeTextStyle: Theme.of(context).textTheme.bodySmall,
      pickersEnabled: const <ColorPickerType, bool>{
        ColorPickerType.both: false,
        ColorPickerType.primary: true,
        ColorPickerType.accent: true,
        ColorPickerType.bw: false,
        ColorPickerType.custom: true,
        ColorPickerType.wheel: true,
      },
      customColorSwatchesAndNames: colorsNameMap,
    ).showPickerDialog(
      context,
      transitionBuilder: (BuildContext context, Animation<double> a1, Animation<double> a2, Widget widget) {
        return FadeTransition(opacity: a1, child: widget);
      },
      transitionDuration: const Duration(milliseconds: 150),
      constraints: const BoxConstraints(minHeight: 460, minWidth: 300, maxWidth: 320),
    );
  }
}
