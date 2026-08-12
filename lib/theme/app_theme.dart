import 'package:do_x/constants/dimens.dart';
import 'package:do_x/theme/color_theme.dart';
import 'package:do_x/theme/neu_theme.dart';
import 'package:do_x/theme/text_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  AppTheme._();

  static const _seed = Color(0xFF2DD4BF);

  static final ThemeData lightTheme = _buildTheme(Brightness.light);
  static final ThemeData darkTheme = _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    // Neumorphism only reads when panels share the scaffold's colour, so the
    // background comes straight from the neumorphic tokens and every surface
    // below is derived from them.
    final neu = isDark ? NeuTheme.dark : NeuTheme.light;
    final baseScheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    );
    final scheme = baseScheme.copyWith(
      primary: isDark ? const Color(0xFF2DD4BF) : const Color(0xFF00695C),
      onPrimary: isDark ? const Color(0xFF003731) : Colors.white,
      primaryContainer: isDark
          ? const Color(0xFF005047)
          : const Color(0xFF5EEAD4),
      onPrimaryContainer: isDark
          ? const Color(0xFF99F6E4)
          : const Color(0xFF00201C),
      secondary: isDark ? const Color(0xFFB1CCC6) : const Color(0xFF35504B),
      onSecondary: isDark ? const Color(0xFF1C3531) : Colors.white,
      tertiary: isDark ? const Color(0xFF37718B) : const Color(0xFF1F4E5C),
      onTertiary: Colors.white,
      // Panels must be the same colour as the scaffold, so the only steps left
      // are the sunken well and two slightly lifted tints for nested blocks.
      surface: neu.base,
      onSurface: isDark ? const Color(0xFFDDE5E1) : const Color(0xFF0C1211),
      onSurfaceVariant: isDark
          ? const Color(0xFFBFC9C5)
          : const Color(0xFF3D4A47),
      surfaceContainerLowest: neu.sunken,
      surfaceContainerLow: neu.sunken,
      surfaceContainer: neu.base,
      surfaceContainerHigh: isDark
          ? const Color(0xFF1E2826)
          : const Color(0xFFEFF6F3),
      surfaceContainerHighest: isDark
          ? const Color(0xFF27322F)
          : const Color(0xFFF6FAF8),
      outline: isDark ? const Color(0xFF89938F) : const Color(0xFF556059),
      outlineVariant: isDark
          ? const Color(0xFF3F4946)
          : const Color(0xFFA7B5B0),
    );
    final background = neu.base;
    // Transparent system bars: with edge-to-edge the app paints behind them, so
    // the gesture navigation area picks up the bottom nav's colour.
    final systemOverlayStyle = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarBrightness: brightness,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: isDark
          ? Brightness.light
          : Brightness.dark,
    );
    final textTheme = _textTheme(scheme);
    final rounded14 = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(Dimens.radiusControl),
    );
    final rounded16 = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(Dimens.radiusCard),
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
        systemOverlayStyle: systemOverlayStyle,
      ),
      // Cards are drawn by `NeuCard`, which paints its own shadow pair. This
      // theme only covers stray Material [Card]s: flat and borderless, so they
      // don't reintroduce an outline next to a neumorphic panel.
      cardTheme: CardThemeData(
        color: neu.base,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: rounded16,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: neu.base,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Dimens.dialogRadius),
        ),
        // The action buttons are raised: the top gap has to clear their lit rim
        // so it does not land on the message above.
        actionsPadding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: textTheme.bodyMedium,
      ),
      // Sheets are opened through `showAppBottomSheet`, which paints its own
      // surface; this only covers a stray `showModalBottomSheet` so it lands on
      // the same colour, radius and width cap instead of a Material default.
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: neu.base,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        // Deliberately not `showDragHandle`: `AppBottomSheet` draws its own, and
        // turning it on here paints a second handle above the sheet's.
        constraints: const BoxConstraints(maxWidth: Dimens.sheetMaxWidth),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(Dimens.sheetRadius),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          disabledBackgroundColor: scheme.onSurface.withValues(alpha: 0.12),
          disabledForegroundColor: scheme.onSurface.withValues(alpha: 0.38),
          // Material can only drop a directional shadow, not a neumorphic pair
          // — enough to keep themed buttons lifted. `NeuButton` is the
          // full-fidelity version, with the press-to-sink cue.
          elevation: 4,
          shadowColor: neu.darkShadow,
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
          backgroundColor: neu.base,
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          // The outline is exactly what neumorphism replaces; a lifted
          // same-colour pill carries the secondary action instead.
          side: BorderSide.none,
          elevation: 3,
          shadowColor: neu.darkShadow,
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
            borderRadius: BorderRadius.circular(Dimens.radiusControlSmall),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: scheme.onSurfaceVariant,
          minimumSize: const Size.square(44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Dimens.radiusControlSmall),
          ),
        ),
      ),
      // Inputs are the concave half of the language: sunken fill, no resting
      // outline. Only focus draws a line, because a colour-only focus cue is
      // too weak on a surface this low-contrast.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: neu.sunken,
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
          borderRadius: BorderRadius.circular(Dimens.radiusControl),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Dimens.radiusControl),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Dimens.radiusControl),
          borderSide: BorderSide(color: scheme.primary, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Dimens.radiusControl),
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Dimens.radiusControl),
          borderSide: BorderSide(color: scheme.error, width: 1.8),
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: neu.sunken,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Dimens.radiusControl),
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
      // A hard rule reads as a seam between two same-coloured panels, so
      // dividers are dialled down; separation comes from the shadows.
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: isDark ? 0.28 : 0.40),
        thickness: 1,
        space: 24,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: neu.sunken,
        selectedColor: scheme.primaryContainer,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Dimens.radiusControlSmall),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        labelStyle: textTheme.labelLarge!,
      ),
      switchTheme: SwitchThemeData(
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : neu.sunken,
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Dimens.radiusTiny),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 68,
        indicatorColor: scheme.primary.withValues(alpha: 0.12),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Dimens.radiusControl),
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
        backgroundColor: background,
        selectedItemColor: scheme.primary,
        unselectedItemColor: scheme.onSurfaceVariant,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primaryContainer,
        foregroundColor: scheme.onPrimaryContainer,
        elevation: 6,
        focusElevation: 6,
        hoverElevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Dimens.radiusCard),
        ),
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
        linearTrackColor: neu.sunken,
        circularTrackColor: neu.sunken,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: neu.base,
        surfaceTintColor: Colors.transparent,
        shadowColor: neu.darkShadow,
        elevation: 6,
        shape: rounded14,
        textStyle: textTheme.bodyMedium,
      ),
      extensions: [
        isDark ? ColorTheme.dark : ColorTheme.light,
        isDark ? DoTextTheme.dark : DoTextTheme.light,
        neu,
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
