import 'package:do_x/constants/dimens.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/widgets/surface/app_pressable.dart';
import 'package:do_x/widgets/surface/surface_scope.dart';
import 'package:flutter/material.dart';

/// Flat card — the replacement for [Card] across the app.
///
/// Keeps a Card-shaped API (`child`, `color`, `margin`, `clipBehavior`) so call
/// sites read the same, but draws no elevation, shadow or outline: the card is
/// found by its fill, one opaque step off whatever it sits on (see
/// `SurfaceTheme.panelOn`). When [onTap] is given, a press lays the state layer
/// over that fill and shrinks the card a touch.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    this.child,
    this.color,
    this.margin,
    this.padding,
    this.radius = Dimens.radiusCard,
    this.depth = 1,
    this.onTap,
    this.onLongPress,
    this.clipBehavior = Clip.antiAlias,
    this.focusNode,
  });

  final Widget? child;
  final FocusNode? focusNode;

  /// Fill that replaces the shared surface colour, for cards that carry a
  /// semantic tint (`colors.successSoft` and friends) or a selection
  /// (`surfaces.primarySoft`). The tint is the card's edge; no border is added.
  final Color? color;

  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final double radius;

  /// Ignored; kept for source compatibility.
  final double depth;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Clip clipBehavior;

  bool get _tappable => onTap != null || onLongPress != null;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final borderRadius = BorderRadius.circular(radius);
    // What this card is drawn on: an untinted card takes the next fill step
    // off it, so one nested in a card or a sheet still stands out from it.
    final background = SurfaceScope.of(context);
    final fill = color ?? surfaces.panelOn(background);

    Widget? content = child;
    if (padding != null) {
      content = Padding(padding: padding!, child: content);
    }
    // Always a Material, even without a tap handler of our own: children often
    // bring their own InkWell/ListTile, and without one here their ink lands on
    // the nearest ancestor Material — behind this card's opaque fill, so the
    // highlight is invisible and unclipped by the rounded corners.
    content = Material(
      type: MaterialType.transparency,
      borderRadius: borderRadius,
      clipBehavior: Clip.antiAlias,
      child: content,
    );
    // Cards nested in this one sit on its fill, not on the scaffold.
    content = SurfaceScope(color: fill, child: content);

    Widget panel(AppPressState state) => AnimatedContainer(
      duration: AppPressable.duration,
      curve: Curves.easeOut,
      margin: margin,
      clipBehavior: clipBehavior,
      decoration: BoxDecoration(
        color: surfaces.stateFill(
          fill,
          content: context.theme.colorScheme.onSurface,
          pressed: state.pressed,
          focused: state.focused,
        ),
        borderRadius: borderRadius,
      ),
      child: content,
    );

    if (!_tappable) {
      return panel(const AppPressState(pressed: false, focused: false));
    }

    return AppPressable(
      pressedScale: Dimens.pressedScaleCard,
      focusNode: focusNode,
      onTap: onTap,
      onLongPress: onLongPress,
      stateBuilder: (context, state) => panel(state),
    );
  }
}
