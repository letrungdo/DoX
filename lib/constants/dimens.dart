import 'package:flutter/foundation.dart';

class Dimens {
  Dimens._();

  static const appBarHeight = kIsWeb ? 60.0 : 44.0;
  static const webMaxWidth = 450.0;

  /// Past this a dialog reads as a banner on a desktop window.
  static const dialogMaxWidth = 460.0;
}
