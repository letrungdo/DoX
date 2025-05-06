import 'package:json_annotation/json_annotation.dart';

part 'weather_data.g.dart';

@JsonSerializable(explicitToJson: true)
class WeatherData {
  final double? latitude;
  final double? longitude;
  final double? generationtimeMs;
  final int? utcOffsetSeconds;
  final String? timezone;
  final String? timezoneAbbreviation;
  final double? elevation;
  final CurrentWeather? current;

  const WeatherData({
    required this.latitude,
    required this.longitude,
    required this.generationtimeMs,
    required this.utcOffsetSeconds,
    required this.timezone,
    required this.timezoneAbbreviation,
    required this.elevation,
    required this.current,
  });

  factory WeatherData.fromJson(Map<String, dynamic> json) => _$WeatherDataFromJson(json);

  Map<String, dynamic> toJson() => _$WeatherDataToJson(this);
}

@JsonSerializable(explicitToJson: true)
class CurrentWeather {
  final String? time;
  final int? interval;

  @JsonKey(name: "is_day")
  final int? isDay;

  bool get isDaylight => isDay != 0;

  @JsonKey(name: "temperature_2m")
  final double? temperature2m;

  @JsonKey(name: "cloud_cover")
  final double? cloudCover;

  @JsonKey(name: "weather_code")
  final int? weatherCode;

  String get temperatureText => "$temperature2m°C";

  const CurrentWeather({
    this.time, //
    this.interval,
    this.isDay,
    this.temperature2m,
    this.cloudCover,
    this.weatherCode,
  });

  factory CurrentWeather.fromJson(Map<String, dynamic> json) => _$CurrentWeatherFromJson(json);

  Map<String, dynamic> toJson() => _$CurrentWeatherToJson(this);
}
