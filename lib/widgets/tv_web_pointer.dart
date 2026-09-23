import 'dart:async';
import 'dart:math';

import 'package:do_x/constants/dimens.dart';
import 'package:do_x/utils/device_type.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

/// Points at a web page with the television remote, and touches it.
///
/// `TvWebNavigator` drives a page by script, which reaches only the page's own
/// document. A control inside a frame from another origin — a bot check's
/// slider, which is a frame by design — is out of script's reach, and a slider
/// is not something a click can answer anyway: it has to be dragged.
///
/// So this puts a pointer over the web view instead. The arrows move it; OK
/// puts a finger down where it is, the arrows then drag that finger, and OK
/// again lifts it. The touches are ordinary Flutter pointer events, so they
/// reach the platform view the way a real finger's would, frames and all.
///
/// A pass-through on every other device.
class TvWebPointer extends StatefulWidget {
  const TvWebPointer({super.key, required this.child, this.autofocus = true});

  final Widget child;

  final bool autofocus;

  @override
  State<TvWebPointer> createState() => _TvWebPointerState();
}

class _TvWebPointerState extends State<TvWebPointer>
    with SingleTickerProviderStateMixin {
  /// How far one press moves the pointer, and one auto-repeat of a held key.
  static const _step = 6.0;
  static const _repeatStep = 16.0;

  /// The share of the remaining distance covered each frame. The pointer
  /// glides to where the keys sent it rather than jumping there, so a drag
  /// arrives as a stream of small moves — which is what a finger produces and
  /// what a bot check expects to see.
  static const _follow = 0.3;

  /// A finger never moves in a perfectly straight line.
  static const _jitter = 0.6;

  /// Well clear of the ids the engine hands real pointers.
  static int _nextPointer = 1 << 20;

  final FocusNode _node = FocusNode(debugLabel: 'tv-web-pointer');
  final _random = Random();

  Ticker? _ticker;

  /// The pointer events' clock: the engine's own, which is the one real
  /// touches are stamped with, carried forward between frames.
  final _clock = Stopwatch();
  late final Duration _clockBase;

  Size _size = Size.zero;
  Offset? _cursor;
  Offset? _target;

  /// The finger that is down, or null while the pointer only hovers.
  int? _pointer;
  int _viewId = 0;
  Offset _lastGlobal = Offset.zero;

  bool get _isPressed => _pointer != null;

  @override
  void initState() {
    super.initState();
    if (!deviceType.isTv) return;
    _clockBase = SchedulerBinding.instance.currentSystemFrameTimeStamp;
    _clock.start();
    _ticker = createTicker(_onTick);
    _node.addListener(_keepKeys);
  }

  @override
  void dispose() {
    _release(cancel: true);
    _ticker?.dispose();
    _node.dispose();
    super.dispose();
  }

  /// Takes the remote back from the web view.
  ///
  /// A touch can hand the native view the focus, and from then on the keys go
  /// to the page rather than to Flutter — the finger could never be lifted
  /// again. The web view's focus node sits under this one, so the moment it
  /// takes the focus, the focus is asked back.
  void _keepKeys() {
    if (!_node.hasFocus || _node.hasPrimaryFocus) return;
    scheduleMicrotask(() {
      if (mounted && _node.hasFocus && !_node.hasPrimaryFocus) {
        _node.requestFocus();
      }
    });
  }

  Duration get _now => _clockBase + _clock.elapsed;

  Offset _toGlobal(Offset local) {
    final box = context.findRenderObject();
    return box is RenderBox && box.attached ? box.localToGlobal(local) : local;
  }

  void _dispatch(PointerEvent event) {
    _lastGlobal = event.position;
    GestureBinding.instance.handlePointerEvent(event);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final step = event is KeyRepeatEvent ? _repeatStep : _step;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowLeft:
        _moveBy(Offset(-step, 0), TraversalDirection.left);
      case LogicalKeyboardKey.arrowRight:
        _moveBy(Offset(step, 0), TraversalDirection.right);
      case LogicalKeyboardKey.arrowUp:
        _moveBy(Offset(0, -step), TraversalDirection.up);
      case LogicalKeyboardKey.arrowDown:
        _moveBy(Offset(0, step), TraversalDirection.down);
      case LogicalKeyboardKey.select:
      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.gameButtonA:
        if (event is KeyDownEvent) _isPressed ? _release() : _press();
      default:
        return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  /// Sends the pointer on by [delta]. Pushed against the edge while no finger
  /// is down, the remote leaves for whatever lies that way — otherwise the
  /// close button would be unreachable for as long as the page is up.
  void _moveBy(Offset delta, TraversalDirection escape) {
    final target = _target;
    if (target == null) return;
    final next = _clamp(target + delta);
    if (next == target) {
      if (!_isPressed) _node.focusInDirection(escape);
      return;
    }
    _target = next;
    final ticker = _ticker;
    if (ticker != null && !ticker.isActive) ticker.start();
  }

  Offset _clamp(Offset p) => Offset(
    p.dx.clamp(0.0, max(0.0, _size.width - 1)),
    p.dy.clamp(0.0, max(0.0, _size.height - 1)),
  );

  void _onTick(Duration _) {
    final from = _cursor;
    final target = _target;
    if (from == null || target == null) return;
    final gap = target - from;
    Offset next;
    if (gap.distance < 0.5) {
      next = target;
      _ticker?.stop();
    } else {
      next = from + gap * _follow;
      if (_isPressed) {
        next = _clamp(
          next +
              Offset(
                (_random.nextDouble() * 2 - 1) * _jitter,
                (_random.nextDouble() * 2 - 1) * _jitter,
              ),
        );
      }
    }
    setState(() => _cursor = next);
    final pointer = _pointer;
    if (pointer == null) return;
    final position = _toGlobal(next);
    _dispatch(
      PointerMoveEvent(
        viewId: _viewId,
        timeStamp: _now,
        pointer: pointer,
        position: position,
        delta: position - _lastGlobal,
      ),
    );
  }

  void _press() {
    final cursor = _cursor;
    if (cursor == null) return;
    final pointer = _nextPointer++;
    _viewId = View.of(context).viewId;
    _dispatch(
      PointerDownEvent(
        viewId: _viewId,
        timeStamp: _now,
        pointer: pointer,
        position: _toGlobal(cursor),
      ),
    );
    setState(() => _pointer = pointer);
  }

  /// Lifts the finger, or — when the page is going away under it — cancels
  /// it, so the web view is never left believing a finger is still down.
  void _release({bool cancel = false}) {
    final pointer = _pointer;
    if (pointer == null) return;
    _pointer = null;
    if (cancel) {
      _dispatch(
        PointerCancelEvent(
          viewId: _viewId,
          timeStamp: _now,
          pointer: pointer,
          position: _lastGlobal,
        ),
      );
      return;
    }
    final cursor = _cursor;
    _dispatch(
      PointerUpEvent(
        viewId: _viewId,
        timeStamp: _now,
        pointer: pointer,
        position: cursor == null ? _lastGlobal : _toGlobal(cursor),
      ),
    );
    setState(() {});
    _keepKeys();
  }

  @override
  Widget build(BuildContext context) {
    if (!deviceType.isTv) return widget.child;
    return Focus(
      focusNode: _node,
      autofocus: widget.autofocus,
      onFocusChange: (hasFocus) {
        if (!hasFocus) _release();
      },
      onKeyEvent: _onKey,
      child: LayoutBuilder(
        builder: (context, constraints) {
          _size = constraints.biggest;
          final cursor = _cursor ??= _size.center(Offset.zero);
          _target ??= cursor;
          const radius = Dimens.tvWebPointerSize / 2;
          return Stack(
            children: [
              Positioned.fill(child: widget.child),
              Positioned(
                left: cursor.dx - radius,
                top: cursor.dy - radius,
                child: IgnorePointer(
                  child: ListenableBuilder(
                    listenable: _node,
                    builder: (context, _) => _PointerMark(
                      isPressed: _isPressed,
                      isActive: _node.hasFocus,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// A ring where the pointer is, filled while the finger is down.
class _PointerMark extends StatelessWidget {
  const _PointerMark({required this.isPressed, required this.isActive});

  final bool isPressed;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return AnimatedOpacity(
      opacity: isActive ? 1 : 0.4,
      duration: Dimens.tvFocusScrollDuration,
      child: Container(
        width: Dimens.tvWebPointerSize,
        height: Dimens.tvWebPointerSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: isPressed ? 0.6 : 0.15),
          border: Border.all(color: color, width: 3),
          boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 6)],
        ),
      ),
    );
  }
}
