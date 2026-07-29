import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:do_x/extensions/context_extensions.dart';
import 'package:flutter/material.dart';

class LineAreaChart extends StatelessWidget {
  final List<double> data;

  /// Optional timestamps aligned 1:1 with [data]. When provided (and valid),
  /// points are positioned along the x-axis proportionally to real time so
  /// uneven gaps between samples are rendered faithfully. Falls back to even
  /// spacing by index when omitted or mismatched.
  final List<DateTime>? times;
  final Color? lineColor;
  final Color? areaColor;
  final double strokeWidth;
  final bool showArea;

  const LineAreaChart({
    super.key,
    required this.data,
    this.times,
    this.lineColor,
    this.areaColor,
    this.strokeWidth = 2.0,
    this.showArea = true,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          // Empty-state well, not an outlined box: the flat sunken fill is how
          // this design marks a placeholder.
          color: context.neu.sunken,
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Center(
          child: Text(
            'No data',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ),
      );
    }

    final effectiveLineColor = lineColor ?? Theme.of(context).primaryColor;
    final effectiveAreaColor =
        areaColor ?? effectiveLineColor.withValues(alpha: 0.1);

    return ClipRect(
      child: CustomPaint(
        painter: _LineAreaChartPainter(
          data: data,
          times: times,
          lineColor: effectiveLineColor,
          areaColor: effectiveAreaColor,
          strokeWidth: strokeWidth,
          showArea: showArea,
        ),
        child: Container(),
      ),
    );
  }
}

class _LineAreaChartPainter extends CustomPainter {
  final List<double> data;
  final List<DateTime>? times;
  final Color lineColor;
  final Color areaColor;
  final double strokeWidth;
  final bool showArea;

  _LineAreaChartPainter({
    required this.data,
    required this.times,
    required this.lineColor,
    required this.areaColor,
    required this.strokeWidth,
    required this.showArea,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    if (data.length == 1) {
      // Draw a single point as a horizontal line
      final y = size.height / 2;
      final paint = Paint()
        ..color = lineColor
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke;

      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      return;
    }

    // Pair each finite value with its x-fraction (0..1) along the axis.
    // When aligned timestamps are available, position points by real time so
    // uneven sampling gaps are preserved; otherwise space them evenly.
    final int n = data.length;
    final bool useTime = times != null && times!.length == n;
    final int firstMs = useTime ? times!.first.millisecondsSinceEpoch : 0;
    final int spanMs = useTime
        ? times!.last.millisecondsSinceEpoch - firstMs
        : 0;

    final validData = <double>[];
    final xFractions = <double>[];
    for (int i = 0; i < n; i++) {
      if (!data[i].isFinite) continue;
      validData.add(data[i]);
      if (useTime && spanMs > 0) {
        xFractions.add((times![i].millisecondsSinceEpoch - firstMs) / spanMs);
      } else {
        xFractions.add(0); // placeholder; filled with even spacing below
      }
    }
    if (validData.isEmpty) {
      return;
    }
    if (!useTime || spanMs <= 0) {
      final int cnt = validData.length;
      for (int i = 0; i < cnt; i++) {
        xFractions[i] = cnt > 1 ? i / (cnt - 1) : 0;
      }
    }

    final double minValue = validData.reduce(math.min);
    final double maxValue = validData.reduce(math.max);
    final double valueRange = maxValue - minValue;

    if (valueRange == 0) {
      final y = size.height / 2;
      final paint = Paint()
        ..color = lineColor
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke;

      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      return;
    }

    // Leave vertical breathing room so the line/dot never clips at the edges.
    final double dotRadius = strokeWidth * 1.8;
    final double vPad = dotRadius + 1;
    final double chartHeight = math.max(0, size.height - vPad * 2);

    final Path linePath = Path();
    final Path areaPath = Path();

    double lastX = 0;
    double lastY = 0;
    bool pathStarted = false;
    for (int i = 0; i < validData.length; i++) {
      final double x = xFractions[i] * size.width;
      final double normalizedValue = (validData[i] - minValue) / valueRange;
      final double y = vPad + (1 - normalizedValue) * chartHeight;

      if (!x.isFinite || !y.isFinite) {
        continue;
      }

      if (!pathStarted) {
        linePath.moveTo(x, y);
        areaPath.moveTo(x, size.height);
        areaPath.lineTo(x, y);
        pathStarted = true;
      } else {
        linePath.lineTo(x, y);
        areaPath.lineTo(x, y);
      }
      lastX = x;
      lastY = y;
    }

    if (!pathStarted) {
      return;
    }

    if (showArea && pathStarted) {
      // Complete the area by going to bottom-right then bottom-left
      areaPath.lineTo(lastX, size.height);
      areaPath.lineTo(0, size.height);
      areaPath.close();

      // Create gradient for area fill
      final gradient = ui.Gradient.linear(
        Offset(0, 0), //
        Offset(0, size.height),
        [areaColor, areaColor.withValues(alpha: 0)],
        [0.0, 1.0],
      );

      final areaPaint = Paint()
        ..shader = gradient
        ..style = PaintingStyle.fill;

      canvas.drawPath(areaPath, areaPaint);
    }

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(linePath, linePaint);

    // Highlight the current (latest) value with a marker dot.
    canvas.drawCircle(
      Offset(lastX, lastY),
      dotRadius,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(_LineAreaChartPainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.times != times ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.areaColor != areaColor ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.showArea != showArea;
  }
}
