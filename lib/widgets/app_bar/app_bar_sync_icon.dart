import 'dart:math' as math;

import 'package:do_x/extensions/context_extensions.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Sync status badge for the [DoAppBar.titleSuffix] slot, modelled on Google
/// Photos: a dashed blue ring sweeps around while data is being fetched, then
/// closes into a solid green ring with a check inside. It never disappears once
/// the fetch is done, so the app bar keeps a steady "this screen syncs"
/// affordance and the layout never shifts.
class AppBarSyncIcon<T extends ChangeNotifier> extends StatelessWidget {
  const AppBarSyncIcon({
    super.key, //
    required this.selector,
    this.size = 20,
  });

  final bool Function(T vm) selector;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Selector<T, bool>(
      selector: (_, vm) => selector(vm),
      builder: (context, isLoading, _) =>
          _SyncRing(isLoading: isLoading, size: size),
    );
  }
}

class _SyncRing extends StatefulWidget {
  const _SyncRing({required this.isLoading, required this.size});

  final bool isLoading;
  final double size;

  @override
  State<_SyncRing> createState() => _SyncRingState();
}

class _SyncRingState extends State<_SyncRing>
    with TickerProviderStateMixin<_SyncRing> {
  /// Sweeps the dashed ring around while loading.
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  /// 0 = dashed and blue (syncing), 1 = solid and green (done).
  late final AnimationController _settle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
    value: widget.isLoading ? 0 : 1,
  );

  late final Animation<double> _settleCurve = CurvedAnimation(
    parent: _settle,
    curve: Curves.easeOutCubic,
  );

  /// The check only belongs to the settled state, and it starts drawing a touch
  /// after the ring closes.
  late final Animation<double> _check = CurvedAnimation(
    parent: _settle,
    curve: const Interval(0.45, 1, curve: Curves.easeOutCubic),
  );

  @override
  void initState() {
    super.initState();
    if (widget.isLoading) _spin.repeat();
    // The dashes only need to keep sweeping while the ring is still open.
    _settle.addListener(() {
      if (_settle.isCompleted) _spin.stop();
    });
  }

  @override
  void didUpdateWidget(_SyncRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLoading == oldWidget.isLoading) return;
    if (widget.isLoading) {
      _spin.repeat();
      _settle.reverse();
    } else {
      _settle.forward();
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    _settle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox.square(
      dimension: widget.size,
      child: AnimatedBuilder(
        animation: Listenable.merge([_spin, _settle]),
        builder: (context, _) {
          return CustomPaint(
            painter: SyncRingPainter(
              rotation: _spin.value,
              settle: _settleCurve.value,
              check: _check.value.clamp(0.0, 1.0),
              syncingColor: colors.info,
              doneColor: colors.success,
            ),
          );
        },
      ),
    );
  }
}

/// Paints the ring and the check. Public so a test can assert the state it was
/// handed; it is otherwise internal to [AppBarSyncIcon].
@visibleForTesting
class SyncRingPainter extends CustomPainter {
  SyncRingPainter({
    required this.rotation, //
    required this.settle,
    required this.check,
    required this.syncingColor,
    required this.doneColor,
  });

  /// Turns, 0..1.
  final double rotation;

  /// 0 = dashed blue, 1 = solid green.
  final double settle;

  /// How much of the check stroke is drawn, 0..1.
  final double check;

  final Color syncingColor;
  final Color doneColor;

  /// Few, long dashes read as a ring being drawn; many short ones just look
  /// like a dotted circle.
  static const _dashCount = 5;

  /// Share of each segment left empty while syncing. Shrinks to 0 as the ring
  /// settles, which is what closes the dashes into one continuous circle.
  static const _gapRatio = 0.38;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.shortestSide * 0.11;
    final rect = Rect.fromLTWH(
      0,
      0,
      size.width,
      size.height,
    ).deflate(stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = Color.lerp(syncingColor, doneColor, settle)!;

    if (settle == 1) {
      canvas.drawOval(rect, paint);
    } else {
      const segment = 2 * math.pi / _dashCount;
      final gap = segment * _gapRatio * (1 - settle);
      // Ease the sweep so the ring pulses like it's being drawn rather than
      // turning at a constant, mechanical rate.
      final eased = Curves.easeInOutSine.transform(rotation % 1);
      final start = eased * 2 * math.pi;
      for (var i = 0; i < _dashCount; i++) {
        canvas.drawArc(
          rect,
          start + i * segment + gap / 2,
          segment - gap,
          false,
          paint,
        );
      }
    }

    if (check > 0) _paintCheck(canvas, size, stroke);
  }

  /// The check is one continuous stroke — down into the vertex, then up — and
  /// [check] reveals it by length, so it draws itself the way a pen would
  /// instead of popping in whole.
  void _paintCheck(Canvas canvas, Size size, double stroke) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * 0.29, h * 0.51)
      ..lineTo(w * 0.44, h * 0.66)
      ..lineTo(w * 0.72, h * 0.36);

    final metric = path.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * check),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = doneColor,
    );
  }

  @override
  bool shouldRepaint(SyncRingPainter old) =>
      old.rotation != rotation ||
      old.settle != settle ||
      old.check != check ||
      old.syncingColor != syncingColor ||
      old.doneColor != doneColor;
}
