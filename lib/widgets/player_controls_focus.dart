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
/// bottom of the player, down out of the one at the top. Even that key belongs
/// to the bar first: a bar with a control stacked above another has somewhere
/// to go in that direction, and only the control at its edge leaves. Every
/// other key is left alone, so moving along the bar stays ordinary traversal.
///
/// The other way out is left to traversal, which needs help of its own: a
/// scope stops directional focus at its edge by default, so an inline player
/// would trap the remote in the transport bar with the episode list right
/// underneath it. The scope is told to carry the search on into the scope
/// around it instead.
class PlayerControlsFocus extends StatefulWidget {
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

  @override
  State<PlayerControlsFocus> createState() => _PlayerControlsFocusState();
}

class _PlayerControlsFocusState extends State<PlayerControlsFocus> {
  @override
  void initState() {
    super.initState();
    _letTheSearchOut();
  }

  @override
  void didUpdateWidget(PlayerControlsFocus oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.node != widget.node) _letTheSearchOut();
  }

  void _letTheSearchOut() {
    widget.node.directionalTraversalEdgeBehavior =
        TraversalEdgeBehavior.parentScope;
  }

  static LogicalKeyboardKey _keyFor(TraversalDirection direction) =>
      switch (direction) {
        TraversalDirection.up => LogicalKeyboardKey.arrowUp,
        TraversalDirection.down => LogicalKeyboardKey.arrowDown,
        TraversalDirection.left => LogicalKeyboardKey.arrowLeft,
        TraversalDirection.right => LogicalKeyboardKey.arrowRight,
      };

  KeyEventResult _onKeyEvent(FocusNode _, KeyEvent event) {
    final node = widget.node;
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey != _keyFor(widget.exit)) {
      return KeyEventResult.ignored;
    }
    if (!node.hasFocus) return KeyEventResult.ignored;

    // Inside the bar first. Traversal from a control only ever considers the
    // controls of its own scope, so this moves along the bar where there is
    // somewhere to go and answers false at its edge — which is the press that
    // means "leave".
    final focused = FocusManager.instance.primaryFocus;
    if (focused != null &&
        focused != node &&
        focused.focusInDirection(widget.exit)) {
      return KeyEventResult.handled;
    }

    widget.onExit();
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
      child: FocusScope(node: widget.node, child: widget.child),
    );
  }
}

/// Puts the remote on a control inside [scope]: the one it was last on, the
/// [preferred] one on a first visit, or the first one in the bar.
///
/// [preferred] is the control the press was aiming at — the play button for a
/// press towards the middle of the picture, the back button for one towards
/// the top — so a bar the remote has never visited opens on something useful
/// rather than on whatever happens to come first in reading order.
///
/// Call it after the bar has been laid out — hidden controls are held out of
/// the focus tree, so a scope whose bar is not on screen yet has nothing to
/// give focus to, and this leaves the remote where it was.
void focusPlayerControls(FocusScopeNode scope, {FocusNode? preferred}) {
  final lastFocused = scope.focusedChild ?? preferred;
  // A control the bar no longer draws — the bar is laid out differently when
  // the player is narrow, or in a window rather than full screen — is gone
  // from the tree and cannot be focused again.
  if (lastFocused != null &&
      lastFocused.context != null &&
      lastFocused.canRequestFocus) {
    lastFocused.requestFocus();
    return;
  }
  // Walks to the first control in the scope; a scope with no focused child of
  // its own is where traversal starts from.
  scope.nextFocus();
}
