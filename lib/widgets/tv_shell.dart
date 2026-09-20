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
/// still falls through to Flutter's defaults. `NavigationMode.directional`
/// comes along for the ride: it is what Flutter documents for a television,
/// and it lets focus rest on a disabled control so the remote can read past it
/// instead of skipping it silently.
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
        navigationMode: NavigationMode.directional,
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
class _FocusOutline extends StatefulWidget {
  const _FocusOutline({required this.child});

  final Widget child;

  @override
  State<_FocusOutline> createState() => _FocusOutlineState();
}

class _FocusOutlineState extends State<_FocusOutline> {
  Rect? _rect;

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
    Rect? rect;
    // A scope node spans its whole page; outlining that says nothing.
    if (node != null && node is! FocusScopeNode && nodeContext != null) {
      final box = nodeContext.findRenderObject();
      if (box is RenderBox &&
          box.attached &&
          box.hasSize &&
          !_marksItself(nodeContext)) {
        rect = node.rect;
      }
    }
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
