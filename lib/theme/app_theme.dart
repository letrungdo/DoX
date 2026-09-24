import 'package:do_x/constants/dimens.dart';
import 'package:do_x/theme/color_theme.dart';
import 'package:do_x/theme/surface_theme.dart';
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
    // The page, card, elevated and muted fills all come from the surface
    // tokens, so the ColorScheme and the hand-drawn primitives agree.
    final surfaces = isDark ? SurfaceTheme.dark : SurfaceTheme.light;
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
      // `surface` is the card, not the page: Material widgets that paint it
      // (a stray Card, a menu) land one fill step above the scaffold.
      surface: surfaces.surface,
      onSurface: isDark ? const Color(0xFFE6EDEB) : const Color(0xFF0F1716),
      onSurfaceVariant: isDark
          ? const Color(0xFFA9B5B2)
          : const Color(0xFF46534F),
      surfaceContainerLowest: isDark
          ? const Color(0xFF0A0F0E)
          : const Color(0xFFFFFFFF),
      surfaceContainerLow: surfaces.base,
      surfaceContainer: surfaces.surface,
      surfaceContainerHigh: surfaces.elevated,
      surfaceContainerHighest: surfaces.sunken,
      outline: isDark ? const Color(0xFF7F8B88) : const Color(0xFF6F7C78),
      outlineVariant: surfaces.hairline,
    );
    final background = surfaces.base;
    // Hints, captions and counters: a step below `onSurfaceVariant` that still
    // passes AA on the card and on the muted input fill.
    final textTertiary = isDark
        ? const Color(0xFF8E9A97)
        : const Color(0xFF5F6B68);
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
    // A floating menu. Dark mode adds a hairline: the elevated fill is too
    // close to the card beneath it for a layer that floats over content.
    final menuShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(Dimens.radiusControl),
      side: isDark
          ? BorderSide(color: surfaces.hairline, width: Dimens.hairline)
          : BorderSide.none,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      hintColor: textTertiary,
      textTheme: textTheme,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      // What an `InkWell` paints when the focus lands on it. Material's default
      // is a faint `onSurface` wash, too weak to read across a room, which is
      // where a TV remote is used from. Tinted with the primary instead, so it
      // matches the outline `TvShell` draws.
      focusColor: scheme.primary.withValues(alpha: isDark ? 0.34 : 0.24),
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
      // Cards are drawn by `AppCard`. This theme only covers stray Material
      // [Card]s: the same card fill, flat and borderless, so they match it.
      cardTheme: CardThemeData(
        color: surfaces.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: rounded16,
      ),
      // No shadow: the scrim is what separates a dialog from the page.
      dialogTheme: DialogThemeData(
        backgroundColor: surfaces.elevated,
        barrierColor: surfaces.scrim,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Dimens.dialogRadius),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      // Sheets are opened through `showAppBottomSheet`, which paints its own
      // surface; this only covers a stray `showModalBottomSheet` so it lands on
      // the same colour, radius and width cap instead of a Material default.
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surfaces.elevated,
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: surfaces.scrim,
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
          disabledBackgroundColor: surfaces.sunken,
          disabledForegroundColor: scheme.onSurface.withValues(alpha: 0.38),
          // Flat, like `AppButton`: the fill is the button.
          elevation: 0,
          minimumSize: const Size(64, Dimens.buttonMinHeight),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          shape: rounded14,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, Dimens.buttonMinHeight),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          shape: rounded14,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          // The neutral button: the card fill carries the secondary action,
          // so no outline is drawn.
          backgroundColor: surfaces.surface,
          minimumSize: const Size(64, Dimens.buttonMinHeight),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          side: BorderSide.none,
          elevation: 0,
          shape: rounded14,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
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
      // Inputs take the muted fill and no resting outline. Only focus draws a
      // line, because a colour-only focus cue is too weak on its own.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? surfaces.sunken.withValues(alpha: 0.5)
              : surfaces.sunken,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        hintStyle: TextStyle(color: textTertiary),
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
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Dimens.radiusControl),
          borderSide: BorderSide(color: scheme.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Dimens.radiusControl),
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surfaces.sunken,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Dimens.radiusControl),
            borderSide: BorderSide.none,
          ),
        ),
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(surfaces.elevated),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          elevation: const WidgetStatePropertyAll(3),
          shadowColor: WidgetStatePropertyAll(surfaces.darkShadow),
          shape: WidgetStatePropertyAll(menuShape),
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
        color: surfaces.hairline,
        thickness: Dimens.hairline,
        space: 24,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaces.sunken,
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
              : surfaces.sunken,
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
        backgroundColor: surfaces.surface,
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
      // The television's tab switcher. Same colours as the bottom bar it
      // replaces, so the two read as one component moved rather than as two
      // different navigations.
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: background,
        elevation: 0,
        useIndicator: true,
        indicatorColor: scheme.primary.withValues(alpha: 0.12),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Dimens.radiusControl),
        ),
        selectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: scheme.primary,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w500,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surfaces.surface,
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
        // Flat, like every other control: the container colour is its edge.
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Dimens.radiusCard),
        ),
      ),
      // Inverse in both modes: a dark snack bar on a dark page was the
      // weakest element of the old theme. It floats, so it keeps the shadow.
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark
            ? const Color(0xFFE6EDEB)
            : const Color(0xFF1E2B29),
        contentTextStyle: TextStyle(
          color: isDark ? const Color(0xFF0F1716) : Colors.white,
          fontWeight: FontWeight.w500,
        ),
        actionTextColor: isDark
            ? const Color(0xFF00695C)
            : const Color(0xFF8CE4D6),
        shape: rounded14,
        elevation: 3,
        insetPadding: const EdgeInsets.all(12),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: surfaces.sunken,
        circularTrackColor: surfaces.sunken,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surfaces.elevated,
        surfaceTintColor: Colors.transparent,
        shadowColor: surfaces.darkShadow,
        elevation: 3,
        shape: menuShape,
        textStyle: textTheme.bodyMedium,
      ),
      extensions: [
        isDark ? ColorTheme.dark : ColorTheme.light,
        isDark ? DoTextTheme.dark : DoTextTheme.light,
        surfaces,
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
            letterSpacing: -0.2,
            color: scheme.onSurface,
          ),
          headlineLarge: TextStyle(
            fontSize: 30,
            height: 1.2,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
            color: scheme.onSurface,
          ),
          headlineMedium: TextStyle(
            fontSize: 26,
            height: 1.2,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
            color: scheme.onSurface,
          ),
          headlineSmall: TextStyle(
            fontSize: 22,
            height: 1.25,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
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
