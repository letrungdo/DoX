import 'dart:math' as math;

import 'package:flutter/material.dart';

class CuteBarChartItem {
  const CuteBarChartItem({required this.label, this.value, this.compareValue});

  final String label;
  final double? value;

  /// Optional second series (e.g. same period last year).
  final double? compareValue;
}

/// Bar chart matching the app theme: thin bars with 4px rounded tops, a 2px
/// gap between paired bars, recessive baseline, tap to inspect a group.
/// The selected group's values are shown in the header row, so bars stay
/// unlabeled and the chart stays quiet.
class CuteBarChart extends StatefulWidget {
  const CuteBarChart({
    super.key,
    required this.items,
    required this.primaryColor,
    this.compareColor,
    this.height = 150,
    this.formatValue,
  });

  final List<CuteBarChartItem> items;
  final Color primaryColor;

  /// Required when any item has [CuteBarChartItem.compareValue].
  final Color? compareColor;
  final double height;
  final String Function(double value)? formatValue;

  @override
  State<CuteBarChart> createState() => _CuteBarChartState();
}

class _CuteBarChartState extends State<CuteBarChart> {
  int? _selected;

  bool get _hasCompare => widget.items.any((e) => e.compareValue != null);

  String _format(double value) => widget.formatValue?.call(value) ?? value.toStringAsFixed(1);

  @override
  void didUpdateWidget(covariant CuteBarChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selected != null && _selected! >= widget.items.length) _selected = null;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontSize: 10,
    );
    final selectedIndex = _selected ?? widget.items.length - 1;
    final selectedItem = widget.items[selectedIndex];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(theme, selectedItem),
        const SizedBox(height: 6),
        GestureDetector(
          onTapDown: (details) => _onTap(details.localPosition),
          child: SizedBox(
            height: widget.height,
            width: double.infinity,
            child: CustomPaint(
              painter: _BarChartPainter(
                items: widget.items,
                primaryColor: widget.primaryColor,
                compareColor: _hasCompare ? widget.compareColor : null,
                selectedIndex: selectedIndex,
                selectionColor: theme.colorScheme.onSurface.withValues(alpha: 0.06),
                baselineColor: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
                labelStyle: labelStyle,
                surfaceColor: theme.scaffoldBackgroundColor,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Selected group details: label + one dot-value pair per series.
  Widget _buildHeader(ThemeData theme, CuteBarChartItem item) {
    final textStyle = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final valueStyle = theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700);
    return Wrap(
      spacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(item.label, style: textStyle),
        if (item.compareValue != null && widget.compareColor != null)
          _legendValue(widget.compareColor!, _format(item.compareValue!), textStyle),
        if (item.value != null) _legendValue(widget.primaryColor, _format(item.value!), valueStyle),
      ],
    );
  }

  Widget _legendValue(Color color, String text, TextStyle? style) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(text, style: style),
      ],
    );
  }

  void _onTap(Offset position) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || widget.items.isEmpty) return;
    final width = box.size.width;
    final groupWidth = width / widget.items.length;
    final index = (position.dx / groupWidth).floor().clamp(0, widget.items.length - 1);
    setState(() => _selected = index);
  }
}

class _BarChartPainter extends CustomPainter {
  _BarChartPainter({
    required this.items,
    required this.primaryColor,
    required this.compareColor,
    required this.selectedIndex,
    required this.selectionColor,
    required this.baselineColor,
    required this.labelStyle,
    required this.surfaceColor,
  });

  final List<CuteBarChartItem> items;
  final Color primaryColor;
  final Color? compareColor;
  final int selectedIndex;
  final Color selectionColor;
  final Color baselineColor;
  final TextStyle? labelStyle;
  final Color surfaceColor;

  static const _labelHeight = 16.0;
  static const _barGap = 2.0;
  static const _maxBarWidth = 18.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (items.isEmpty) return;

    final plotHeight = size.height - _labelHeight;
    final groupWidth = size.width / items.length;

    double maxValue = 0;
    for (final item in items) {
      maxValue = math.max(maxValue, math.max(item.value ?? 0, item.compareValue ?? 0));
    }
    if (maxValue <= 0) maxValue = 1;

    final barsPerGroup = compareColor != null ? 2 : 1;
    final barWidth = math.min(
      _maxBarWidth,
      (groupWidth * 0.62 - _barGap * (barsPerGroup - 1)) / barsPerGroup,
    );

    // Selection backdrop behind the whole group.
    final selectionRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(selectedIndex * groupWidth + 1, 0, groupWidth - 2, plotHeight),
      const Radius.circular(6),
    );
    canvas.drawRRect(selectionRect, Paint()..color = selectionColor);

    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final groupCenter = i * groupWidth + groupWidth / 2;
      final totalBarsWidth = barWidth * barsPerGroup + _barGap * (barsPerGroup - 1);
      var x = groupCenter - totalBarsWidth / 2;

      // Compare (older period) on the left, primary (current) on the right —
      // groups read left→right in time like the axis does.
      if (compareColor != null) {
        _drawBar(canvas, x, item.compareValue, maxValue, plotHeight, barWidth, compareColor!);
        x += barWidth + _barGap;
      }
      _drawBar(canvas, x, item.value, maxValue, plotHeight, barWidth, primaryColor);
    }

    // Recessive baseline on top of the bars' feet.
    canvas.drawLine(
      Offset(0, plotHeight),
      Offset(size.width, plotHeight),
      Paint()
        ..color = baselineColor
        ..strokeWidth = 1,
    );

    _drawLabels(canvas, size, groupWidth, plotHeight);
  }

  void _drawBar(Canvas canvas, double x, double? value, double maxValue, double plotHeight, double width, Color color) {
    if (value == null) return;
    final height = (value / maxValue) * (plotHeight - 6);
    if (height <= 0) return;
    final rect = RRect.fromRectAndCorners(
      Rect.fromLTWH(x, plotHeight - height, width, height),
      topLeft: const Radius.circular(4),
      topRight: const Radius.circular(4),
    );
    canvas.drawRRect(rect, Paint()..color = color);
  }

  void _drawLabels(Canvas canvas, Size size, double groupWidth, double plotHeight) {
    // Thin the labels out when groups get narrow instead of colliding.
    final step = math.max(1, (items.length / (size.width / 34)).ceil());
    for (var i = 0; i < items.length; i += step) {
      final painter = TextPainter(
        text: TextSpan(text: items[i].label, style: labelStyle),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: "…",
      )..layout(maxWidth: groupWidth + 8);
      final x = (i * groupWidth + groupWidth / 2 - painter.width / 2).clamp(0.0, size.width - painter.width);
      painter.paint(canvas, Offset(x, plotHeight + (_labelHeight - painter.height) / 2 + 2));
    }
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter oldDelegate) {
    return oldDelegate.items != items ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.compareColor != compareColor;
  }
}
