import 'package:auto_size_text/auto_size_text.dart';
import 'package:do_x/screen/news/widgets/fx_rate_row.dart';
import 'package:do_x/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The two rows as the news page builds them: one with a source name and a
/// chevron behind it, one with neither.
///
/// Deliberately wider than a phone. The bug this guards against only shows
/// when the caption has slack to leave behind: on a narrow row the caption is
/// squeezed to exactly its share and nothing is stranded, which is why a
/// phone-width test went on passing while the real page was visibly wrong.
Future<void> _pumpRows(
  WidgetTester tester, {
  String? caption = 'Google',
}) async {
  tester.view.physicalSize = const Size(800, 400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              FxRateRow(
                pair: 'JPY/VND',
                color: Colors.blue,
                softColor: Colors.blue.shade50,
                caption: caption,
                value: '166.495',
                onTap: () {},
              ),
              FxRateRow(
                pair: 'USDT/VND',
                color: Colors.green,
                softColor: Colors.green.shade50,
                value: '25,813',
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

double _valueRight(WidgetTester tester, String value) {
  return tester
      .getRect(
        find.byWidgetPredicate((w) => w is AutoSizeText && w.data == value),
      )
      .right;
}

void main() {
  testWidgets('both rates end on the same line', (tester) async {
    await _pumpRows(tester);

    expect(
      _valueRight(tester, '166.495'),
      _valueRight(tester, '25,813'),
      reason: 'a row with a caption and a chevron must not pull its figure in',
    );
  });

  testWidgets('the figure sits a chevron in from the card edge', (
    tester,
  ) async {
    await _pumpRows(tester);

    final cardRight = tester.getRect(find.byType(FxRateRow).first).right;
    // 11 of card padding, then the chevron's reserved slot and the gap before
    // it — the figure stops exactly there, on both rows.
    const expectedInset = 11 + FxRateRow.chevronSize + 8;

    expect(_valueRight(tester, '166.495'), cardRight - expectedInset);
  });

  testWidgets('a row with no caption still lines up', (tester) async {
    await _pumpRows(tester, caption: null);

    expect(_valueRight(tester, '166.495'), _valueRight(tester, '25,813'));
  });

  testWidgets('a rate that has not arrived leaves the slot blank', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(
          body: FxRateRow(
            pair: 'USDT/VND',
            color: Colors.green,
            softColor: Colors.white,
            value: null,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('-'), findsNothing);
  });
}
