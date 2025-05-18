import 'package:flutter/material.dart';

extension ColorExtensions on Color? {
  String? toHexString({bool includeAlpha = true}) {
    final color = this;
    if (color == null) return null;

    final aInt = (color.a * 255).toInt();
    final rInt = (color.r * 255).toInt();
    final gInt = (color.g * 255).toInt();
    final bInt = (color.b * 255).toInt();

    final aHex = aInt.toRadixString(16).padLeft(2, '0');
    final rHex = rInt.toRadixString(16).padLeft(2, '0');
    final gHex = gInt.toRadixString(16).padLeft(2, '0');
    final bHex = bInt.toRadixString(16).padLeft(2, '0');

    return '#${includeAlpha ? aHex : ""}$rHex$gHex$bHex'.toUpperCase();
  }

  Color? getTextColor() {
    final color = this;
    if (color == null) return null;
    return color.computeLuminance() > 0.5 ? Color.fromARGB(255, 2, 22, 59) : Color(0xFFFFFFE6);
  }
}
