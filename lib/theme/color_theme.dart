import 'package:flutter/material.dart';

class ColorTheme extends ThemeExtension<ColorTheme> {
  const ColorTheme({
    required this.inputBadgeBg, //
    required this.disabled,
  });

  final Color inputBadgeBg;
  final Color disabled;

  static final light = ColorTheme(
    inputBadgeBg: const Color.fromARGB(255, 255, 255, 255), //
    disabled: const Color(0xFFCFCFDD),
  );

  static final dark = ColorTheme(
    inputBadgeBg: const Color.fromARGB(255, 13, 55, 222), //
    disabled: Colors.white.withValues(alpha: 0.3),
  );

  @override
  ThemeExtension<ColorTheme> copyWith({Color? inputBadgeBg, Color? disabled}) {
    return ColorTheme(
      inputBadgeBg: inputBadgeBg ?? this.inputBadgeBg, //
      disabled: disabled ?? this.disabled,
    );
  }

  @override
  ThemeExtension<ColorTheme> lerp(ThemeExtension<ColorTheme>? other, double t) {
    if (other is! ColorTheme) {
      return this;
    }
    return ColorTheme(
      inputBadgeBg: Color.lerp(inputBadgeBg, other.inputBadgeBg, t)!, //
      disabled: Color.lerp(disabled, other.disabled, t)!,
    );
  }
}
