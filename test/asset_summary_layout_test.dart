import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/model/asset/asset_summary.dart';
import 'package:do_x/screen/asset/widgets/asset_summary_card.dart';
import 'package:do_x/screen/asset/widgets/asset_summary_stats.dart';
import 'package:do_x/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The narrowest phone the app still has to look right on.
const _narrow = Size(320, 640);

AssetSummary _summary({
  AssetPerformer? best,
  AssetPerformer? worst,
  DateTime? nextMaturity,
}) {
  return AssetSummary(
    savings: const AssetClassStat(cost: 100000000, value: 107000000, count: 3),
    investments: const AssetClassStat(
      cost: 50000000,
      value: 43000000,
      count: 2,
    ),
    gold: const AssetClassStat(cost: 180000000, value: 200000000, count: 1),
    monthlyInterest: 583333,
    monthlyProfit: 1250000,
    averageAnnualReturn: 8.42,
    maturedSavingsCount: 1,
    nextMaturityDate: nextMaturity,
    nextMaturityBank: nextMaturity == null ? null : 'Ngân hàng TMCP Kỹ Thương',
    best: best,
    worst: worst,
  );
}

Future<void> _pump(WidgetTester tester, AssetSummary summary) async {
  tester.view.physicalSize = _narrow;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      locale: const Locale('vi'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: Column(
            children: [
              AssetSummaryCard(summary: summary),
              AssetReturnCard(summary: summary),
              AssetAllocationCard(summary: summary),
              AssetPerformanceCard(summary: summary),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('asset summary figures', () {
    test('totals add the three classes up and price the gain against cost', () {
      final summary = _summary();

      expect(summary.totalAssets, 350000000);
      expect(summary.totalCost, 330000000);
      expect(summary.totalProfitLoss, 20000000);
      expect(summary.totalProfitLossPercent, closeTo(6.06, 0.01));
    });

    test('a class share is measured against what is held today', () {
      final summary = _summary();

      expect(summary.shareOf(summary.gold), closeTo(57.14, 0.01));
      expect(
        summary.shareOf(summary.savings) +
            summary.shareOf(summary.investments) +
            summary.shareOf(summary.gold),
        closeTo(100, 0.01),
      );
    });

    test('the yearly figure follows the rate, sign included', () {
      expect(_summary().estimatedYearlyProfit, closeTo(29470000, 1));
    });

    test('an empty portfolio divides by nothing', () {
      const empty = AssetSummary(
        savings: AssetClassStat.empty(),
        investments: AssetClassStat.empty(),
        gold: AssetClassStat.empty(),
        monthlyInterest: 0,
        monthlyProfit: 0,
        averageAnnualReturn: 0,
        maturedSavingsCount: 0,
      );

      expect(empty.totalProfitLossPercent, 0);
      expect(empty.shareOf(empty.gold), 0);
      expect(empty.savings.profitLossPercent, 0);
    });
  });

  group('asset summary layout', () {
    testWidgets('the cards fit a narrow phone', (tester) async {
      await _pump(
        tester,
        _summary(
          best: const AssetPerformer(
            name: 'Vàng nhẫn PNJ 999.9',
            profitLoss: 20000000,
            profitLossPercent: 11.11,
          ),
          worst: const AssetPerformer(
            name: 'BTC',
            profitLoss: -7000000,
            profitLossPercent: -14,
          ),
          nextMaturity: DateTime.now().add(const Duration(days: 45)),
        ),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('every figure ends on the card\'s right edge', (tester) async {
      await _pump(
        tester,
        _summary(nextMaturity: DateTime.now().add(const Duration(days: 45))),
      );

      for (final (card, statRowsOnly) in [
        (find.byType(AssetReturnCard), false),
        (find.byType(AssetAllocationCard), false),
        // The summary card's headline is centred by design; only the stat
        // lines folded into it below belong to the right-hand column.
        (find.byType(AssetSummaryCard), true),
      ]) {
        final cardRight = tester.getRect(card).right;
        final figures = statRowsOnly
            ? find.descendant(
                of: find.descendant(
                  of: card,
                  matching: find.byType(AssetStatRow),
                ),
                matching: find.byType(Text),
              )
            : find.descendant(of: card, matching: find.byType(Text));
        final rights = <String, double>{};

        for (final text in tester.widgetList<Text>(figures)) {
          final data = text.data ?? '';
          // The right-hand column is the one carrying a figure.
          if (!data.startsWith('+') &&
              !data.startsWith('-') &&
              !data.startsWith('≈') &&
              !data.endsWith('đ')) {
            continue;
          }
          rights[data] = tester.getRect(find.byWidget(text)).right;
        }

        expect(rights, isNotEmpty);
        for (final entry in rights.entries) {
          expect(
            entry.value,
            // The card's own padding is all that stands between the figure and
            // the edge.
            closeTo(cardRight - 16, 1),
            reason: '"${entry.key}" stops short of the card edge',
          );
        }
      }
    });

    testWidgets('the performance card stays away with nothing to rank', (
      tester,
    ) async {
      await _pump(tester, _summary());

      expect(find.byType(AssetPerformanceCard), findsOneWidget);
      expect(tester.takeException(), isNull);
      // Nothing to name, so the card draws nothing rather than an empty panel.
      expect(tester.getSize(find.byType(AssetPerformanceCard)), Size.zero);
    });
  });
}
