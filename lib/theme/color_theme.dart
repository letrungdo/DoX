import 'package:flutter/material.dart';

class ColorTheme extends ThemeExtension<ColorTheme> {
  const ColorTheme({
    required this.buttonBg, //
    required this.disabled,
    required this.iconColor,
    required this.money,
  });

  final Color buttonBg;
  final Color disabled;
  final Color iconColor;

  /// Shared color for money/price texts across screens.
  final Color money;

  static final light = ColorTheme(
    buttonBg: Colors.white, //
    disabled: const Color(0xFFBFC9C5),
    iconColor: const Color(0xFF435A55),
    money: const Color(0xFF00897B),
  );

  static final dark = ColorTheme(
    buttonBg: const Color(0xFF19211F), //
    disabled: const Color(0xFF3F4946),
    iconColor: const Color(0xFFDDE5E1),
    money: const Color(0xFF2DD4BF),
  );

  @override
  ThemeExtension<ColorTheme> copyWith({
    Color? buttonBg,
    Color? disabled,
    Color? iconColor, //
    Color? money,
  }) {
    return ColorTheme(
      buttonBg: buttonBg ?? this.buttonBg, //
      disabled: disabled ?? this.disabled,
      iconColor: iconColor ?? this.iconColor,
      money: money ?? this.money,
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
      money: Color.lerp(money, other.money, t)!,
    );
  }
}
