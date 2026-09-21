import 'dart:math' as math;

import 'package:do_x/constants/dimens.dart';
import 'package:do_x/utils/device_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The app's press behaviour for every neumorphic surface that can be tapped.
///
/// Deliberately not an [InkWell]: a ripple recolours the panel, and on a
/// neumorphic surface the press is meant to read as the panel sinking into the
/// page, not as a tint washing over it. [builder] gets the pressed flag and
/// draws that sink itself — usually inset shadows.
///
/// It is also the app's single focus target. Cards, buttons and chips all end
/// up here, so giving this one widget a focus node is what makes the whole
/// neumorphic surface family reachable with a TV remote's D-pad. It draws no
/// focus *marker* of its own — `TvShell` outlines whatever the remote is on,
/// for every widget in the app, and a second marker here only read as a stray
/// line inside the first.
///
/// What it does do on a television is grow. An outline alone is a thin line
/// on a panel being read from across a room; the control lifting off the page
/// is what can be seen from the sofa, and it is what every television
/// interface does. `TvShell` measures the outline from where the control is
/// actually painted, so the ring grows with it.
class NeuPress extends StatefulWidget {
  const NeuPress({
    super.key,
    required this.builder,
    this.onTap,
    this.onLongPress,
    this.pressedScale = 0.97,
    this.autofocus = false,
    this.focusNode,
  });

  /// Draws the surface. `pressed` is true from the moment the finger lands
  /// until the sink has both finished and been released.
  final Widget Function(BuildContext context, bool pressed) builder;

  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// How far the surface shrinks while held. The shadows alone change too
  /// little to read as movement; a small shrink is what sells the press. Keep
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

  /// Long enough for the sink to be seen, short enough not to feel laggy.
  static const duration = Duration(milliseconds: 130);

  @override
  State<NeuPress> createState() => _NeuPressState();
}

class _NeuPressState extends State<NeuPress> {
  bool _pressed = false;
  bool _fingerDown = false;
  bool _sinkFinished = true;

  /// Whether the remote is resting on this control. Only ever set on a
  /// television — elsewhere nothing reads it, and a mouse or a finger leaves
  /// focus behind on controls it has merely touched.
  bool _focused = false;

  /// How wide the surface was when the remote arrived, so the lift can be
  /// the same number of pixels whatever the control is.
  double? _width;

  /// How big the surface is drawn: sunk while held, lifted while the remote
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
  /// [NeuPress.duration].
  ///
  /// Without the hold, a quick tap lifts the finger before the animation has
  /// travelled anywhere and nothing visibly moves — the same problem
  /// `flutter_neumorphic` solves by waiting for the down animation before it
  /// lets the release through.
  Future<void> _sink() async {
    _fingerDown = true;
    _sinkFinished = false;
    setState(() => _pressed = true);
    HapticFeedback.lightImpact();
    await Future.delayed(NeuPress.duration);
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
  /// so the sink is played out in full first and the tap fires on the way back
  /// up — otherwise the surface would never visibly move on a TV.
  Future<void> _activate() async {
    await _sink();
    _release();
    if (!mounted) return;
    widget.onTap?.call();
  }

  void _onFocusHighlight(bool value) {
    if (_focused == value || !mounted) return;
    setState(() {
      _focused = value;
      // Read now rather than through a `LayoutBuilder`: one of these wraps
      // every tappable surface in the app, and a layout builder among them
      // would refuse the intrinsic measurements some of their parents ask
      // for. The box was laid out by the frame before this one.
      if (value) {
        final box = context.findRenderObject();
        _width = box is RenderBox && box.hasSize ? box.size.width : null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // The scale wraps the focus node rather than sitting inside it. `TvShell`
    // measures its outline from the focused node's render object, and a
    // transform *below* that node is one the measurement cannot see — the
    // card grew and the ring stayed the size of the slot, drawn across the
    // middle of it. From out here the transform is on the way up, so the
    // rect the shell measures is the one that is actually on screen.
    return AnimatedScale(
      scale: _scale,
      duration: NeuPress.duration,
      curve: Curves.easeOut,
      child: FocusableActionDetector(
        enabled: _enabled,
        autofocus: widget.autofocus,
        focusNode: widget.focusNode,
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
          child: widget.builder(context, _pressed),
        ),
      ),
    );
  }
}
