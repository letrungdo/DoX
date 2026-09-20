import 'dart:async';

import 'package:collection/collection.dart';
import 'package:do_x/constants/dimens.dart';
import 'package:do_x/utils/device_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Everything the app does differently because it is running on a television.
///
/// Wraps the whole navigator once, rather than being sprinkled through the
/// pages, and is a pass-through on every other device — so a phone build
/// carries none of it.
///
/// Two things happen here:
///
/// * **Overscan.** A TV can crop the outer few percent of the picture, and the
///   panel has no notch for the system to report, so the padding has to be
///   invented. Injecting it into [MediaQuery] means every `SafeArea` already in
///   the app — `AppScaffold`, dialogs, sheets — keeps its content inside the
///   visible area without any of them knowing about televisions.
/// * **Getting back out of a text field.** `EditableText` binds
///   `DirectionalFocusAction.forTextField()`, which drops any arrow key whose
///   intent has `ignoreTextFields` set — and every arrow in `WidgetsApp`'s
///   default map has it set, so the keys are free to move the caret instead.
///   On a desktop that is right. On a TV it is a trap with no way out: the
///   D-pad walks into the first field of the login form and stays there, with
///   no other field, no submit button and no tab bar ever reachable again.
///   Re-binding the four arrows to the same intent with the flag cleared is
///   what frees them; the caret is not lost with it, because Android TV edits
///   text in its own full-screen IME rather than in place.
/// * **The OK button.** Depending on the remote it arrives as `select` or as a
///   game-pad button rather than as `enter`, neither of which the default
///   shortcut map turns into an activation.
///
/// This sits below `WidgetsApp`'s own `Shortcuts`, and a key walks up from the
/// focused node, so these bindings are found first and anything not listed
/// still falls through to Flutter's defaults.
///
/// Deliberately *not* `NavigationMode.directional`, whatever the framework
/// documentation suggests for a television. It does not free the arrows from a
/// text field — that is the flag on the intent, above — and the one thing it
/// does do is make every `InkWell` focusable whether or not it has an `onTap`.
/// A settings row is a `ListTile` with no tap handler wrapping a dropdown, so
/// the remote stopped on the whole row and OK did nothing, with the control it
/// was meant to reach sitting inside.
class TvShell extends StatelessWidget {
  const TvShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!deviceType.isTv) return child;

    final media = MediaQuery.of(context);
    return MediaQuery(
      data: media.copyWith(
        padding: media.padding + Dimens.tvOverscan,
        viewPadding: media.viewPadding + Dimens.tvOverscan,
      ),
      child: _FocusOutline(
        child: Shortcuts(
          shortcuts: const <ShortcutActivator, Intent>{
            SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
            SingleActivator(LogicalKeyboardKey.gameButtonA): ActivateIntent(),
            SingleActivator(LogicalKeyboardKey.arrowUp): DirectionalFocusIntent(
              TraversalDirection.up,
              ignoreTextFields: false,
            ),
            SingleActivator(
              LogicalKeyboardKey.arrowDown,
            ): DirectionalFocusIntent(
              TraversalDirection.down,
              ignoreTextFields: false,
            ),
            SingleActivator(
              LogicalKeyboardKey.arrowLeft,
            ): DirectionalFocusIntent(
              TraversalDirection.left,
              ignoreTextFields: false,
            ),
            SingleActivator(
              LogicalKeyboardKey.arrowRight,
            ): DirectionalFocusIntent(
              TraversalDirection.right,
              ignoreTextFields: false,
            ),
          },
          child: child,
        ),
      ),
    );
  }
}

/// Draws one outline around whatever the remote is pointing at, over the whole
/// app.
///
/// A television has no cursor and no finger, so seeing the control is the only
/// way to know what OK will press — and a phone app has nothing that says so.
/// Marking each widget in turn would mean touching every screen and would still
/// miss the ones built out of plain text and images, so the outline is painted
/// once at the root from [FocusManager] and works for controls nobody has
/// thought about yet.
/// Marks a focusable area that holds the remote without being a control: the
/// picture a player parks it on while the transport bar is hidden.
///
/// [TvShell]'s outline skips exactly this node — a ring traced around the whole
/// picture says nothing about where the remote is, and on a full-screen player
/// it reads as a coloured border around the television itself. The controls
/// inside the area are outlined as usual; only the node named here is passed
/// over.
class TvFocusSurface extends StatelessWidget {
  const TvFocusSurface({super.key, required this.node, required this.child});

  /// The focus node of the surface itself, so a control that happens to sit
  /// inside it is still told apart from it.
  final FocusNode node;

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

class _FocusOutline extends StatefulWidget {
  const _FocusOutline({required this.child});

  final Widget child;

  @override
  State<_FocusOutline> createState() => _FocusOutlineState();
}

class _FocusOutlineState extends State<_FocusOutline> {
  Rect? _rect;
  bool _hadControl = false;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_scheduleMeasure);
    _scheduleMeasure();
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_scheduleMeasure);
    super.dispose();
  }

  /// Measured after the frame rather than during it: the widget that has just
  /// taken focus is usually built by that very frame, so there is nothing laid
  /// out to measure until it ends.
  void _scheduleMeasure() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  void _measure() {
    if (!mounted) return;
    final node = FocusManager.instance.primaryFocus;
    final nodeContext = node?.context;
    // Whether the remote is on a control at all, which is *not* the same as
    // whether one is outlined: a text field is a control the outline stays off.
    // Reading the outline instead of this left the field submitting from the
    // on-screen keyboard — the one way a TV signs in — outside the rescue.
    var onAControl = false;
    Rect? rect;
    // A scope node spans its whole page; outlining that says nothing.
    if (node != null && node is! FocusScopeNode && nodeContext != null) {
      final box = nodeContext.findRenderObject();
      if (box is RenderBox && box.attached && box.hasSize) {
        onAControl = true;
        if (!_marksItself(nodeContext) && !_isSurface(node, nodeContext)) {
          rect = node.rect;
        }
      }
    }
    // The remote was on something and that something is gone — logging in
    // replaces the page under it, switching tabs takes the old one out of the
    // focus tree. Focus falls back to a scope, no arrow key finds anything from
    // there, and the remote is dead for the rest of the session. Put it back on
    // the page. Only when focus is *lost*, never at launch: forcing focus onto
    // whatever a page happens to start with would open the on-screen keyboard
    // on any page whose first control is a text field.
    if (!onAControl && _hadControl) _rescueOrphanedRemote();
    _hadControl = onAControl;
    if (rect != _rect) setState(() => _rect = rect);
  }

  /// Whether the focused widget already says it has the focus on its own.
  ///
  /// A text field does: its outline thickens and turns to the primary colour,
  /// and the label lifts into the notch. Adding this outline as well draws a
  /// second line just inside the first, which reads as a rendering mistake
  /// rather than as emphasis — and the field's own cue is the better of the
  /// two anyway, because it also fits the field's shape.
  bool _marksItself(BuildContext context) {
    return context.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  /// Whether the focus is on a [TvFocusSurface] rather than on a control.
  ///
  /// Matched by node, not by ancestry: a player's controls are built *inside*
  /// the picture they float over, so anything looser would take the outline
  /// off the buttons too — the one place a television needs it most.
  bool _isSurface(FocusNode node, BuildContext context) {
    final surface = context.findAncestorWidgetOfExactType<TvFocusSurface>();
    return surface != null && identical(surface.node, node);
  }

  void _rescueOrphanedRemote() {
    // Deliberately late, and deliberately *not* another post-frame callback:
    // this runs from inside one, and a post-frame callback registered there
    // waits for a frame that nothing is going to ask for. A microtask still
    // runs after every other post-frame callback of this frame, which is what
    // the delay is for — losing focus and wanting it somewhere are often the
    // same event (opening the movie server's URL row removes the button that
    // had the focus and asks the field to take it), and this is the last
    // resort, so it has to let that happen first.
    scheduleMicrotask(() {
      if (!mounted) return;
      final current = FocusManager.instance.primaryFocus;
      if (current != null && current is! FocusScopeNode) return;

      final scope = current is FocusScopeNode
          ? current
          : FocusManager.instance.rootScope;
      // Routes that something covers are already excluded from this, so the
      // first one is a control on the page actually in front of the user.
      scope.traversalDescendants.firstOrNull?.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final rect = _rect;
    return NotificationListener<ScrollNotification>(
      // Focus does not change while a list scrolls, but the row it rests on
      // moves under it, so without this the outline is left behind.
      onNotification: (_) {
        _scheduleMeasure();
        return false;
      },
      child: Stack(
        textDirection: TextDirection.ltr,
        fit: StackFit.expand,
        children: [
          widget.child,
          if (rect != null && !rect.isEmpty)
            Positioned.fromRect(
              rect: rect.inflate(Dimens.focusOutlineGap),
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(Dimens.radiusControl),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary,
                      width: Dimens.focusRingWidth,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
