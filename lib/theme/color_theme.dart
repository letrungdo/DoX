import 'package:flutter/material.dart';

class ColorTheme extends ThemeExtension<ColorTheme> {
  const ColorTheme({
    required this.buttonBg, //
    required this.disabled,
    required this.iconColor,
    required this.money,
    required this.success,
    required this.successSoft,
    required this.warning,
    required this.warningSoft,
    required this.danger,
    required this.dangerSoft,
    required this.info,
    required this.infoSoft,
    required this.meat,
    required this.meatSoft,
  });

  final Color buttonBg;
  final Color disabled;
  final Color iconColor;

  /// Shared color for money/price texts across screens.
  final Color money;

  /// Semantic accents, used for text, icons and borders. Each one is picked to
  /// stay readable on its own theme's surfaces: deep shades in light mode
  /// (raw `Colors.green`/`Colors.orange` wash out on white), bright shades in
  /// dark mode.
  final Color success;
  final Color warning;
  final Color danger;
  final Color info;

  /// Accent for meat chicken records. Deliberately not a brown: it sits next to
  /// [warning] (expense) in the statistics chart, and two warm tones there were
  /// impossible to tell apart.
  final Color meat;

  /// Opaque low-contrast fills that pair with the accent of the same name.
  /// Opaque rather than `accent.withValues(alpha: ...)` so a tint keeps its hue
  /// when it lands on a card that is itself tinted.
  final Color successSoft;
  final Color warningSoft;
  final Color dangerSoft;
  final Color infoSoft;
  final Color meatSoft;

  static final light = ColorTheme(
    buttonBg: const Color(0xFFE7F1ED), //
    disabled: const Color(0xFFA7B5B0),
    iconColor: const Color(0xFF2E4540),
    money: const Color(0xFF00695C),
    success: const Color(0xFF0B5A2C),
    successSoft: const Color(0xFFD6EDDF),
    warning: const Color(0xFF853A04),
    warningSoft: const Color(0xFFF8E5CB),
    danger: const Color(0xFF8F1D17),
    dangerSoft: const Color(0xFFF7DAD7),
    info: const Color(0xFF135A73),
    infoSoft: const Color(0xFFD4E6EE),
    meat: const Color(0xFF5620AE),
    meatSoft: const Color(0xFFE4DAFB),
  );

  static final dark = ColorTheme(
    buttonBg: const Color(0xFF16201E), //
    disabled: const Color(0xFF3F4946),
    iconColor: const Color(0xFFDDE5E1),
    money: const Color(0xFF2DD4BF),
    success: const Color(0xFF6EDFA6),
    successSoft: const Color(0xFF16332A),
    warning: const Color(0xFFFFB871),
    warningSoft: const Color(0xFF3A2A17),
    danger: const Color(0xFFFF8A80),
    dangerSoft: const Color(0xFF3A1F1E),
    info: const Color(0xFF8ECBE6),
    infoSoft: const Color(0xFF17303A),
    meat: const Color(0xFFC4B5FD),
    meatSoft: const Color(0xFF2A2340),
  );

  @override
  ThemeExtension<ColorTheme> copyWith({
    Color? buttonBg,
    Color? disabled,
    Color? iconColor, //
    Color? money,
    Color? success,
    Color? successSoft,
    Color? warning,
    Color? warningSoft,
    Color? danger,
    Color? dangerSoft,
    Color? info,
    Color? infoSoft,
    Color? meat,
    Color? meatSoft,
  }) {
    return ColorTheme(
      buttonBg: buttonBg ?? this.buttonBg, //
      disabled: disabled ?? this.disabled,
      iconColor: iconColor ?? this.iconColor,
      money: money ?? this.money,
      success: success ?? this.success,
      successSoft: successSoft ?? this.successSoft,
      warning: warning ?? this.warning,
      warningSoft: warningSoft ?? this.warningSoft,
      danger: danger ?? this.danger,
      dangerSoft: dangerSoft ?? this.dangerSoft,
      info: info ?? this.info,
      infoSoft: infoSoft ?? this.infoSoft,
      meat: meat ?? this.meat,
      meatSoft: meatSoft ?? this.meatSoft,
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
      success: Color.lerp(success, other.success, t)!,
      successSoft: Color.lerp(successSoft, other.successSoft, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningSoft: Color.lerp(warningSoft, other.warningSoft, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerSoft: Color.lerp(dangerSoft, other.dangerSoft, t)!,
      info: Color.lerp(info, other.info, t)!,
      infoSoft: Color.lerp(infoSoft, other.infoSoft, t)!,
      meat: Color.lerp(meat, other.meat, t)!,
      meatSoft: Color.lerp(meatSoft, other.meatSoft, t)!,
    );
  }
}
