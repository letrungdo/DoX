import 'package:do_x/theme/app_theme.dart';
import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/model/asset/asset_gold.dart';
import 'package:do_x/model/asset/asset_investment.dart';
import 'package:do_x/model/asset/asset_saving.dart';
import 'package:do_x/model/asset/gold_type.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:do_x/screen/asset/widgets/asset_tile.dart';
import 'package:do_x/screen/asset/widgets/bank_logo.dart';
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

/// Every amount in a tile ends on one line down the right of the card — the
/// headline figure and the figure in the row beneath it especially, which used
/// to stop at different places and read as a misalignment.
void _expectAmountsFlushRight(WidgetTester tester) {
  final cardRight = tester.getRect(find.byType(AssetTileCard).first).right;
  final expected = cardRight - AssetTileCard.sidePadding;
  final rights = <String, double>{};

  for (final text in tester.widgetList<AutoSizeText>(
    find.byType(AutoSizeText),
  )) {
    final data = text.data ?? '';
    // The right-hand column is the one carrying a figure.
    if (!data.startsWith('+') && !data.startsWith('-') && !data.endsWith('đ')) {
      continue;
    }
    rights[data] = tester.getRect(find.byWidget(text)).right;
  }

  expect(rights, isNotEmpty, reason: 'no amounts found to check');
  for (final entry in rights.entries) {
    expect(
      entry.value,
      expected,
      reason: '"${entry.key}" should end on the tile\'s right-hand line',
    );
  }
}

void main() {
  group('gold tile', () {
    testWidgets('lays out on a narrow phone without overflowing', (
      tester,
    ) async {
      await _pump(tester, GoldList(gold: [_gold()]));

      expect(tester.takeException(), isNull);
      expect(find.text(GoldAssetType.ring9999.label), findsOneWidget);
      _expectAmountsFlushRight(tester);
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
      expect(find.byType(AssetTileCard), findsNothing);
      // The empty state is a scroll view, not a bare label: that is what lets
      // it be pulled down to refresh.
      expect(find.text('Chưa có ghi chép mua vàng nào.'), findsOneWidget);
      expect(find.byType(Scrollable), findsOneWidget);
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
      _expectAmountsFlushRight(tester);
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

  _bankLogoTests();

  group('crypto tile', () {
    testWidgets('a coin holding fits on a narrow phone', (tester) async {
      final investment = AssetInvestment(
        id: 'i1',
        symbol: 'BTCUSDT',
        type: InvestmentType.crypto,
        quantity: 0.25,
        buyPrice: 76559.94,
        buyDate: DateTime.now().subtract(const Duration(days: 389)),
      );

      await _pump(tester, InvestmentList(investments: [investment]));

      expect(tester.takeException(), isNull);
      // The tile is headed by the coin, not by the pair it trades in.
      expect(find.text('BTC'), findsWidgets);
      expect(find.text('BTCUSDT'), findsNothing);
      _expectAmountsFlushRight(tester);
    });

    testWidgets('a coin worth a fraction of a cent fits too', (tester) async {
      final investment = AssetInvestment(
        id: 'i2',
        symbol: 'PEPEUSDT',
        type: InvestmentType.crypto,
        quantity: 120000000,
        buyPrice: 0.00000812,
        buyDate: DateTime.now().subtract(const Duration(days: 40)),
      );

      await _pump(tester, InvestmentList(investments: [investment]));

      expect(tester.takeException(), isNull);
      // Rounded to two decimals this price reads as "0.00 USDT".
      expect(find.textContaining('0.00000812'), findsOneWidget);
    });
  });
}

void _bankLogoTests() {
  group('bank logo', () {
    Future<void> pump(WidgetTester tester, String? logo) {
      return tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Center(child: BankLogo(logo: logo)),
          ),
        ),
      );
    }

    testWidgets('a wordmark gets a chip wider than it is tall', (tester) async {
      await pump(tester, 'https://api.vietqr.io/img/VCB.png');

      final size = tester.getSize(find.byType(BankLogo));
      expect(size.height, 44);
      // Room for a 3:1 wordmark to be read, which a 44px circle never gives it.
      expect(size.width, greaterThan(size.height));
    });

    testWidgets('a bank with no logo keeps the round badge', (tester) async {
      await pump(tester, null);

      expect(find.byType(AssetTileBadge), findsOneWidget);
      expect(tester.getSize(find.byType(BankLogo)), const Size.square(44));
    });
  });
}
