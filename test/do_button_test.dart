import 'package:do_x/widgets/button/button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Lays the button out the way a form does: a stretching column inside a box
/// of a known width.
Future<void> _pump(WidgetTester tester, {required bool isBusy}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 300,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                DoButton(
                  isBusy: isBusy,
                  text: 'Cập nhật mật khẩu',
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('going busy does not resize a stretched button', (tester) async {
    await _pump(tester, isBusy: false);
    final idleWidth = tester.getSize(find.byType(ElevatedButton)).width;
    expect(idleWidth, 300);

    await _pump(tester, isBusy: true);
    // Used to collapse to the width of the label, leaving the spinner beside
    // the button instead of on top of it.
    expect(tester.getSize(find.byType(ElevatedButton)).width, idleWidth);
  });

  testWidgets('a button its parent did not stretch still hugs its label', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: DoButton(isBusy: true, text: 'OK', onPressed: () {}),
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byType(ElevatedButton)).width, lessThan(300));
  });
}
