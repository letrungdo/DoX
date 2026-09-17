import 'package:do_x/theme/app_theme.dart';
import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/model/asset/asset_gold.dart';
import 'package:do_x/model/asset/asset_investment.dart';
import 'package:do_x/model/asset/asset_saving.dart';
import 'package:do_x/model/asset/gold_type.dart';
import 'package:do_x/screen/asset/widgets/gold_list.dart';
import 'package:do_x/screen/asset/widgets/investment_list.dart';
import 'package:do_x/screen/asset/widgets/saving_list.dart';
import 'package:do_x/view_model/asset_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// The narrowest phone the app still has to look right on.
const _narrow = Size(320, 640);

Future<void> _pump(
  WidgetTester tester,
  Widget list, {
  Size size = _narrow,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ChangeNotifierProvider(
      create: (_) => AssetViewModel(),
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        locale: const Locale('vi'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: list),
      ),
    ),
  );
  await tester.pump();
}

AssetGold _gold({double quantity = 2, double buyPrice = 90000000}) {
  return AssetGold(
    id: 'g1',
    goldType: GoldAssetType.ring9999.label,
    quantity: quantity,
    buyPrice: buyPrice,
    buyDate: DateTime.now().subtract(const Duration(days: 389)),
  );
}

void main() {
  group('gold tile', () {
    testWidgets('lays out on a narrow phone without overflowing', (
      tester,
    ) async {
      await _pump(tester, GoldList(gold: [_gold()]));

      expect(tester.takeException(), isNull);
      expect(find.text(GoldAssetType.ring9999.label), findsOneWidget);
    });

    testWidgets('the widest plausible figures still fit', (tester) async {
      // A hundred taels bought at nine figures: every column at full width.
      await _pump(
        tester,
        GoldList(gold: [_gold(quantity: 100.5, buyPrice: 143500000)]),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('an empty list says so instead of showing a bare tile', (
      tester,
    ) async {
      await _pump(tester, const GoldList(gold: []));

      expect(tester.takeException(), isNull);
      expect(find.byType(ListView), findsNothing);
    });
  });

  group('savings tile', () {
    AssetSaving saving({int? termMonths, int startedDaysAgo = 200}) {
      return AssetSaving(
        id: 's1',
        bankName: 'Vietcombank',
        amount: 200000000,
        interestRate: 6.8,
        startDate: DateTime.now().subtract(Duration(days: startedDaysAgo)),
        termMonths: termMonths,
      );
    }

    testWidgets('a running deposit fits on a narrow phone', (tester) async {
      await _pump(tester, SavingList(savings: [saving()]));

      expect(tester.takeException(), isNull);
      expect(find.text('Vietcombank'), findsOneWidget);
    });

    testWidgets('a matured deposit says so instead of a monthly figure', (
      tester,
    ) async {
      await _pump(
        tester,
        SavingList(savings: [saving(termMonths: 3, startedDaysAgo: 400)]),
      );

      expect(tester.takeException(), isNull);
      expect(find.textContaining('Đã đáo hạn'), findsOneWidget);
      expect(find.textContaining('/tháng'), findsNothing);
    });
  });

  group('investment tile', () {
    testWidgets('a dollar-quoted holding fits on a narrow phone', (
      tester,
    ) async {
      final investment = AssetInvestment(
        id: 'i1',
        symbol: 'XAUUSD',
        type: InvestmentType.stock,
        quantity: 2,
        buyPrice: 3600,
        buyDate: DateTime.now().subtract(const Duration(days: 389)),
      );

      await _pump(tester, InvestmentList(investments: [investment]));

      expect(tester.takeException(), isNull);
      expect(find.text('XAUUSD'), findsOneWidget);
    });

    testWidgets('a đồng-quoted holding fits too', (tester) async {
      final investment = AssetInvestment(
        id: 'i2',
        symbol: 'VNIndex',
        type: InvestmentType.stock,
        quantity: 1000,
        buyPrice: 1250000,
        buyDate: DateTime.now().subtract(const Duration(days: 40)),
      );

      await _pump(tester, InvestmentList(investments: [investment]));

      expect(tester.takeException(), isNull);
    });
  });
}
