// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'weather_data.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WeatherData _$WeatherDataFromJson(Map<String, dynamic> json) => WeatherData(
  latitude: (json['latitude'] as num?)?.toDouble(),
  longitude: (json['longitude'] as num?)?.toDouble(),
  generationtimeMs: (json['generationtimeMs'] as num?)?.toDouble(),
  utcOffsetSeconds: (json['utcOffsetSeconds'] as num?)?.toInt(),
  timezone: json['timezone'] as String?,
  timezoneAbbreviation: json['timezoneAbbreviation'] as String?,
  elevation: (json['elevation'] as num?)?.toDouble(),
  current:
      json['current'] == null
          ? null
          : CurrentWeather.fromJson(json['current'] as Map<String, dynamic>),
);

Map<String, dynamic> _$WeatherDataToJson(WeatherData instance) =>
    <String, dynamic>{
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'generationtimeMs': instance.generationtimeMs,
      'utcOffsetSeconds': instance.utcOffsetSeconds,
      'timezone': instance.timezone,
      'timezoneAbbreviation': instance.timezoneAbbreviation,
      'elevation': instance.elevation,
      'current': instance.current?.toJson(),
    };

CurrentWeather _$CurrentWeatherFromJson(Map<String, dynamic> json) =>
    CurrentWeather(
      time: json['time'] as String?,
      interval: (json['interval'] as num?)?.toInt(),
      isDay: (json['is_day'] as num?)?.toInt(),
      temperature2m: (json['temperature_2m'] as num?)?.toDouble(),
      cloudCover: (json['cloud_cover'] as num?)?.toDouble(),
      weatherCode: (json['weather_code'] as num?)?.toInt(),
    );

Map<String, dynamic> _$CurrentWeatherToJson(CurrentWeather instance) =>
    <String, dynamic>{
      'time': instance.time,
      'interval': instance.interval,
      'is_day': instance.isDay,
      'temperature_2m': instance.temperature2m,
      'cloud_cover': instance.cloudCover,
      'weather_code': instance.weatherCode,
    };
