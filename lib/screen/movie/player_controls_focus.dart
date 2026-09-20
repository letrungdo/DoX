import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A bar of player controls the D-pad can walk into and back out of.
///
/// Directional focus is decided by geometry, and the transport bar sits
/// *inside* the video's own focus node — so a television's remote has nothing
/// to walk onto: every control is within the rectangle it is trying to leave,
/// and pressing down from the video moves nothing at all. The way out is to
/// stop asking geometry: the video hands focus to this scope by name when the
/// remote presses towards it, and this hands it back when the remote presses
/// away again.
///
/// [exit] is the direction that leaves the bar — up out of the bar at the
/// bottom of the player, down out of the one at the top. Every other key is
/// left alone, so moving along the bar, and out of it the other way, stays
/// ordinary traversal.
class PlayerControlsFocus extends StatelessWidget {
  const PlayerControlsFocus({
    super.key,
    required this.node,
    required this.exit,
    required this.onExit,
    required this.child,
  });

  final FocusScopeNode node;
  final TraversalDirection exit;
  final VoidCallback onExit;
  final Widget child;

  static LogicalKeyboardKey _keyFor(TraversalDirection direction) =>
      switch (direction) {
        TraversalDirection.up => LogicalKeyboardKey.arrowUp,
        TraversalDirection.down => LogicalKeyboardKey.arrowDown,
        TraversalDirection.left => LogicalKeyboardKey.arrowLeft,
        TraversalDirection.right => LogicalKeyboardKey.arrowRight,
      };

  KeyEventResult _onKeyEvent(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey != _keyFor(exit)) return KeyEventResult.ignored;
    if (!node.hasFocus) return KeyEventResult.ignored;
    onExit();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    // Holds no focus of its own and is skipped by traversal: it is here to
    // read the keys its descendants did not use, nothing more.
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _onKeyEvent,
      child: FocusScope(node: node, child: child),
    );
  }
}

/// Puts the remote on a control inside [scope]: the one it was last on, or the
/// first one in the bar on a first visit.
///
/// Call it after the bar has been laid out — hidden controls are held out of
/// the focus tree, so a scope whose bar is not on screen yet has nothing to
/// give focus to.
void focusPlayerControls(FocusScopeNode scope) {
  final lastFocused = scope.focusedChild;
  if (lastFocused != null) {
    lastFocused.requestFocus();
    return;
  }
  // Walks to the first control in the scope; a scope with no focused child of
  // its own is where traversal starts from.
  scope.nextFocus();
}
