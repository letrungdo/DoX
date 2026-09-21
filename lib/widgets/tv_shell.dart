import 'dart:async';

import 'package:collection/collection.dart';
import 'package:do_x/constants/dimens.dart';
import 'package:do_x/utils/device_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

/// Everything the app does differently because it is running on a television.
///
/// Wraps the whole navigator once, rather than being sprinkled through the
/// pages, and is a pass-through on every other device — so a phone build
/// carries none of it.
///
/// Two things happen here:
///
/// * **Text size.** Everything in the app is sized for a phone at arm's
///   length. A television is read from a sofa, so the whole app is scaled up
///   from here rather than every size being chosen a second time.
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
        // Clamped rather than set: the app's sizes are chosen for a phone at
        // arm's length and are too small to read from a sofa, but a viewer
        // who has already turned their television's text up wants that, not
        // that multiplied by this.
        textScaler: media.textScaler.clamp(minScaleFactor: Dimens.tvTextScale),
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
          child: Actions(
            actions: <Type, Action<Intent>>{
              DirectionalFocusIntent: _DirectionalFocusOrScrollAction(),
            },
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Moves the remote, and scrolls the page when there is nowhere to move it.
///
/// A phone scrolls under a finger wherever the finger lands. A television has
/// only the focus, so a page scrolls exactly as far as its last focusable
/// control and no further — and anything printed below that, a card of
/// details under a calendar, is on the page but out of reach for good.
///
/// So when the arrow finds nothing to move to, it scrolls instead. Only then:
/// while there is another control in that direction, going to it is what the
/// viewer meant, and the scrolling that brings it into view happens anyway.
/// Marks the page a control belongs to, so the remote can be kept inside it.
///
/// `AppScaffold` puts one of these around every page, which nests: the tab
/// host is a page whose body holds the rail *and* whichever page is on
/// screen, and that page brings its own. So the nearest one above a control
/// tells the rail apart from the page beside it.
class TvPageArea extends InheritedWidget {
  const TvPageArea({super.key, required super.child});

  /// The page [context] sits in, or null for anything outside one — a
  /// full-screen player, a dialog, the app before a page is built.
  ///
  /// The element, not the widget. A widget is rebuilt into a new instance
  /// whenever anything above it changes, so comparing those says two
  /// controls are on different pages every time the page redraws — which
  /// stopped the remote moving inside the tab rail at all. The element is
  /// the same object for as long as the page is on screen.
  static Element? of(BuildContext? context) {
    if (context == null || !context.mounted) return null;
    return context.getElementForInheritedWidgetOfExactType<TvPageArea>();
  }

  @override
  bool updateShouldNotify(TvPageArea oldWidget) => false;
}

class _DirectionalFocusOrScrollAction extends Action<DirectionalFocusIntent> {
  /// How far one press carries the page when it is scrolling rather than
  /// moving the focus. A little over half a screen: enough to be worth the
  /// press, little enough to keep a line of sight on what was already read.
  static const _pageFraction = 0.6;

  static const _duration = Duration(milliseconds: 220);

  @override
  Object? invoke(DirectionalFocusIntent intent) {
    final node = FocusManager.instance.primaryFocus;
    if (node == null) return null;

    final from = TvPageArea.of(node.context);
    if (!node.focusInDirection(intent.direction)) {
      _scroll(node.context, intent.direction);
      return null;
    }
    if (from == null || !_isVertical(intent.direction)) return null;

    // Where the focus went is only known after the manager has applied it,
    // which it does on a microtask — before any of it is drawn, so putting
    // it back here costs nothing on screen.
    scheduleMicrotask(() => _keepInsidePage(node, from, intent.direction));
    return null;
  }

  /// Puts the remote back and scrolls, if the arrow took it off the page.
  ///
  /// Up and down belong to the page: a page whose lower half holds nothing
  /// pressable has the tab rail as the nearest thing below its last control,
  /// so pressing down there threw the remote sideways into the rail — and
  /// the page, having never run out of places to send the focus, never
  /// scrolled. Leaving the page is what left and right are for.
  void _keepInsidePage(
    FocusNode node,
    Element from,
    TraversalDirection direction,
  ) {
    final landed = FocusManager.instance.primaryFocus;
    if (landed == null || identical(TvPageArea.of(landed.context), from)) {
      return;
    }
    node.requestFocus();
    _scroll(node.context, direction);
  }

  static bool _isVertical(TraversalDirection direction) =>
      direction == TraversalDirection.up ||
      direction == TraversalDirection.down;

  void _scroll(BuildContext? context, TraversalDirection direction) {
    if (context == null || !context.mounted) return;
    final forward = switch (direction) {
      TraversalDirection.down => true,
      TraversalDirection.up => false,
      // Sideways is for the rail and for a row of chips, both of which have
      // their own controls to move between. Nothing here to scroll.
      TraversalDirection.left || TraversalDirection.right => null,
    };
    if (forward == null) return;

    final position = _pageScrollPosition(context);
    if (position == null) return;

    final step = position.viewportDimension * _pageFraction;
    final target = (position.pixels + (forward ? step : -step)).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if ((target - position.pixels).abs() < 1) return;

    position.animateTo(target, duration: _duration, curve: Curves.easeOutCubic);
  }

  /// The list this page is read by scrolling.
  ///
  /// Usually the one the focused control sits in, and looking up the tree
  /// finds it. But the control need not be inside it at all — the remote can
  /// be on the app bar, or over on the tab rail — and then the page has to be
  /// searched from the top down instead.
  ScrollPosition? _pageScrollPosition(BuildContext context) {
    final enclosing = Scrollable.maybeOf(
      context,
      axis: Axis.vertical,
    )?.position;
    if (_canScroll(enclosing)) return enclosing;

    final page = TvPageArea.of(context);
    if (page == null) return null;
    return _firstScrollableIn(page);
  }

  /// Whether [position] has anywhere to go.
  ///
  /// A list that fits its viewport is still a list, and stopping at the first
  /// one found would mean the tab rail — which is scrollable, and never has
  /// to scroll — answering for the page beside it.
  bool _canScroll(ScrollPosition? position) =>
      position != null &&
      position.hasContentDimensions &&
      position.maxScrollExtent > 0;

  /// Searches [element]'s subtree for the page's own list.
  ///
  /// Downwards, which the framework has no api for — `Scrollable.of` only
  /// looks up. Walking the elements is the way to ask the question, and this
  /// only runs on a press that had nowhere else to go.
  ScrollPosition? _firstScrollableIn(Element element) {
    ScrollPosition? found;
    void visit(Element child) {
      if (found != null) return;
      if (child is StatefulElement && child.state is ScrollableState) {
        final position = (child.state as ScrollableState).position;
        if (position.axis == Axis.vertical && _canScroll(position)) {
          found = position;
          return;
        }
      }
      child.visitChildren(visit);
    }

    element.visitChildren(visit);
    return found;
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

  /// How many more frames the outline re-measures itself for.
  ///
  /// The control the remote lands on grows into place rather than snapping,
  /// so a single measurement taken the moment focus moves is of a card that
  /// has not finished arriving. Following it for the length of that animation
  /// is what keeps the ring on the card instead of inside it.
  ///
  /// Counted in frames rather than against the clock: a widget test runs on
  /// its own time, where a wall-clock deadline is never reached and the
  /// frames this asks for never stop coming.
  int _settleFrames = 0;

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
    final wasSettling = _settleFrames > 0;
    _settleFrames = _settleFrameCount;
    if (!wasSettling) _measureNextFrame();
  }

  /// A little longer than the lift itself, so the last frame of it is caught.
  static const _settleFrameCount = 12;

  void _measureNextFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _measure();
      if (--_settleFrames <= 0) return;
      _measureNextFrame();
      // The control is animating, so frames are being produced anyway — but
      // not once it settles, and a post-frame callback waiting for a frame
      // nobody asks for never runs. Asking costs a few idle frames per focus
      // move and is what makes the last measurement the one that lands.
      SchedulerBinding.instance.scheduleFrame();
    });
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
          // Where the control is *painted*, not where it was laid out. On a
          // television the focused control is drawn larger than its slot, and
          // `FocusNode.rect` reports the slot — an outline traced on that sits
          // inside the card it is meant to be around.
          rect = MatrixUtils.transformRect(
            box.getTransformTo(null),
            Offset.zero & box.size,
          );
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
