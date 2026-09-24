import 'package:do_x/utils/device_type.dart';
import 'package:flutter/material.dart';

/// A tap target that a remote can reach.
///
/// The drop-in replacement for a bare [GestureDetector] whose `onTap` is a real
/// action: a `GestureDetector` has no focus node, so on a TV the D-pad skips
/// straight past it and the control is unreachable. This adds the node and the
/// select-key handling while leaving touch behaviour exactly as it was.
///
/// It draws nothing. Showing which control the remote is on is `TvShell`'s job,
/// and it does it for the whole app at once — a second marker here would only
/// paint a line just inside that one. A control that wants a focused fill as
/// well passes [builder] instead of [child] and draws it itself. It never
/// grows the way `AppPressable` does: a rail whose rows grow jitters.
class FocusableTap extends StatefulWidget {
  const FocusableTap({
    super.key,
    this.child,
    this.builder,
    this.onTap,
    this.onLongPress,
    this.autofocus = false,
    this.focusNode,
    this.behavior = HitTestBehavior.opaque,
  }) : assert(
         (child == null) != (builder == null),
         'Pass exactly one of child and builder.',
       );

  final Widget? child;

  /// Draws the content knowing whether the remote rests on it. `focused` is
  /// only ever true on a television.
  final Widget Function(BuildContext context, bool focused)? builder;

  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool autofocus;
  final FocusNode? focusNode;
  final HitTestBehavior behavior;

  @override
  State<FocusableTap> createState() => _FocusableTapState();
}

class _FocusableTapState extends State<FocusableTap> {
  bool _focused = false;

  bool get _enabled => widget.onTap != null || widget.onLongPress != null;

  void _onFocusHighlight(bool value) {
    if (_focused == value || !mounted) return;
    setState(() => _focused = value);
  }

  @override
  Widget build(BuildContext context) {
    final builder = widget.builder;
    return FocusableActionDetector(
      enabled: _enabled,
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      mouseCursor: _enabled ? SystemMouseCursors.click : MouseCursor.defer,
      // Only listened to when something draws it, and only on a television —
      // elsewhere a mouse or a finger leaves focus behind on controls it has
      // merely touched.
      onShowFocusHighlight: builder != null && deviceType.isTv
          ? _onFocusHighlight
          : null,
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
        child: builder?.call(context, _focused) ?? widget.child,
      ),
    );
  }
}
