import 'package:do_ai/model/platform_value.dart';

enum Flavor {
  dev,
  prod,
}

class Envs {
  const Envs._();

  static const String _flavorString = String.fromEnvironment('FLAVOR');
  static final Flavor flavor = Flavor.values.firstWhere(
    (e) => e.name == _flavorString,
    orElse: () => Flavor.dev,
  );

  static final bool isDev = flavor != Flavor.prod;

  static const firebaseApiKey = PlatformValue(
    iOS: String.fromEnvironment('FIREBASE_API_KEY_IOS'),
    android: String.fromEnvironment('FIREBASE_API_KEY_ANDROID'),
    web: String.fromEnvironment('FIREBASE_API_KEY_WEB'),
  );
}
