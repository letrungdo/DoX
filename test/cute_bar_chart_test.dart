import 'package:do_x/widgets/chart/cute_bar_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(width: 360, child: child),
        ),
      ),
    );
  }

  testWidgets('renders single-series daily chart and handles taps', (tester) async {
    final items = List.generate(
      14,
      (i) => CuteBarChartItem(label: "${i + 1}/7", value: (i % 5) + 1.0),
    );
    await tester.pumpWidget(wrap(CuteBarChart(items: items, primaryColor: Colors.teal)));
    expect(tester.takeException(), isNull);

    // Header shows the last item by default; tapping selects another group.
    expect(find.text("14/7"), findsOneWidget);
    await tester.tapAt(tester.getTopLeft(find.byType(CustomPaint).last) + const Offset(5, 50));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text("1/7"), findsOneWidget);
  });

  testWidgets('renders grouped monthly chart with compare series', (tester) async {
    final items = List.generate(
      12,
      (i) => CuteBarChartItem(label: "${i + 1}/26", value: 100.0 + i, compareValue: 90.0 + i),
    );
    await tester.pumpWidget(
      wrap(CuteBarChart(items: items, primaryColor: Colors.teal, compareColor: Colors.orange)),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('handles empty and zero-value data', (tester) async {
    await tester.pumpWidget(wrap(CuteBarChart(items: const [], primaryColor: Colors.teal)));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      wrap(
        CuteBarChart(
          items: const [CuteBarChartItem(label: "1/7", value: 0)],
          primaryColor: Colors.teal,
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
