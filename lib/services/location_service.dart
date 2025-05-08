import 'package:do_x/utils/logger.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  String? _currentTimeZone;
  Position? _position;

  Future<String?> getLocationName(Position position) async {
    try {
      final placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      final place = placemarks.firstOrNull;
      if (place == null) return "";
      return "${place.street}, ${place.locality}";
    } catch (e) {
      logger.e(e.toString(), error: e);
    }
    return null;
  }

  Future<Position?> getCurrentPosition() async {
    try {
      _position ??= await _determinePosition();
      return _position;
    } catch (e) {
      logger.e(e.toString(), error: e);
    }
    return null;
  }

  Future<String> getCurrentTimeZone() async {
    try {
      _currentTimeZone ??= await FlutterTimezone.getLocalTimezone();
    } catch (e) {
      logger.e(e.toString(), error: e);
    }
    return _currentTimeZone ?? "Asia/Tokyo";
  }

  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled don't continue
      // accessing the position and request users of the
      // App to enable the location services.
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Permissions are denied, next time you could try
        // requesting permissions again (this is also where
        // Android's shouldShowRequestPermissionRationale
        // returned true. According to Android guidelines
        // your App should show an explanatory UI now.
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Permissions are denied forever, handle appropriately.
      return Future.error('Location permissions are permanently denied, we cannot request permissions.');
    }

    // When we reach here, permissions are granted and we can
    // continue accessing the position of the device.
    return await Geolocator.getCurrentPosition();
  }
}
