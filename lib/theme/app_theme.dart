import 'package:do_x/theme/color_theme.dart';
import 'package:do_x/theme/text_theme.dart';
import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // Light
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      brightness: Brightness.light, //
      seedColor: Colors.deepPurple,
    ),
    extensions: [
      ColorTheme.light, //
      DoTextTheme.light,
    ],
  );

  // Dark
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      brightness: Brightness.dark, //
      seedColor: Colors.lightGreenAccent,
    ),
    // elevatedButtonTheme: ElevatedButtonThemeData(
    //   style: ButtonStyle(
    //     backgroundColor: WidgetStateProperty.fromMap({
    //       WidgetState.disabled: ColorTheme.primary.shade600,
    //       WidgetState.any: ColorTheme.primary.shade900,
    //     }),
    //     textStyle: WidgetStatePropertyAll(DoTextTheme.dark.primary.medium.copyWith(color: Colors.white)),
    //   ),
    // ),
    extensions: [
      ColorTheme.dark, //
      DoTextTheme.dark,
    ],
  );
}
