import 'package:do_x/theme/app_theme.dart';
import 'package:do_x/widgets/surface/app_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(WidgetTester tester, {VoidCallback? onTap}) {
    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Center(
            child: AppCard(onTap: onTap, child: const Text('Chi phí chung')),
          ),
        ),
      ),
    );
  }

  testWidgets('a tappable card sinks instead of rippling', (tester) async {
    var taps = 0;
    await pump(tester, onTap: () => taps++);

    // An ink ripple would recolour the panel, which is what the sink replaces.
    expect(find.byType(InkWell), findsNothing);

    double scale() =>
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale;
    expect(scale(), 1);

    await tester.tap(find.text('Chi phí chung'));
    await tester.pump();
    expect(scale(), lessThan(1));

    await tester.pumpAndSettle();
    expect(scale(), 1);
    expect(taps, 1);
  });

  testWidgets('a plain card has nothing to press', (tester) async {
    await pump(tester);
    expect(find.byType(AnimatedScale), findsNothing);
  });

  testWidgets('a pressed card lays a state layer over its fill', (
    tester,
  ) async {
    await pump(tester, onTap: () {});

    Color? fill() =>
        (tester
                    .widget<AnimatedContainer>(find.byType(AnimatedContainer))
                    .decoration!
                as BoxDecoration)
            .color;
    final resting = fill();

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Chi phí chung')),
    );
    await tester.pump();
    expect(fill(), isNot(resting));

    await gesture.up();
    await tester.pumpAndSettle();
    expect(fill(), resting);
  });
}
