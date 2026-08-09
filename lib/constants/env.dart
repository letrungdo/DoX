import 'package:do_x/model/platform_value.dart';

enum Flavor { dev, prod }

class Envs {
  const Envs._();

  static const String _flavorString = String.fromEnvironment('FLAVOR');
  static final Flavor flavor = Flavor.values.firstWhere(
    (e) => e.name == _flavorString,
    orElse: () => Flavor.dev,
  );

  static final bool isDev = flavor != Flavor.prod;

  // --- Server endpoints ------------------------------------------------
  //
  // The backends a build can be pointed at live here rather than in the service
  // that calls them, and come in through
  // `--dart-define-from-file envs/<flavor>/dart-define.env`.
  //
  // Fixed addresses stay inline at their call site: the public APIs (Google,
  // open-meteo, Cloudflare), the GitHub releases endpoint, and the companion
  // site in [AuthLinks], which the platform manifests have to agree with.

  /// Market data — quotes, bars and the overview catalogues.
  static const marketApiUrl = String.fromEnvironment('MARKET_API_URL');

  /// Real-time price push for the market data above.
  static const marketWsUrl = String.fromEnvironment('MARKET_WS_URL');

  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseKey = String.fromEnvironment('SUPABASE_KEY');

  static const myLifeApiUrl = String.fromEnvironment('ML_API_URL');

  /// CSKH CPC (Trung tâm CSKH Điện lực miền Trung).
  static const electricApiUrl = String.fromEnvironment('ELECTRIC_API_URL');

  /// MyLife's own API key. It is the key their iOS client ships, and every
  /// platform authenticates with it — the app talks to MyLife's servers, not to
  /// a per-platform Firebase project of ours.
  static const myLifeApiKey = String.fromEnvironment('ML_API_KEY');

  /// Bundle identifier the My Life requests present themselves with. The
  /// upstream Firebase project only answers to its own client, so this travels
  /// in the `X-Ios-Bundle-Identifier` header and in the upload user agents.
  static const myLifeBundleId = String.fromEnvironment('ML_BUNDLE_ID');

  /// Firebase Storage prefix the My Life moments are uploaded to, up to the
  /// stem the two buckets share — the upload service appends `-img` / `-video`
  /// and the path under them.
  static const myLifeStorageUrl = String.fromEnvironment('ML_STORAGE_URL');

  static const firebaseApiKey = PlatformValue(
    iOS: String.fromEnvironment('FIREBASE_API_KEY_IOS'),
    android: String.fromEnvironment('FIREBASE_API_KEY_ANDROID'),
    web: String.fromEnvironment('FIREBASE_API_KEY_WEB'),
  );
}
