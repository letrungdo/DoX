import 'package:do_x/extensions/text_style_extensions.dart';
import 'package:flutter/material.dart';

class DoTextTheme extends ThemeExtension<DoTextTheme> {
  const DoTextTheme({
    required this.primary,
    required this.secondary,
    required this.title,
  });

  final TextStyle primary;
  final TextStyle secondary;
  final TextStyle title;

  static const white500Color = Color(0xFFF5F6F7);
  static const rangoonGreenColor = Color(0xFF18181A);
  static const black500Color = Color(0xFF18181A);

  static const baseStyle = TextStyle(
    fontWeight: FontWeight.w400,
    fontSize: 14,
    letterSpacing: 0,
  );

  /// Text inside a small pill/badge. `height: 1` with even leading centres the
  /// glyph box in the pill — with the font's default line height the descent
  /// pushes the label visibly low inside such tight padding. Callers add
  /// `fontSize` and `color`.
  static const pill = TextStyle(
    height: 1,
    leadingDistribution: TextLeadingDistribution.even,
    fontWeight: FontWeight.w700,
  );

  /// The money figure on a list row (a sale, an expense). Callers add `color`.
  static const listAmount = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
  );

  static final light = DoTextTheme(
    primary: baseStyle.textColor(black500Color),
    secondary: baseStyle.textColor(black500Color),
    title: baseStyle.textColor(const Color(0xFF676B74)),
  );

  static final dark = DoTextTheme(
    primary: baseStyle.textColor(Colors.white),
    secondary: baseStyle.textColor(white500Color),
    title: baseStyle.textColor(const Color(0xFFAEAEBF)),
  );

  @override
  ThemeExtension<DoTextTheme> copyWith({
    TextStyle? primary,
    TextStyle? secondary,
    TextStyle? title,
  }) {
    return DoTextTheme(
      primary: primary ?? this.primary,
      secondary: secondary ?? this.secondary,
      title: title ?? this.title,
    );
  }

  @override
  ThemeExtension<DoTextTheme> lerp(
    ThemeExtension<DoTextTheme>? other,
    double t,
  ) {
    if (other is! DoTextTheme) {
      return this;
    }
    return DoTextTheme(
      primary: TextStyle.lerp(primary, other.primary, t)!,
      secondary: TextStyle.lerp(secondary, other.secondary, t)!,
      title: TextStyle.lerp(title, other.title, t)!,
    );
  }
}
