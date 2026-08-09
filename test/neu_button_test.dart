import 'package:do_x/theme/app_theme.dart';
import 'package:do_x/widgets/neu/neu_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double _scale(WidgetTester tester) =>
    tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale;

void main() {
  Future<void> pump(WidgetTester tester, {VoidCallback? onPressed}) {
    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Center(
            child: NeuButton(onPressed: onPressed, child: const Text('Lưu')),
          ),
        ),
      ),
    );
  }

  testWidgets('a tap too quick to animate still shows the button sink', (
    tester,
  ) async {
    var taps = 0;
    await pump(tester, onPressed: () => taps++);
    expect(_scale(tester), 1);

    // Down and straight back up, faster than the sink takes to travel.
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Lưu')),
    );
    await tester.pump();
    expect(_scale(tester), lessThan(1));

    await gesture.up();
    await tester.pump();
    expect(
      _scale(tester),
      lessThan(1),
      reason: 'the press is held until the sink has finished',
    );

    await tester.pumpAndSettle();
    expect(_scale(tester), 1);
    expect(taps, 1);
  });

  testWidgets('a disabled button does not move', (tester) async {
    await pump(tester);

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Lưu')),
    );
    await tester.pump();
    expect(_scale(tester), 1);
    await gesture.up();
  });
}
