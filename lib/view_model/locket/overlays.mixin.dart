import 'package:dio/dio.dart';
import 'package:do_x/constants/enum/overlay_type.dart';
import 'package:do_x/model/weather_data.dart';
import 'package:do_x/services/location_service.dart';
import 'package:do_x/services/weather_service.dart';
import 'package:do_x/utils/logger.dart';
import 'package:do_x/view_model/core/core_view_model.dart';
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
}
