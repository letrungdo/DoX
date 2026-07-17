import 'package:do_x/theme/color_theme.dart';
import 'package:do_x/theme/text_theme.dart';
import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const _seed = Color(0xFF2DD4BF);
  static const _lightBackground = Color(0xFFF4FAF8);
  static const _darkBackground = Color(0xFF0D1513);

  static final ThemeData lightTheme = _buildTheme(Brightness.light);
  static final ThemeData darkTheme = _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final baseScheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    );
    final scheme = baseScheme.copyWith(
      primary: isDark ? const Color(0xFF2DD4BF) : const Color(0xFF00897B),
      onPrimary: isDark ? const Color(0xFF003731) : Colors.white,
      primaryContainer: isDark
          ? const Color(0xFF005047)
          : const Color(0xFF99F6E4),
      onPrimaryContainer: isDark
          ? const Color(0xFF99F6E4)
          : const Color(0xFF00201C),
      secondary: isDark ? const Color(0xFFB1CCC6) : const Color(0xFF4A635E),
      onSecondary: isDark ? const Color(0xFF1C3531) : Colors.white,
      tertiary: isDark ? const Color(0xFFA9CDDF) : const Color(0xFF336575),
      onTertiary: isDark ? const Color(0xFF143542) : Colors.white,
      surface: isDark ? const Color(0xFF151D1B) : Colors.white,
      onSurface: isDark ? const Color(0xFFDDE5E1) : const Color(0xFF171D1B),
      surfaceContainerLowest: isDark ? const Color(0xFF080F0D) : Colors.white,
      surfaceContainerLow: isDark
          ? const Color(0xFF151D1B)
          : const Color(0xFFF0F8F5),
      surfaceContainer: isDark
          ? const Color(0xFF19211F)
          : const Color(0xFFEAF2EF),
      surfaceContainerHigh: isDark
          ? const Color(0xFF232B29)
          : const Color(0xFFE4ECE9),
      surfaceContainerHighest: isDark
          ? const Color(0xFF2E3634)
          : const Color(0xFFDDE5E2),
      outline: isDark ? const Color(0xFF89938F) : const Color(0xFF6F7975),
      outlineVariant: isDark
          ? const Color(0xFF3F4946)
          : const Color(0xFFBFC9C5),
    );
    final background = isDark ? _darkBackground : _lightBackground;
    final textTheme = _textTheme(scheme);
    final rounded14 = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
    );
    final rounded16 = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      textTheme: textTheme,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        iconTheme: IconThemeData(color: scheme.onSurface, size: 23),
        actionsIconTheme: IconThemeData(color: scheme.onSurface, size: 23),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: isDark ? 0 : 1,
        shadowColor: scheme.shadow.withValues(alpha: 0.10),
        margin: EdgeInsets.zero,
        shape: rounded16.copyWith(
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.55),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shadowColor: scheme.shadow.withValues(alpha: 0.24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: textTheme.bodyMedium,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          disabledBackgroundColor: scheme.onSurface.withValues(alpha: 0.12),
          disabledForegroundColor: scheme.onSurface.withValues(alpha: 0.38),
          elevation: 0,
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          shape: rounded14,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          shape: rounded14,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          side: BorderSide(color: scheme.outlineVariant),
          shape: rounded14,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          minimumSize: const Size(48, 44),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: scheme.onSurfaceVariant,
          minimumSize: const Size.square(44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        hintStyle: TextStyle(
          color: scheme.onSurfaceVariant.withValues(
            alpha: isDark ? 0.58 : 0.52,
          ),
        ),
        prefixIconColor: scheme.onSurfaceVariant,
        suffixIconColor: scheme.onSurfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.65),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.error, width: 1.8),
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: scheme.surfaceContainerLow,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(scheme.surfaceContainer),
          shape: WidgetStatePropertyAll(rounded14),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        textColor: scheme.onSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: rounded14,
        titleTextStyle: textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        subtitleTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.70),
        thickness: 1,
        space: 24,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainer,
        selectedColor: scheme.primaryContainer,
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.65)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        labelStyle: textTheme.labelLarge!,
      ),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.surfaceContainerHighest,
        ),
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.onPrimary
              : scheme.outline,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : Colors.transparent,
        ),
        checkColor: WidgetStatePropertyAll(scheme.onPrimary),
        side: BorderSide(color: scheme.outline, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 2,
        height: 68,
        indicatorColor: scheme.primary.withValues(alpha: 0.12),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
            size: 24,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => textTheme.labelMedium?.copyWith(
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: scheme.surface,
        selectedItemColor: scheme.primary,
        unselectedItemColor: scheme.onSurfaceVariant,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primaryContainer,
        foregroundColor: scheme.onPrimaryContainer,
        elevation: 2,
        focusElevation: 3,
        hoverElevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark
            ? scheme.surfaceContainerHighest
            : const Color(0xFF263330),
        contentTextStyle: TextStyle(
          color: isDark ? scheme.onSurface : Colors.white,
          fontWeight: FontWeight.w500,
        ),
        actionTextColor: isDark ? scheme.primary : const Color(0xFF8CE4D6),
        shape: rounded14,
        insetPadding: const EdgeInsets.all(12),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.primaryContainer,
        circularTrackColor: scheme.surfaceContainerHighest,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shape: rounded14,
        textStyle: textTheme.bodyMedium,
      ),
      extensions: [
        isDark ? ColorTheme.dark : ColorTheme.light,
        isDark ? DoTextTheme.dark : DoTextTheme.light,
      ],
    );
  }

  static TextTheme _textTheme(ColorScheme scheme) {
    return Typography.material2021(platform: TargetPlatform.android).black
        .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface)
        .copyWith(
          displaySmall: TextStyle(
            fontSize: 36,
            height: 1.15,
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
          headlineLarge: TextStyle(
            fontSize: 30,
            height: 1.2,
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
          headlineMedium: TextStyle(
            fontSize: 26,
            height: 1.2,
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
          headlineSmall: TextStyle(
            fontSize: 22,
            height: 1.25,
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
          titleLarge: TextStyle(
            fontSize: 20,
            height: 1.3,
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
          titleMedium: TextStyle(
            fontSize: 16,
            height: 1.35,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
          titleSmall: TextStyle(
            fontSize: 14,
            height: 1.35,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
          bodyLarge: TextStyle(
            fontSize: 16,
            height: 1.45,
            fontWeight: FontWeight.w400,
            color: scheme.onSurface,
          ),
          bodyMedium: TextStyle(
            fontSize: 14,
            height: 1.45,
            fontWeight: FontWeight.w400,
            color: scheme.onSurface,
          ),
          bodySmall: TextStyle(
            fontSize: 12,
            height: 1.4,
            fontWeight: FontWeight.w400,
            color: scheme.onSurfaceVariant,
          ),
          labelLarge: TextStyle(
            fontSize: 14,
            height: 1.25,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
          labelMedium: TextStyle(
            fontSize: 12,
            height: 1.25,
            fontWeight: FontWeight.w600,
            color: scheme.onSurfaceVariant,
          ),
        );
  }
}
