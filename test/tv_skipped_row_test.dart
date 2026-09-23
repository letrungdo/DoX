import 'package:do_x/utils/device_type.dart';
import 'package:do_x/widgets/app_scaffold.dart';
import 'package:do_x/widgets/tv_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _button(FocusNode node, String label) =>
    TextButton(focusNode: node, onPressed: () {}, child: Text(label));

void main() {
  setUp(() => deviceType.isTv = true);
  tearDown(() => deviceType.isTv = false);

  /// Shaped like the news page: a narrow toggle at the left of one card, a
  /// small button at the right end of the heading under it, and full-width
  /// rows below that.
  Future<({FocusNode toggle, FocusNode picker, FocusNode row})> pump(
    WidgetTester tester, {
    Widget? beside,
  }) async {
    final toggle = FocusNode(debugLabel: 'toggle');
    final picker = FocusNode(debugLabel: 'picker');
    final row = FocusNode(debugLabel: 'row');
    addTearDown(toggle.dispose);
    addTearDown(picker.dispose);
    addTearDown(row.dispose);

    final list = ListView(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: _button(toggle, 'details'),
        ),
        Align(alignment: Alignment.centerRight, child: _button(picker, 'pick')),
        SizedBox(width: double.infinity, child: _button(row, 'first row')),
        for (var i = 0; i < 3; i++)
          SizedBox(
            width: double.infinity,
            child: TextButton(onPressed: () {}, child: Text('row $i')),
          ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => TvShell(child: child!),
        home: AppScaffold(
          body: beside == null
              ? list
              : Row(
                  children: [
                    Expanded(child: list),
                    beside,
                  ],
                ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (toggle: toggle, picker: picker, row: row);
  }

  testWidgets('down does not jump over a control on the row below', (
    tester,
  ) async {
    final nodes = await pump(tester);
    nodes.toggle.requestFocus();
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(nodes.picker.hasPrimaryFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(nodes.row.hasPrimaryFocus, isTrue);
  });

  testWidgets('up does not jump over it either', (tester) async {
    final nodes = await pump(tester);
    nodes.row.requestFocus();
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(nodes.picker.hasPrimaryFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(nodes.toggle.hasPrimaryFocus, isTrue);
  });

  testWidgets('a panel beside the list is left to left and right', (
    tester,
  ) async {
    final side = FocusNode(debugLabel: 'side');
    addTearDown(side.dispose);
    // Level with the gap between the toggle and the first row, but outside
    // the list the remote is walking down.
    final nodes = await pump(
      tester,
      beside: SizedBox(
        width: 120,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [const SizedBox(height: 50), _button(side, 'side')],
        ),
      ),
    );
    nodes.toggle.requestFocus();
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(side.hasFocus, isFalse);
  });
}
