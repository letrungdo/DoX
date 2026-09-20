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
/// paint a line just inside that one.
class FocusableTap extends StatelessWidget {
  const FocusableTap({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.autofocus = false,
    this.focusNode,
    this.behavior = HitTestBehavior.opaque,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool autofocus;
  final FocusNode? focusNode;
  final HitTestBehavior behavior;

  bool get _enabled => onTap != null || onLongPress != null;

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      enabled: _enabled,
      focusNode: focusNode,
      autofocus: autofocus,
      mouseCursor: _enabled ? SystemMouseCursors.click : MouseCursor.defer,
      actions: {
        // The remote's OK button arrives as an `ActivateIntent`, the same
        // intent Enter and the space bar raise on a keyboard.
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            onTap?.call();
            return null;
          },
        ),
      },
      child: GestureDetector(
        behavior: behavior,
        onTap: onTap,
        onLongPress: onLongPress,
        child: child,
      ),
    );
  }
}
