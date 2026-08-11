import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The app's press behaviour for every neumorphic surface that can be tapped.
///
/// Deliberately not an [InkWell]: a ripple recolours the panel, and on a
/// neumorphic surface the press is meant to read as the panel sinking into the
/// page, not as a tint washing over it. [builder] gets the pressed flag and
/// draws that sink itself — usually inset shadows.
class NeuPress extends StatefulWidget {
  const NeuPress({
    super.key,
    required this.builder,
    this.onTap,
    this.onLongPress,
    this.pressedScale = 0.97,
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

  /// Long enough for the sink to be seen, short enough not to feel laggy.
  static const duration = Duration(milliseconds: 130);

  @override
  State<NeuPress> createState() => _NeuPressState();
}

class _NeuPressState extends State<NeuPress> {
  bool _pressed = false;
  bool _fingerDown = false;
  bool _sinkFinished = true;

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

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: _enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTapDown: _enabled ? (_) => _sink() : null,
        onTapUp: _enabled ? (_) => _release() : null,
        onTapCancel: _enabled ? _release : null,
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: AnimatedScale(
          scale: _pressed ? widget.pressedScale : 1,
          duration: NeuPress.duration,
          curve: Curves.easeOut,
          child: widget.builder(context, _pressed),
        ),
      ),
    );
  }
}
