import 'package:do_x/constants/dimens.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/widgets/loading.dart';
import 'package:do_x/widgets/surface/app_pressable.dart';
import 'package:do_x/widgets/surface/surface_scope.dart';
import 'package:flutter/material.dart';

/// A flat button: an opaque fill, a state layer while held, no shadow.
///
/// Without [accent] it is the neutral button — the next fill step off whatever
/// it sits on (white on the page, a nested grey in a dialog). [accent] fills it
/// for a primary or destructive action; `accent: surfaces.primarySoft` with
/// `foreground: scheme.primary` makes the tonal variant.
class AppButton extends StatefulWidget {
  const AppButton({
    super.key,
    required this.child,
    this.onPressed,
    this.accent,
    this.foreground,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    this.radius = Dimens.radiusControl,
    this.depth = 0.85,
    this.expand = false,
    this.focusNode,
  });

  final Widget child;
  final VoidCallback? onPressed;

  /// Fill for primary actions. `null` keeps the shared surface colour.
  final Color? accent;

  /// Label/icon colour. Defaults to what reads on [accent] (or on the surface
  /// when there is none) — pass it when the accent is not the primary colour,
  /// e.g. a destructive action filled with `scheme.error`.
  final Color? foreground;

  final EdgeInsetsGeometry padding;
  final double radius;

  /// Ignored; kept for source compatibility.
  final double depth;

  /// Stretch to the parent's width, for bottom-of-sheet actions.
  final bool expand;

  /// Lets a caller put the TV remote on this button.
  final FocusNode? focusNode;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  /// Press layer on a primary or error fill, where the theme's 10% is too
  /// faint to read.
  static const _saturatedPressOpacity = 0.12;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final scheme = context.theme.colorScheme;
    final enabled = widget.onPressed != null;
    final borderRadius = BorderRadius.circular(widget.radius);
    final background = SurfaceScope.of(context);
    final fill = widget.accent ?? surfaces.panelOn(background);
    final foreground = !enabled
        ? context.colors.disabled
        : widget.foreground ??
              (widget.accent == null ? scheme.onSurface : scheme.onPrimary);

    Widget content = DefaultTextStyle.merge(
      style: TextStyle(
        color: foreground,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      child: IconTheme.merge(
        data: IconThemeData(color: foreground, size: 20),
        child: Padding(padding: widget.padding, child: widget.child),
      ),
    );

    // A saturated fill needs a slightly stronger press layer to show.
    final saturated =
        widget.accent == scheme.primary || widget.accent == scheme.error;

    final button = AppPressable(
      focusNode: widget.focusNode,
      onTap: widget.onPressed,
      stateBuilder: (context, state) => AnimatedContainer(
        duration: AppPressable.duration,
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: enabled
              ? surfaces.stateFill(
                  fill,
                  content: foreground,
                  pressed: state.pressed,
                  focused: state.focused,
                  pressOpacity: saturated ? _saturatedPressOpacity : null,
                )
              : surfaces.sunken,
          borderRadius: borderRadius,
        ),
        child: content,
      ),
    );

    return widget.expand
        ? SizedBox(width: double.infinity, child: button)
        : button;
  }
}

/// Square flat icon button, for app bar actions and toolbars. A neutral
/// [AppButton] underneath: a white (or slate) rounded square on the page, a
/// nested grey one inside a card or sheet.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.size = Dimens.iconButtonSize,
    this.iconSize = 20,
    this.color,
    this.tooltip,
    this.depth = 0.6,
    this.focusNode,
    this.loading = false,
  });

  final IconData icon;

  /// Shows a spinner, the icon's size, in the icon's place. The button
  /// stays what it was, pressable or not.
  final bool loading;
  final VoidCallback? onPressed;
  final double size;
  final double iconSize;
  final Color? color;
  final String? tooltip;
  final FocusNode? focusNode;

  /// Ignored; kept for source compatibility.
  final double depth;

  @override
  Widget build(BuildContext context) {
    final button = AppButton(
      onPressed: onPressed,
      radius: Dimens.radiusControlSmall,
      padding: EdgeInsets.zero,
      focusNode: focusNode,
      child: SizedBox.square(
        dimension: size,
        child: Center(
          child: loading
              ? Loading(size: iconSize)
              : Icon(
                  icon,
                  size: iconSize,
                  // Greyed out with the rest of the button when it is
                  // disabled.
                  color: onPressed == null
                      ? context.colors.disabled
                      : color ?? context.colors.iconColor,
                ),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}
