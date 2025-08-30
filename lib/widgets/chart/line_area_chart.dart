import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class LineAreaChart extends StatelessWidget {
  final List<double> data;
  final Color? lineColor;
  final Color? areaColor;
  final double strokeWidth;
  final bool showArea;

  const LineAreaChart({super.key, required this.data, this.lineColor, this.areaColor, this.strokeWidth = 2.0, this.showArea = true});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return Container(
        decoration: BoxDecoration(border: Border.all(color: Colors.grey.withValues(alpha: 0.3)), borderRadius: BorderRadius.circular(4)),
        child: const Center(child: Text('No data', style: TextStyle(color: Colors.grey, fontSize: 12))),
      );
    }

    final effectiveLineColor = lineColor ?? Theme.of(context).primaryColor;
    final effectiveAreaColor = areaColor ?? effectiveLineColor.withValues(alpha: 0.1);

    return ClipRect(
      child: CustomPaint(
        painter: _LineAreaChartPainter(
          data: data,
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
  final Color lineColor;
  final Color areaColor;
  final double strokeWidth;
  final bool showArea;

  _LineAreaChartPainter({
    required this.data,
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
      final paint =
          Paint()
            ..color = lineColor
            ..strokeWidth = strokeWidth
            ..style = PaintingStyle.stroke;

      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      return;
    }

    // Filter out invalid values
    final validData = data.where((v) => v.isFinite).toList();
    if (validData.isEmpty) {
      return;
    }

    final double minValue = validData.reduce(math.min);
    final double maxValue = validData.reduce(math.max);
    final double valueRange = maxValue - minValue;

    if (valueRange == 0) {
      final y = size.height / 2;
      final paint =
          Paint()
            ..color = lineColor
            ..strokeWidth = strokeWidth
            ..style = PaintingStyle.stroke;

      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      return;
    }

    final double xStep = validData.length > 1 ? size.width / (validData.length - 1) : 0;
    final Path linePath = Path();
    final Path areaPath = Path();

    bool pathStarted = false;
    for (int i = 0; i < validData.length; i++) {
      final double x = i * xStep;
      final double normalizedValue = (validData[i] - minValue) / valueRange;
      final double y = size.height - (normalizedValue * size.height);

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
    }

    if (!pathStarted) {
      return;
    }

    if (showArea && pathStarted) {
      // Complete the area by going to bottom-right then bottom-left
      final lastX = (validData.length - 1) * xStep;
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

      final areaPaint =
          Paint()
            ..shader = gradient
            ..style = PaintingStyle.fill;

      canvas.drawPath(areaPath, areaPaint);
    }

    final linePaint =
        Paint()
          ..color = lineColor
          ..strokeWidth = strokeWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(linePath, linePaint);
  }

  @override
  bool shouldRepaint(_LineAreaChartPainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.areaColor != areaColor ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.showArea != showArea;
  }
}
