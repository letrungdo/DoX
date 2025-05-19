import 'package:flutter/material.dart';

extension TextStyleExt on TextStyle {
  TextStyle textColor(Color color) {
    return copyWith(color: color);
  }

  // Font Size
  TextStyle get size13 => copyWith(fontSize: 13);
  TextStyle get size15 => copyWith(fontSize: 15);
  TextStyle get size16 => copyWith(fontSize: 16);
  TextStyle get size17 => copyWith(fontSize: 17);
  TextStyle get size18 => copyWith(fontSize: 18);
  TextStyle get size20 => copyWith(fontSize: 20);
  TextStyle get size24 => copyWith(fontSize: 24);
  TextStyle get size28 => copyWith(fontSize: 28);
  TextStyle get size36 => copyWith(fontSize: 36);

  TextStyle weight(FontWeight fontWeight) {
    return copyWith(fontWeight: fontWeight);
  }

  // Font Weight
  TextStyle get regular => weight(FontWeight.normal);
  TextStyle get medium => weight(FontWeight.w500);
  TextStyle get bold => weight(FontWeight.w700);

  /// Line height 100%
  TextStyle get fit => copyWith(height: 1);

  /// Line height 150%
  TextStyle get height150 => copyWith(height: 1.5);
}
