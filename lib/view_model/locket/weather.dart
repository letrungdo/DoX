import 'package:flutter/material.dart';
import 'package:flutter_sficon/flutter_sficon.dart';

class WeatherIcon {
  const WeatherIcon(this.symbolName, this.description, this.icon);
  final String symbolName;
  final String description;
  final IconData icon;
}

/// https://gist.github.com/stellasphere/9490c195ed2b53c707087c8c2db4ec0c
/// https://gist.github.com/jasonsnell/2757e58081a1ae377a9c0feed875976b
/// https://docs.google.com/spreadsheets/d/1D8Bdrk26dhZ4PdrNGUL9e9Bs9vnCrUxI_VbHhaZMgUY/edit?gid=1359697320#gid=1359697320
/// https://www.nodc.noaa.gov/archive/arc0021/0002199/1.1/data/0-data/HTML/WMO-CODE/WMO4677.HTM
final Map<int, WeatherIcon> wmoWeatherInfos = {
  0: WeatherIcon('sun.max', 'clear', SFIcons.sf_sun_max),
  1: WeatherIcon('sun.min', 'mostlyClear', SFIcons.sf_sun_min),
  2: WeatherIcon('cloud.sun', 'partlyCloudy', SFIcons.sf_cloud_sun),
  3: WeatherIcon('cloud', 'cloudy', SFIcons.sf_cloud),
  45: WeatherIcon('cloud.fog', 'foggy', SFIcons.sf_cloud_fog),
  48: WeatherIcon('cloud.fog', 'foggy', SFIcons.sf_cloud_fog),
  51: WeatherIcon('cloud.drizzle', 'drizzle', SFIcons.sf_cloud_drizzle),
  53: WeatherIcon('cloud.drizzle', 'drizzle', SFIcons.sf_cloud_drizzle),
  55: WeatherIcon('cloud.drizzle', 'drizzle', SFIcons.sf_cloud_drizzle),
  56: WeatherIcon('cloud.drizzle.fill', 'freezingDrizzle', SFIcons.sf_cloud_drizzle_fill),
  57: WeatherIcon('cloud.drizzle.fill', 'freezingDrizzle', SFIcons.sf_cloud_drizzle_fill),
  61: WeatherIcon('cloud.rain', 'rain', SFIcons.sf_cloud_rain),
  63: WeatherIcon('cloud.rain', 'rain', SFIcons.sf_cloud_rain),
  65: WeatherIcon('cloud.heavyrain', 'heavyRain', SFIcons.sf_cloud_heavyrain),
  66: WeatherIcon('cloud.rain.fill', 'freezingRain', SFIcons.sf_cloud_rain_fill),
  67: WeatherIcon('cloud.rain.fill', 'freezingRain', SFIcons.sf_cloud_rain_fill),
  71: WeatherIcon('cloud.snow', 'snow', SFIcons.sf_cloud_snow),
  73: WeatherIcon('cloud.snow', 'snow', SFIcons.sf_cloud_snow),
  75: WeatherIcon('cloud.snow.fill', 'heavySnow', SFIcons.sf_cloud_snow_fill),
  77: WeatherIcon('cloud.snow', 'snow', SFIcons.sf_cloud_snow),
  80: WeatherIcon('cloud.rain', 'rain', SFIcons.sf_cloud_rain),
  81: WeatherIcon('cloud.rain', 'rain', SFIcons.sf_cloud_rain),
  82: WeatherIcon('cloud.heavyrain', 'heavyRain', SFIcons.sf_cloud_heavyrain),
  85: WeatherIcon('cloud.snow', 'snow', SFIcons.sf_cloud_snow),
  86: WeatherIcon('cloud.snow', 'snow', SFIcons.sf_cloud_snow),
  95: WeatherIcon('cloud.bolt', 'thunderstorms', SFIcons.sf_cloud_bolt),
  96: WeatherIcon('cloud.bolt', 'thunderstorms', SFIcons.sf_cloud_bolt),
  99: WeatherIcon('cloud.bolt', 'thunderstorms', SFIcons.sf_cloud_bolt),
};
