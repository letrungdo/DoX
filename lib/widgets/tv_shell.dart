import 'dart:async';

import 'package:collection/collection.dart';
import 'package:do_x/constants/dimens.dart';
import 'package:do_x/utils/device_type.dart';
import 'package:flutter/foundation.dart';
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
    scheduleMicrotask(() {
      if (_keepInsidePage(node, from, intent.direction)) return;
      _takeSkippedRow(node, intent.direction);
    });
    return null;
  }

  /// Puts the remote on a control the arrow jumped over, if it jumped one.
  ///
  /// The framework only looks straight down (or up) the column the remote is
  /// in, and goes further only when nothing at all is there. So from a
  /// narrow control on the left — the news card's "details" toggle — down
  /// passed over the small button at the right end of the heading below and
  /// landed on the list under it: the button was on screen, one row down,
  /// and down never reached it.
  ///
  /// A control lying wholly between where the remote was and where it went
  /// is the row the viewer meant. Only one in the same list as both, so a
  /// panel beside the list — the music player's buttons — is still left to
  /// left and right.
  void _takeSkippedRow(FocusNode node, TraversalDirection direction) {
    final landed = FocusManager.instance.primaryFocus;
    final context = node.context;
    final landedContext = landed?.context;
    if (landed == null ||
        identical(landed, node) ||
        context == null ||
        !context.mounted ||
        landedContext == null) {
      return;
    }
    final scrollable = Scrollable.maybeOf(context, axis: Axis.vertical);
    if (Scrollable.maybeOf(landedContext, axis: Axis.vertical) != scrollable) {
      return;
    }
    final page = TvPageArea.of(context);
    final down = direction == TraversalDirection.down;
    final from = node.rect;
    final to = landed.rect;
    // Past the one edge, short of the other: a row of its own in between.
    bool between(Rect rect) => down
        ? rect.top >= from.bottom && rect.bottom <= to.top
        : rect.bottom <= from.top && rect.top >= to.bottom;

    final scope = node.nearestScope;
    if (scope == null) return;
    final skipped = scope.traversalDescendants.where((candidate) {
      if (candidate is FocusScopeNode ||
          identical(candidate, node) ||
          identical(candidate, landed)) {
        return false;
      }
      final candidateContext = candidate.context;
      if (candidateContext == null || !candidateContext.mounted) return false;
      if (!identical(TvPageArea.of(candidateContext), page)) return false;
      if (Scrollable.maybeOf(candidateContext, axis: Axis.vertical) !=
          scrollable) {
        return false;
      }
      return between(candidate.rect);
    }).toList();
    if (skipped.isEmpty) return;

    // The nearest row, and in it the control nearest the remote's column.
    final centre = from.center;
    skipped.sort((a, b) {
      final vertical = (a.rect.center.dy - centre.dy).abs().compareTo(
        (b.rect.center.dy - centre.dy).abs(),
      );
      if (vertical != 0) return vertical;
      return (a.rect.center.dx - centre.dx).abs().compareTo(
        (b.rect.center.dx - centre.dx).abs(),
      );
    });
    skipped.first.requestFocus();
  }

  /// Puts the remote back and scrolls, if the arrow took it off the page.
  ///
  /// Up and down belong to the page: a page whose lower half holds nothing
  /// pressable has the tab rail as the nearest thing below its last control,
  /// so pressing down there threw the remote sideways into the rail — and
  /// the page, having never run out of places to send the focus, never
  /// scrolled. Leaving the page is what left and right are for.
  ///
  /// True when it put the remote back.
  bool _keepInsidePage(
    FocusNode node,
    Element from,
    TraversalDirection direction,
  ) {
    final landed = FocusManager.instance.primaryFocus;
    if (landed == null || identical(TvPageArea.of(landed.context), from)) {
      return false;
    }
    node.requestFocus();
    _scroll(node.context, direction);
    return true;
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
  bool _hadControl = false;

  /// What the ring is drawn around, looked up when the focus moves.
  ///
  /// The lookup walks the element tree, which is only safe between frames —
  /// so it is done here and the painter is left with render objects it can
  /// simply ask where they are now.
  final ValueNotifier<_FocusTarget?> _target = ValueNotifier<_FocusTarget?>(
    null,
  );

  /// Bumped whenever the control may have moved under the ring: a list
  /// scrolling, or the lift growing the card into place.
  final ValueNotifier<int> _tick = ValueNotifier<int>(0);

  /// How many more frames the ring follows the control for.
  ///
  /// The control the remote lands on grows into place rather than snapping,
  /// so a ring drawn once, the moment focus moves, is around a card that has
  /// not finished arriving.
  ///
  /// Counted in frames rather than against the clock: a widget test runs on
  /// its own time, where a wall-clock deadline is never reached and the frames
  /// this asks for never stop coming.
  int _settleFrames = 0;

  /// A little longer than the lift itself, so the last frame of it is caught.
  static const _settleFrameCount = 12;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_onFocusChange);
    _onFocusChange();
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_onFocusChange);
    _target.dispose();
    _tick.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    _follow();
    // After the frame: the widget that has just taken the focus is usually
    // built by that very frame, so there is nothing attached to look up until
    // it ends.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _target.value = _focusTarget();
      _rescueIfOrphaned();
    });
  }

  /// Asks for a repaint now, and for the frames the lift takes to settle.
  void _follow() {
    _tick.value++;
    final wasSettling = _settleFrames > 0;
    _settleFrames = _settleFrameCount;
    if (!wasSettling) _followNextFrame();
  }

  void _followNextFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _tick.value++;
      if (--_settleFrames <= 0) return;
      _followNextFrame();
      // The control is animating, so frames are being produced anyway — but
      // not once it settles, and a post-frame callback waiting for a frame
      // nobody asks for never runs. Asking costs a few idle frames per focus
      // move and is what puts the ring on the card's final size.
      SchedulerBinding.instance.scheduleFrame();
    });
  }

  /// Puts the remote back on the page when whatever held it has gone.
  void _rescueIfOrphaned() {
    // Whether the remote is on a control at all, which is *not* the same as
    // whether one is outlined: a text field is a control the ring stays off.
    // Reading the ring instead of this left the field submitting from the
    // on-screen keyboard — the one way a TV signs in — outside the rescue.
    final onAControl = _focusedBox() != null;
    // Logging in replaces the page under the remote; switching tabs takes the
    // old one out of the focus tree. Focus falls back to a scope, no arrow key
    // finds anything from there, and the remote is dead for the rest of the
    // session. Only when focus is *lost*, never at launch: forcing it onto
    // whatever a page happens to start with would open the on-screen keyboard
    // on any page whose first control is a text field.
    if (!onAControl && _hadControl) _rescueOrphanedRemote();
    _hadControl = onAControl;
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
    return NotificationListener<ScrollNotification>(
      // Focus does not change while a list scrolls, but the row it rests on
      // moves under it, so without this the ring is left behind.
      onNotification: (_) {
        _follow();
        return false;
      },
      child: Stack(
        textDirection: TextDirection.ltr,
        fit: StackFit.expand,
        children: [
          widget.child,
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _FocusOutlinePainter(
                  color: Theme.of(context).colorScheme.primary,
                  target: _target,
                  repaint: Listenable.merge([_target, _tick]),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// What the ring is drawn around: the focused control, and the lists it
/// scrolls inside.
///
/// Render objects rather than contexts, because the painter asks them where
/// they are while it paints — and walking the element tree then is not
/// allowed.
class _FocusTarget {
  const _FocusTarget({
    required this.box,
    required this.verticalViewport,
    required this.horizontalViewport,
  });

  final RenderBox box;

  /// The list the control scrolls up and down in, if it is in one.
  final RenderBox? verticalViewport;

  /// The row it scrolls left and right in, if it is in one.
  final RenderBox? horizontalViewport;
}

/// The focused control's box, or null when the remote is not on one.
///
/// A scope node spans its whole page, and a node whose widget has gone has
/// nothing to measure — neither is a control.
RenderBox? _focusedBox() {
  final context = FocusManager.instance.primaryFocus?.context;
  final node = FocusManager.instance.primaryFocus;
  if (node == null || node is FocusScopeNode || context == null) return null;
  // If the node can no longer request focus (e.g. it's inside an ExcludeFocus
  // because an overlay is opening), stop drawing the ring. This prevents
  // the border from lingering on covered cards during animations.
  if (!node.canRequestFocus) return null;
  if (!context.mounted) return null;
  final box = context.findRenderObject();
  if (box is! RenderBox || !box.attached || !box.hasSize) return null;
  return box;
}

/// What the ring should be drawn around right now, or null for nothing.
_FocusTarget? _focusTarget() {
  // Only a television draws one: everywhere else the remote does not exist
  // and the platform marks focus its own way.
  if (!deviceType.isTv) return null;
  final box = _focusedBox();
  final node = FocusManager.instance.primaryFocus;
  final context = node?.context;
  if (box == null || node == null || context == null) return null;
  if (_marksItself(context) || _isSurface(node, context)) return null;

  RenderBox? vertical;
  RenderBox? horizontal;
  context.visitAncestorElements((element) {
    if (element is StatefulElement && element.state is ScrollableState) {
      final state = element.state as ScrollableState;
      final viewport = state.context.findRenderObject();
      if (viewport is RenderBox && viewport.attached && viewport.hasSize) {
        if (state.position.axis == Axis.vertical) {
          vertical ??= viewport;
        } else {
          horizontal ??= viewport;
        }
      }
    }
    return vertical == null || horizontal == null;
  });

  return _FocusTarget(
    box: box,
    verticalViewport: vertical,
    horizontalViewport: horizontal,
  );
}

/// Whether the focused widget already says it has the focus on its own.
///
/// A text field does: its outline thickens and turns to the primary colour,
/// and the label lifts into the notch. Adding this ring as well draws a second
/// line just inside the first, which reads as a rendering mistake rather than
/// as emphasis — and the field's own cue is the better of the two anyway,
/// because it also fits the field's shape.
bool _marksItself(BuildContext context) {
  return context.findAncestorWidgetOfExactType<EditableText>() != null;
}

/// Whether the focus is on a [TvFocusSurface] rather than on a control.
///
/// Matched by node, not by ancestry: a player's controls are built *inside*
/// the picture they float over, so anything looser would take the ring off the
/// buttons too — the one place a television needs it most.
bool _isSurface(FocusNode node, BuildContext context) {
  final surface = context.findAncestorWidgetOfExactType<TvFocusSurface>();
  return surface != null && identical(surface.node, node);
}

/// The rectangle of [target]'s ring, in global coordinates, or null when the
/// list it scrolls in has carried it out of sight.
Rect? _ringOf(_FocusTarget target) {
  final box = target.box;
  if (!box.attached || !box.hasSize) return null;

  // The node still holds the primary focus (to prevent it jumping to the
  // app bar), but it has been shut out of the focus tree by an overlay
  // zooming in. If it can no longer be reached, the ring should not be
  // drawn over the screen either.
  final node = FocusManager.instance.primaryFocus;
  if (node == null || !node.canRequestFocus) return null;

  // Where the control is *painted*, not where it was laid out. On a television
  // the focused control is drawn larger than its slot, and `FocusNode.rect`
  // reports the slot — a ring traced on that sits inside the card it is meant
  // to be around.
  final painted = MatrixUtils.transformRect(
    box.getTransformTo(null),
    Offset.zero & box.size,
  );
  if (painted.isEmpty) return null;
  final ring = painted.inflate(Dimens.focusOutlineGap);

  final clip = _clipOf(target);
  if (!clip.overlaps(ring)) return null;
  return ring;
}

/// What the ring is allowed to reach, given the lists the control sits in.
///
/// Each list bounds it in that list's own direction only: a page bounds the
/// ring top and bottom, which is what keeps a row scrolling out of sight from
/// leaving its ring drawn across the app bar it has gone behind, and a row of
/// chips bounds it left and right. Bounding both ways from either would cut
/// the lift, which is drawn outside the slot the list gave the control — so
/// each edge is let out by as much as the lift can add.
Rect _clipOf(_FocusTarget target) {
  var clip = Rect.largest;
  const slack = Dimens.tvFocusGrowth;
  final vertical = _globalRectOf(target.verticalViewport);
  if (vertical != null) {
    clip = Rect.fromLTRB(
      clip.left,
      vertical.top - slack,
      clip.right,
      vertical.bottom + slack,
    );
  }
  final horizontal = _globalRectOf(target.horizontalViewport);
  if (horizontal != null) {
    clip = Rect.fromLTRB(
      horizontal.left - slack,
      clip.top,
      horizontal.right + slack,
      clip.bottom,
    );
  }
  return clip;
}

Rect? _globalRectOf(RenderBox? box) {
  if (box == null || !box.attached || !box.hasSize) return null;
  return MatrixUtils.transformRect(
    box.getTransformTo(null),
    Offset.zero & box.size,
  );
}

/// The ring `TvShell` would draw for the focus as it stands, with the bounds
/// it is clipped to — or null when it would draw none. The shell's own
/// answer, so a test can ask for it.
@visibleForTesting
({Rect ring, Rect clip})? tvFocusRing() {
  final target = _focusTarget();
  if (target == null) return null;
  final ring = _ringOf(target);
  if (ring == null) return null;
  return (ring: ring, clip: _clipOf(target));
}

/// Draws the ring where the focused control is *at paint time*.
///
/// Not from a rectangle kept in state, because such a rectangle is a frame
/// old: it is measured after one frame and drawn in the next, so during a
/// fling the row has already moved on and the ring trails it across the
/// screen. Reading the transform here — after this frame's layout, in the same
/// frame as the page underneath — is what keeps the two together.
class _FocusOutlinePainter extends CustomPainter {
  _FocusOutlinePainter({
    required this.color,
    required this.target,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final Color color;
  final ValueListenable<_FocusTarget?> target;

  @override
  void paint(Canvas canvas, Size size) {
    final target = this.target.value;
    if (target == null) return;
    final ring = _ringOf(target);
    if (ring == null) return;

    canvas
      ..save()
      ..clipRect(_clipOf(target))
      // The stroke straddles the line it is drawn on, so the rectangle is
      // pulled in by half of it to sit where a border of the same width would.
      ..drawRRect(
        RRect.fromRectAndRadius(
          ring.deflate(Dimens.focusRingWidth / 2),
          const Radius.circular(Dimens.radiusControl),
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = Dimens.focusRingWidth
          ..color = color,
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_FocusOutlinePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.target != target;
}
