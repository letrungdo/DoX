import 'package:financial_chart/financial_chart.dart';
import 'package:flutter/material.dart';

class ChartThemeLight extends GTheme {
  static const String themeName = 'light';
  ChartThemeLight()
    : super(
        name: themeName,
        backgroundTheme: backgroundThemeDefault,
        panelTheme: panelThemeDefault,
        pointAxisTheme: pointAxisThemeDefault,
        valueAxisTheme: valueAxisThemeDefault,
        crosshairTheme: crosshairThemeDefault,
        tooltipTheme: tooltipThemeDefault,
        splitterTheme: splitterThemeDefault,
        graphThemes: {
          GGraph.typeName: GGraphTheme(axisMarkerTheme: axisMarkerThemeDefault, overlayMarkerTheme: overlayMarkerThemeDefault),
          GGraphGrids.typeName: gridsGraphTheme,
          GGraphOhlc.typeName: ohlcGraphTheme,
          GGraphLine.typeName: lineGraphTheme,
          GGraphBar.typeName: barGraphTheme,
          GGraphArea.typeName: areaGraphTheme,
        },
        axisMarkerTheme: axisMarkerThemeDefault,
        overlayMarkerTheme: overlayMarkerThemeDefault,
      );

  static final GBackgroundTheme backgroundThemeDefault = GBackgroundTheme(
    style: PaintStyle(), //
  );

  static final GPanelTheme panelThemeDefault = GPanelTheme(
    style: PaintStyle(
      fillColor: Colors.transparent, //
      strokeColor: Colors.transparent,
      strokeWidth: 0,
    ),
  );

  static final GAxisTheme pointAxisThemeDefault = GAxisTheme(
    lineStyle: PaintStyle(strokeColor: const Color(0xFF000000), strokeWidth: 1.0),
    tickerLength: 5.0,
    tickerStyle: PaintStyle(strokeColor: const Color(0xFF000000), strokeWidth: 1.0),
    selectionStyle: PaintStyle(fillColor: const Color(0x552222FF), strokeColor: const Color(0xAA2222FF), strokeWidth: 1.0),
    labelTheme: GAxisLabelTheme(
      labelStyle: LabelStyle(
        textStyle: const TextStyle(color: Color(0xFF000000), fontSize: 10.0),
        backgroundStyle: PaintStyle(),
        backgroundPadding: const EdgeInsets.all(2),
        backgroundCornerRadius: 2,
      ),
    ),
  );

  static final GAxisTheme valueAxisThemeDefault = GAxisTheme(
    lineStyle: PaintStyle(strokeColor: const Color(0xFF000000), strokeWidth: 1.0),
    tickerLength: 5.0,
    tickerStyle: PaintStyle(strokeColor: const Color(0xFF000000), strokeWidth: 1.0),
    selectionStyle: PaintStyle(fillColor: const Color(0x552222FF), strokeColor: const Color(0xAA2222FF), strokeWidth: 1.0),
    labelTheme: GAxisLabelTheme(
      labelStyle: LabelStyle(
        textStyle: const TextStyle(color: Color(0xFF000000), fontSize: 10.0),
        backgroundStyle: PaintStyle(),
        backgroundPadding: const EdgeInsets.all(2),
        backgroundCornerRadius: 2,
      ),
    ),
  );

  static final GCrosshairTheme crosshairThemeDefault = GCrosshairTheme(
    lineStyle: PaintStyle(strokeColor: const Color(0xFFA0A0A0), strokeWidth: 1, dash: const [5, 5]),
    pointLabelTheme: GAxisLabelTheme(
      labelStyle: LabelStyle(
        textStyle: const TextStyle(color: Color(0xFFFFFFFF), fontSize: 10.0),
        backgroundStyle: PaintStyle(fillColor: const Color(0xFF000000)),
        backgroundPadding: const EdgeInsets.all(2),
        backgroundCornerRadius: 2,
      ),
    ),
    valueLabelTheme: GAxisLabelTheme(
      labelStyle: LabelStyle(
        textStyle: const TextStyle(color: Color(0xFFFFFFFF), fontSize: 10.0),
        backgroundStyle: PaintStyle(fillColor: const Color(0xFF000000)),
        backgroundPadding: const EdgeInsets.all(2),
        backgroundCornerRadius: 2,
      ),
    ),
  );

  static final GTooltipTheme tooltipThemeDefault = GTooltipTheme(
    frameStyle: PaintStyle(fillColor: Colors.white.withAlpha(180), strokeColor: Colors.grey, strokeWidth: 1),
    pointStyle: LabelStyle(textStyle: const TextStyle(color: Colors.black, fontSize: 12.0, fontWeight: FontWeight.bold)),
    labelStyle: LabelStyle(textStyle: const TextStyle(color: Colors.black, fontSize: 12.0, fontWeight: FontWeight.bold)),
    valueStyle: LabelStyle(textStyle: const TextStyle(color: Colors.black, fontSize: 12.0)),
    pointHighlightStyle: PaintStyle(fillColor: Colors.blue.withAlpha(120)),
    valueHighlightStyle: PaintStyle(strokeColor: Colors.blue, strokeWidth: 1),
  );

  static final GSplitterTheme splitterThemeDefault = GSplitterTheme(
    lineStyle: PaintStyle(strokeColor: Colors.grey.withAlpha(100), strokeWidth: 4),
    handleStyle: PaintStyle(fillColor: Colors.white, strokeColor: Colors.grey),
    handleLineStyle: PaintStyle(strokeColor: Colors.black, strokeWidth: 0.5),
    handleWidth: 80,
    handleBorderRadius: 4,
  );

  static final GGraphOhlcTheme ohlcGraphTheme = GGraphOhlcTheme(
    barStylePlus: PaintStyle(fillColor: Colors.redAccent, strokeWidth: 1, strokeColor: Colors.redAccent),
    barStyleMinus: PaintStyle(fillColor: Colors.teal, strokeWidth: 1, strokeColor: Colors.teal),
    axisMarkerTheme: axisMarkerThemeDefault,
    highlightMarkerTheme: graphHighlightMarkThemeDefault,
  );

  static final GGraphLineTheme lineGraphTheme = GGraphLineTheme(
    lineStyle: PaintStyle(strokeColor: Colors.blue, strokeWidth: 1),
    pointStyle: PaintStyle(fillColor: Colors.blue),
    axisMarkerTheme: axisMarkerThemeDefault,
    highlightMarkerTheme: graphHighlightMarkThemeDefault,
  );

  static final GGraphGridsTheme gridsGraphTheme = GGraphGridsTheme(
    lineStyle: PaintStyle(strokeColor: const Color(0xFFC0C0C0), strokeWidth: 0.5),
    selectionStyle: PaintStyle(fillColor: const Color(0x332222FF), strokeColor: const Color(0xAA2222FF), strokeWidth: 1.0),
    axisMarkerTheme: axisMarkerThemeDefault,
    overlayMarkerTheme: overlayMarkerThemeDefault,
    highlightMarkerTheme: graphHighlightMarkThemeDefault,
  );

  static final GGraphBarTheme barGraphTheme = GGraphBarTheme(
    barStyleAboveBase: PaintStyle(fillColor: Colors.teal.withAlpha(150)),
    barStyleBelowBase: PaintStyle(fillColor: Colors.red.withAlpha(150)),
    axisMarkerTheme: axisMarkerThemeDefault,
    overlayMarkerTheme: overlayMarkerThemeDefault,
    highlightMarkerTheme: graphHighlightMarkThemeDefault,
  );

  static final GGraphAreaTheme areaGraphTheme = GGraphAreaTheme(
    styleAboveBase: PaintStyle(strokeColor: Colors.blue, strokeWidth: 1, fillColor: Colors.blue.withAlpha(100)),
    styleBelowBase: PaintStyle(strokeColor: Colors.red, strokeWidth: 1, fillColor: Colors.red.withAlpha(100)),
    axisMarkerTheme: axisMarkerThemeDefault,
    overlayMarkerTheme: overlayMarkerThemeDefault,
    highlightMarkerTheme: graphHighlightMarkThemeDefault,
  );

  static final GAxisMarkerTheme axisMarkerThemeDefault = GAxisMarkerTheme(
    labelTheme: GAxisLabelTheme(
      labelStyle: LabelStyle(
        textStyle: const TextStyle(color: Color(0xFFEEEEEE), fontSize: 10.0),
        backgroundStyle: PaintStyle(fillColor: const Color(0xFF0000EE)),
        backgroundPadding: const EdgeInsets.all(2),
        backgroundCornerRadius: 2,
      ),
    ),
    rangeStyle: PaintStyle(fillColor: Colors.blue.withAlpha(150)),
  );

  static final GOverlayMarkerTheme overlayMarkerThemeDefault = GOverlayMarkerTheme(
    markerStyle: PaintStyle(fillColor: Colors.blueAccent.withAlpha(120), strokeColor: Colors.blue, strokeWidth: 2),
    controlPointsStyle: PaintStyle(fillColor: Colors.white, strokeColor: Colors.blueAccent, strokeWidth: 2),
    labelStyle: LabelStyle(
      textStyle: const TextStyle(color: Colors.black, fontSize: 10.0),
      backgroundStyle: PaintStyle(fillColor: Colors.white, strokeColor: Colors.black, strokeWidth: 1),
      backgroundPadding: const EdgeInsets.all(5),
      backgroundCornerRadius: 5,
    ),
  );

  static final GGraphHighlightMarkerTheme graphHighlightMarkThemeDefault = GGraphHighlightMarkerTheme(
    style: PaintStyle(strokeColor: Colors.black54, strokeWidth: 1, fillColor: Colors.white),
    size: 4.0,
    interval: 100.0,
    crosshairHighlightSize: 4.0,
  );
}
