import 'dart:math' as math;

import 'package:do_x/constants/dimens.dart';
import 'package:do_x/utils/device_type.dart';
import 'package:do_x/widgets/tv_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// What a [AppPressable] surface should draw.
@immutable
class AppPressState {
  const AppPressState({required this.pressed, required this.focused});

  /// True from the moment the finger lands until the press has both finished
  /// and been released.
  final bool pressed;

  /// True only on a TV while the remote rests on this control.
  final bool focused;
}

/// The app's press behaviour for every flat surface that can be tapped.
///
/// Deliberately not an [InkWell]: a ripple spreads from the finger and gets
/// clipped by whatever the surface happens to hold. Here the whole surface
/// takes the press at once — [builder] gets the pressed and focused flags and
/// draws the flat state layer itself, usually through
/// `SurfaceTheme.stateFill` — and the surface shrinks a little while held.
///
/// It is also the app's single focus target. Cards, buttons and chips all end
/// up here, so giving this one widget a focus node is what makes the whole
/// surface family reachable with a TV remote's D-pad.
///
/// Each surface draws its own focus ring: [builder] passes
/// `FocusRingDecoration.of` as its `foregroundDecoration`, so the ring takes
/// the surface's own radius. This widget tells `TvShell` so through
/// [TvOwnFocusRing], and the shell's app-wide outline stays off it — a
/// builder that draws no ring leaves the control with only the focused fill.
///
/// On a television the surface also grows. A ring alone is a thin line on a
/// panel being read from across a room; the control lifting off the page is
/// what can be seen from the sofa, and it is what every television interface
/// does. The ring is painted by the surface itself, so it grows with it.
class AppPressable extends StatefulWidget {
  const AppPressable({
    super.key,
    required this.builder,
    this.onTap,
    this.onLongPress,
    this.pressedScale = Dimens.pressedScaleControl,
    this.autofocus = false,
    this.focusNode,
  });

  /// Draws the surface for its current [AppPressState], focus ring included.
  final Widget Function(BuildContext context, AppPressState state) builder;

  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// How far the surface shrinks while held. The state layer alone is a
  /// colour change; a small shrink is what sells the press as movement. Keep
  /// it nearer 1 for a large panel, where 3% is a visible lurch.
  final double pressedScale;

  /// Takes the D-pad on the way into a page. Set it on the first control of a
  /// screen so the remote lands somewhere useful instead of nowhere.
  ///
  /// Only honoured when nothing in the scope holds focus yet — which on a TV is
  /// almost never true, since the remote is always resting on something. Pass a
  /// [focusNode] and call `requestFocus()` on it when the focus has to move.
  final bool autofocus;

  /// Lets a caller move the remote onto this control. See [autofocus].
  final FocusNode? focusNode;

  /// Long enough for the press to be seen, short enough not to feel laggy.
  static const duration = Duration(milliseconds: 130);

  @override
  State<AppPressable> createState() => _AppPressableState();
}

class _AppPressableState extends State<AppPressable> {
  bool _pressed = false;
  bool _fingerDown = false;
  bool _sinkFinished = true;

  /// Whether the focus highlight is showing on this control's node — true
  /// while the node or anything inside it has the focus. Only ever set on a
  /// television: elsewhere nothing reads it, and a mouse or a finger leaves
  /// focus behind on controls it has merely touched.
  bool _highlight = false;

  /// Whether the remote is on this control itself, not on a control inside
  /// it. A card that holds a button is not focused while the remote is on
  /// the button — lifting and ringing both would mark two things at once.
  bool _primary = false;

  /// Whether the remote is resting on this control.
  bool get _focused => _highlight && _primary;

  /// Used when the caller passes no [AppPressable.focusNode], so there is
  /// always a node to name to [TvOwnFocusRing].
  FocusNode? _ownNode;

  FocusNode get _node =>
      widget.focusNode ?? (_ownNode ??= FocusNode(debugLabel: 'AppPressable'));

  @override
  void initState() {
    super.initState();
    _node.addListener(_onNodeChange);
    _primary = _node.hasPrimaryFocus;
  }

  @override
  void didUpdateWidget(AppPressable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode == widget.focusNode) return;
    (oldWidget.focusNode ?? _ownNode)?.removeListener(_onNodeChange);
    _node.addListener(_onNodeChange);
    _primary = _node.hasPrimaryFocus;
  }

  @override
  void dispose() {
    _node.removeListener(_onNodeChange);
    _ownNode?.dispose();
    super.dispose();
  }

  /// How wide the surface was when the remote arrived, so the lift can be
  /// the same number of pixels whatever the control is.
  double? _width;

  /// How big the surface is drawn: shrunk while held, lifted while the remote
  /// is on it, its own size otherwise. Pressing wins, because a press is
  /// something the viewer is doing right now.
  double get _scale {
    if (_pressed) return widget.pressedScale;
    if (!_focused) return 1;

    final width = _width;
    if (width == null || !width.isFinite || width <= 0) {
      return Dimens.tvFocusScaleMax;
    }
    // Capped, because ten pixels on an app bar's icon is a third of it.
    return math.min(1 + Dimens.tvFocusGrowth / width, Dimens.tvFocusScaleMax);
  }

  bool get _enabled => widget.onTap != null || widget.onLongPress != null;

  /// Presses the surface in and holds it there for at least
  /// [AppPressable.duration].
  ///
  /// Without the hold, a quick tap lifts the finger before the animation has
  /// travelled anywhere and nothing visibly changes, so the release waits for
  /// the down animation before it is let through.
  Future<void> _sink() async {
    _fingerDown = true;
    _sinkFinished = false;
    setState(() => _pressed = true);
    HapticFeedback.lightImpact();
    await Future.delayed(AppPressable.duration);
    _sinkFinished = true;
    _riseIfReleased();
  }

  void _release() {
    _fingerDown = false;
    _riseIfReleased();
  }

  void _riseIfReleased() {
    if (!mounted || _fingerDown || !_sinkFinished || !_pressed) return;
    setState(() => _pressed = false);
  }

  /// The remote's OK button. A key press has no down/up the way a finger does,
  /// so the press is played out in full first and the tap fires on the way back
  /// up — otherwise the surface would never visibly move on a TV.
  Future<void> _activate() async {
    await _sink();
    _release();
    if (!mounted) return;
    widget.onTap?.call();
  }

  void _onFocusHighlight(bool value) {
    if (_highlight == value || !mounted) return;
    _setFocus(() => _highlight = value);
  }

  void _onNodeChange() {
    final primary = _node.hasPrimaryFocus;
    if (_primary == primary || !mounted) return;
    _setFocus(() => _primary = primary);
  }

  void _setFocus(VoidCallback change) {
    final was = _focused;
    change();
    if (was == _focused) return;
    setState(() {
      // Read now rather than through a `LayoutBuilder`: one of these wraps
      // every tappable surface in the app, and a layout builder among them
      // would refuse the intrinsic measurements some of their parents ask
      // for. The box was laid out by the frame before this one.
      if (_focused) {
        final box = context.findRenderObject();
        _width = box is RenderBox && box.hasSize ? box.size.width : null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // The scale wraps the focus node rather than sitting inside it, so
    // whatever measures the focused node's render object — the D-pad's
    // traversal, the scroll that brings the control into view — sees the rect
    // that is actually on screen rather than the slot it grew out of.
    return AnimatedScale(
      scale: _scale,
      duration: AppPressable.duration,
      curve: Curves.easeOut,
      child: TvOwnFocusRing(
        node: _node,
        child: FocusableActionDetector(
          enabled: _enabled,
          autofocus: widget.autofocus,
          focusNode: _node,
          onShowFocusHighlight: deviceType.isTv ? _onFocusHighlight : null,
          mouseCursor: _enabled
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                _activate();
                return null;
              },
            ),
          },
          child: GestureDetector(
            onTapDown: _enabled ? (_) => _sink() : null,
            onTapUp: _enabled ? (_) => _release() : null,
            onTapCancel: _enabled ? _release : null,
            onTap: widget.onTap,
            onLongPress: widget.onLongPress,
            child: widget.builder(
              context,
              AppPressState(pressed: _pressed, focused: _focused),
            ),
          ),
        ),
      ),
    );
  }
}
