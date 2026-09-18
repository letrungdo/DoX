import 'package:do_x/constants/dimens.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:flutter/material.dart';

/// Outlines whatever the D-pad is currently pointing at.
///
/// On a TV there is no pointer and no ripple under a finger, so the outline is
/// the *only* thing telling the user which control the remote will activate.
/// It is drawn as a foreground decoration, which takes no layout space, so a
/// control does not move when focus arrives.
///
/// On a touch device [focused] never becomes true — Flutter only reports a
/// focus highlight once the highlight mode is `traditional`, which the app
/// switches on for televisions only — so this costs a phone nothing.
class FocusRing extends StatelessWidget {
  const FocusRing({
    super.key,
    required this.focused,
    required this.child,
    this.radius = Dimens.radiusControl,
  });

  final bool focused;
  final Widget child;

  /// Match the corner of the surface being wrapped, or the ring cuts across it.
  final double radius;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          // Transparent rather than no border at all: a `Border.all` of width 0
          // would still be a different decoration to animate between, and the
          // constant width keeps the painted geometry identical either way.
          color: focused
              ? context.theme.colorScheme.primary
              : Colors.transparent,
          width: Dimens.focusRingWidth,
        ),
      ),
      child: child,
    );
  }
}

/// A tap target that a remote can reach.
///
/// The drop-in replacement for a bare [GestureDetector] whose `onTap` is a
/// real action: a `GestureDetector` has no focus node, so on a TV the D-pad
/// skips straight past it and the control becomes unreachable. This adds the
/// node, the ring and the select-key handling while leaving touch behaviour
/// exactly as it was.
class FocusableTap extends StatefulWidget {
  const FocusableTap({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.radius = Dimens.radiusControl,
    this.autofocus = false,
    this.focusNode,
    this.behavior = HitTestBehavior.opaque,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double radius;
  final bool autofocus;
  final FocusNode? focusNode;
  final HitTestBehavior behavior;

  bool get _enabled => onTap != null || onLongPress != null;

  @override
  State<FocusableTap> createState() => _FocusableTapState();
}

class _FocusableTapState extends State<FocusableTap> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      enabled: widget._enabled,
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      mouseCursor: widget._enabled
          ? SystemMouseCursors.click
          : MouseCursor.defer,
      onShowFocusHighlight: (value) {
        if (_focused != value) setState(() => _focused = value);
      },
      actions: {
        // The remote's OK button arrives as an `ActivateIntent`, the same
        // intent Enter and the space bar raise on a keyboard.
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onTap?.call();
            return null;
          },
        ),
      },
      child: GestureDetector(
        behavior: widget.behavior,
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: FocusRing(
          focused: _focused,
          radius: widget.radius,
          child: widget.child,
        ),
      ),
    );
  }
}
