import 'package:flutter/foundation.dart';

enum OverlayType {
  standard("standard"),
  review("review"),
  // music("music"),
  location("location"),
  weather("weather"),
  time("time");

  const OverlayType(this.value);

  final String value;

  static List<OverlayType> get options =>
      kIsWeb
          ? [
            OverlayType.standard, //
            OverlayType.review,
            OverlayType.weather,
            OverlayType.time,
          ]
          : OverlayType.values;
}
