import 'package:flutter/material.dart';

class ColorTheme extends ThemeExtension<ColorTheme> {
  const ColorTheme({
    required this.buttonBg, //
    required this.disabled,
    required this.iconColor,
  });

  final Color buttonBg;
  final Color disabled;
  final Color iconColor;

  static final light = ColorTheme(
    buttonBg: Colors.white, //
    disabled: const Color(0xFFCFCFDD),
    iconColor: Colors.grey[800]!,
  );

  static final dark = ColorTheme(
    buttonBg: Colors.black, //
    disabled: Colors.white.withValues(alpha: 0.3),
    iconColor: Colors.white,
  );

  @override
  ThemeExtension<ColorTheme> copyWith({
    Color? buttonBg,
    Color? disabled,
    Color? iconColor, //
  }) {
    return ColorTheme(
      buttonBg: buttonBg ?? this.buttonBg, //
      disabled: disabled ?? this.disabled,
      iconColor: iconColor ?? this.iconColor,
    );
  }

  @override
  ThemeExtension<ColorTheme> lerp(ThemeExtension<ColorTheme>? other, double t) {
    if (other is! ColorTheme) {
      return this;
    }
    return ColorTheme(
      buttonBg: Color.lerp(buttonBg, other.buttonBg, t)!, //
      disabled: Color.lerp(disabled, other.disabled, t)!,
      iconColor: Color.lerp(iconColor, other.iconColor, t)!,
    );
  }
}
