import 'dart:async';
import 'dart:math' as math;

import 'package:auto_route/auto_route.dart';
import 'package:do_x/constants/dimens.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/extensions/widget_extensions.dart';
import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/utils/feng_shui.dart';
import 'package:do_x/widgets/app_bar/app_bar_base.dart';
import 'package:do_x/widgets/app_scaffold.dart';
import 'package:do_x/widgets/neu/neu_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';

@RoutePage()
class FengShuiCompassScreen extends StatefulWidget {
  const FengShuiCompassScreen({super.key});

  @override
  State<FengShuiCompassScreen> createState() => _FengShuiCompassScreenState();
}

class _FengShuiCompassScreenState extends State<FengShuiCompassScreen> {
  /// The sensor fires many times a second. A notifier keeps those updates from
  /// rebuilding the page around the compass — only the rose's rotation and the
  /// readouts listen to it.
  final _heading = ValueNotifier<double?>(null);
  StreamSubscription<CompassEvent>? _compassSub;
  bool _sensorAvailable = true;

  /// Heading noise wobbles by fractions of a degree even on a still phone.
  /// Below this nothing visibly moves, so it is not worth a rebuild.
  static const _headingEpsilon = 0.5;

  @override
  void initState() {
    super.initState();
    _initCompass();
  }

  Future<void> _initCompass() async {
    // iOS surfaces heading through CoreLocation, which needs location access.
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      await Geolocator.requestPermission();
    }

    final stream = FlutterCompass.events;
    if (stream == null) {
      if (mounted) setState(() => _sensorAvailable = false);
      return;
    }
    _compassSub = stream.listen((event) {
      final heading = event.heading;
      if (heading == null) return;
      final previous = _heading.value;
      if (previous != null && (heading - previous).abs() < _headingEpsilon) {
        return;
      }
      _heading.value = heading;
    });
  }

  @override
  void dispose() {
    _compassSub?.cancel();
    _heading.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppScaffold(
      bottom: true,
      appBar: DoAppBar(title: l10n.fengShuiCompass),
      body: SingleChildScrollView(
        child: Padding(
          padding: Dimens.screenPadding,
          child: Column(children: [_buildBody(context, l10n)]),
        ).contentConstrainedBox(),
      ),
    );
  }

  Widget _buildBody(BuildContext context, AppLocalizations l10n) {
    if (!_sensorAvailable) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          children: [
            Icon(
              Icons.explore_off_rounded,
              size: 56,
              color: context.theme.colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(l10n.fengShuiNoSensor, textAlign: TextAlign.center),
          ],
        ),
      );
    }

    // Built once and handed to the builder: everything below reacts to the
    // heading through its own listener, so no widget here is rebuilt when the
    // first reading arrives or the phone turns.
    return ValueListenableBuilder<double?>(
      valueListenable: _heading,
      builder: (context, heading, child) {
        if (heading == null) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 80),
            child: CircularProgressIndicator(),
          );
        }
        return child!;
      },
      child: Column(
        children: [
          _buildCompass(context),
          const SizedBox(height: 24),
          _buildFacingCard(context, l10n),
          const SizedBox(height: 14),
          _buildHint(context, l10n),
        ],
      ),
    );
  }

  Widget _buildCompass(BuildContext context) {
    final scheme = context.theme.colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = math.min(constraints.maxWidth, 340.0);
        // The rose is a fixed drawing that only ever rotates. Behind a repaint
        // boundary it is rasterised once and re-used, instead of re-running 32
        // text layouts every time the page scrolls past or the heading ticks.
        final rose = RepaintBoundary(
          child: CustomPaint(
            size: Size.square(size),
            painter: _CompassRosePainter(
              surface: scheme.surface,
              onSurface: scheme.onSurface,
              muted: scheme.onSurfaceVariant,
              ring: scheme.outlineVariant,
              north: scheme.error,
              accent: scheme.primary,
            ),
          ),
        );

        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Rotating compass rose: turn it so geographic North stays put.
              ValueListenableBuilder<double?>(
                valueListenable: _heading,
                child: rose,
                builder: (context, heading, child) => Transform.rotate(
                  angle: -(heading ?? 0) * math.pi / 180,
                  child: child,
                ),
              ),
              // Fixed readout in the center (does not rotate).
              ValueListenableBuilder<double?>(
                valueListenable: _heading,
                builder: (context, heading, _) {
                  final facing = FengShui.of(heading ?? 0);
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${(heading ?? 0).round()}°',
                        style: context.theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: scheme.primary,
                        ),
                      ),
                      Text(
                        '${facing.name} · ${facing.mountain}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  );
                },
              ),
              // Fixed pointer marking the facing direction (phone's top edge).
              Positioned(
                top: 0,
                child: Icon(
                  Icons.arrow_drop_down_rounded,
                  size: 40,
                  color: scheme.primary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFacingCard(BuildContext context, AppLocalizations l10n) {
    final scheme = context.theme.colorScheme;
    return NeuCard(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ValueListenableBuilder<double?>(
          valueListenable: _heading,
          builder: (context, heading, _) {
            final facing = FengShui.of(heading ?? 0);
            // Sitting direction is the opposite bearing.
            final sitting = FengShui.of((heading ?? 0) + 180);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.home_rounded, color: scheme.primary, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      l10n.fengShuiHouseFacing,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    Text(
                      '${facing.name}  ${facing.bearing.round()}°',
                      style: context.theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: scheme.primary,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                _row(context, l10n.fengShuiMountain, facing.mountain),
                const SizedBox(height: 8),
                _row(context, l10n.fengShuiTrigram, facing.trigram),
                const SizedBox(height: 8),
                _row(context, l10n.fengShuiElement, facing.element),
                const SizedBox(height: 8),
                _row(
                  context,
                  l10n.fengShuiSitting,
                  '${sitting.name} · ${sitting.trigram} (${sitting.bearing.round()}°)',
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: TextStyle(color: context.theme.colorScheme.onSurfaceVariant),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildHint(BuildContext context, AppLocalizations l10n) {
    final scheme = context.theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        // A hint is not a panel: the flat sunken fill is how this design says
        // "sits in the page" rather than "lifted off it".
        color: context.neu.sunken,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: scheme.outline),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${l10n.fengShuiHoldFlat}\n${l10n.fengShuiCalibrateHint}',
              style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompassRosePainter extends CustomPainter {
  final Color surface;
  final Color onSurface;
  final Color muted;
  final Color ring;
  final Color north;
  final Color accent;

  _CompassRosePainter({
    required this.surface,
    required this.onSurface,
    required this.muted,
    required this.ring,
    required this.north,
    required this.accent,
  });

  static const _dirLabels = ['B', 'ĐB', 'Đ', 'ĐN', 'N', 'TN', 'T', 'TB'];
  static const _mountains = [
    'Tý', 'Quý', 'Sửu', 'Cấn', 'Dần', 'Giáp', //
    'Mão', 'Ất', 'Thìn', 'Tốn', 'Tỵ', 'Bính',
    'Ngọ', 'Đinh', 'Mùi', 'Khôn', 'Thân', 'Canh',
    'Dậu', 'Tân', 'Tuất', 'Càn', 'Hợi', 'Nhâm',
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;

    // Base disc + outer ring.
    canvas.drawCircle(center, radius - 1, Paint()..color = surface);
    canvas.drawCircle(
      center,
      radius - 1,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = ring,
    );
    canvas.drawCircle(
      center,
      radius * 0.66,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = ring.withValues(alpha: 0.6),
    );

    // 24 mountain ticks + labels (every 15°).
    for (var i = 0; i < 24; i++) {
      final angle = (i * 15) * math.pi / 180 - math.pi / 2;
      final isPrincipal = i % 3 == 0; // the 8 main directions
      final outer = radius - 2;
      final inner = radius * (isPrincipal ? 0.80 : 0.87);
      canvas.drawLine(
        center + Offset(math.cos(angle), math.sin(angle)) * inner,
        center + Offset(math.cos(angle), math.sin(angle)) * outer,
        Paint()
          ..strokeWidth = isPrincipal ? 2 : 1
          ..color = isPrincipal ? accent : muted.withValues(alpha: 0.7),
      );
      _drawText(
        canvas,
        _mountains[i],
        center + Offset(math.cos(angle), math.sin(angle)) * (radius * 0.74),
        angle,
        fontSize: 9,
        color: muted,
      );
    }

    // 8 direction labels on the inner band.
    for (var i = 0; i < 8; i++) {
      final angle = (i * 45) * math.pi / 180 - math.pi / 2;
      final isNorth = i == 0;
      _drawText(
        canvas,
        _dirLabels[i],
        center + Offset(math.cos(angle), math.sin(angle)) * (radius * 0.52),
        angle,
        fontSize: isNorth ? 18 : 15,
        color: isNorth ? north : onSurface,
        bold: true,
      );
    }

    // North needle (points to geographic north as the rose rotates).
    final northTip = center + const Offset(0, 0) + Offset(0, -radius * 0.62);
    final needle = Path()
      ..moveTo(northTip.dx, northTip.dy)
      ..lineTo(center.dx - 7, center.dy)
      ..lineTo(center.dx + 7, center.dy)
      ..close();
    canvas.drawPath(needle, Paint()..color = north);

    canvas.drawCircle(center, 4, Paint()..color = accent);
  }

  /// Laid-out glyphs, keyed by how they look. The 32 labels never change, so
  /// measuring them once covers every later repaint (and both themes).
  static final _textCache = <String, TextPainter>{};

  static TextPainter _textPainter(
    String text,
    double fontSize,
    Color color,
    bool bold,
  ) {
    final key = '$text|$fontSize|${color.toARGB32()}|$bold';
    return _textCache.putIfAbsent(
      key,
      () => TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontSize: fontSize,
            color: color,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(),
    );
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset position,
    double angle, {
    required double fontSize,
    required Color color,
    bool bold = false,
  }) {
    final tp = _textPainter(text, fontSize, color, bold);
    canvas.save();
    canvas.translate(position.dx, position.dy);
    // Keep glyphs radial-upright relative to the rose center.
    canvas.rotate(angle + math.pi / 2);
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CompassRosePainter oldDelegate) {
    return surface != oldDelegate.surface ||
        onSurface != oldDelegate.onSurface ||
        muted != oldDelegate.muted ||
        ring != oldDelegate.ring ||
        north != oldDelegate.north ||
        accent != oldDelegate.accent;
  }
}
