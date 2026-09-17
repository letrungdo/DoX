import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/screen/asset/widgets/asset_refreshable_list.dart';
import 'package:do_x/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(
  WidgetTester tester, {
  required int itemCount,
  required Future<void> Function() onRefresh,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      locale: const Locale('vi'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: AssetRefreshableList(
          itemCount: itemCount,
          emptyMessage: 'Chưa có gì',
          onRefresh: onRefresh,
          itemBuilder: (_, index) =>
              SizedBox(height: 80, child: Text('item $index')),
        ),
      ),
    ),
  );
}

Future<void> _pullDown(WidgetTester tester) async {
  await tester.fling(find.byType(Scrollable), const Offset(0, 320), 1000);
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a list with records refreshes when pulled', (tester) async {
    var refreshed = 0;
    await _pump(tester, itemCount: 6, onRefresh: () async => refreshed++);

    await _pullDown(tester);

    expect(refreshed, 1);
  });

  testWidgets('an empty list can still be pulled', (tester) async {
    // The moment a refresh is most wanted is a list that came back empty, so
    // the empty state has to be draggable rather than a centred label.
    var refreshed = 0;
    await _pump(tester, itemCount: 0, onRefresh: () async => refreshed++);

    expect(find.text('Chưa có gì'), findsOneWidget);
    await _pullDown(tester);

    expect(refreshed, 1);
  });
}
