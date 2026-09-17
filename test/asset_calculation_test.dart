import 'package:do_x/constants/enum/market_code.dart';
import 'package:do_x/model/asset/asset_gold.dart';
import 'package:do_x/model/asset/asset_investment.dart';
import 'package:do_x/model/asset/asset_saving.dart';
import 'package:do_x/model/asset/gold_type.dart';
import 'package:do_x/extensions/number_extensions.dart';
import 'package:do_x/model/fx/gold_model.dart';
import 'package:do_x/screen/asset/widgets/asset_tile_format.dart';
import 'package:do_x/view_model/asset_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

AssetSaving _saving({
  required DateTime startDate,
  int? termMonths,
  double amount = 100000000,
  double interestRate = 6,
}) {
  return AssetSaving(
    id: 'id',
    bankName: 'VCB',
    amount: amount,
    interestRate: interestRate,
    startDate: startDate,
    termMonths: termMonths,
  );
}

void main() {
  // The view model notifies through the scheduler, which needs a binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('savings interest', () {
    test('an open-ended deposit accrues for as long as it is held', () {
      final saving = _saving(
        startDate: DateTime.now().subtract(const Duration(days: 365)),
      );

      expect(saving.accruedInterest, closeTo(6000000, 20000));
      expect(saving.monthlyInterest, closeTo(500000, 1));
    });

    test('interest stops at maturity instead of running on forever', () {
      // A 12-month deposit opened three years ago pays one year of interest,
      // not three.
      final saving = _saving(
        startDate: DateTime.now().subtract(const Duration(days: 365 * 3)),
        termMonths: 12,
      );

      expect(saving.isMatured, isTrue);
      expect(saving.accruedInterest, closeTo(6000000, 60000));
      expect(saving.monthlyInterest, 0);
    });

    test('a term still running accrues up to today', () {
      final saving = _saving(
        startDate: DateTime.now().subtract(const Duration(days: 180)),
        termMonths: 12,
      );

      expect(saving.isMatured, isFalse);
      expect(saving.accruedInterest, closeTo(2958904, 20000));
      expect(saving.currentValue, closeTo(102958904, 20000));
    });

    test('a deposit opened today has accrued nothing', () {
      final saving = _saving(startDate: DateTime.now(), termMonths: 6);

      expect(saving.accruedInterest, 0);
    });
  });

  group('gold pricing', () {
    final prices = [
      const GoldSymbol(code: 'SJC_HCM', bid: 143500000, ask: 146500000),
      const GoldSymbol(code: 'PNJ_RING_9999', bid: 143500000, ask: 146500000),
    ];

    test('each type resolves to the quote that backs it', () {
      expect(prices.findPrice(GoldAssetType.sjcPiece), 143500000);
      expect(prices.findPrice(GoldAssetType.ring9999), 143500000);
    });

    test('a quote that is missing yields null rather than a stale price', () {
      expect(<GoldSymbol>[].findPrice(GoldAssetType.sjcPiece), isNull);
    });

    test('every type points at a code the price feed publishes', () {
      const published = {'SJC_HCM', 'PNJ_RING_9999'};

      for (final type in GoldAssetType.values) {
        expect(
          published,
          contains(type.code),
          reason: '${type.label} is priced by a code nothing writes',
        );
      }
    });

    test('a stored label still maps back to its type', () {
      for (final type in GoldAssetType.values) {
        expect(GoldAssetType.fromLabel(type.label), type);
      }
      expect(GoldAssetType.fromLabel('Vàng chưa từng có'), isNull);
    });
  });

  group('sell price override', () {
    AssetGold gold() => AssetGold(
      id: 'g1',
      goldType: GoldAssetType.sjcPiece.label,
      quantity: 2,
      buyPrice: 100000000,
      buyDate: DateTime.now().subtract(const Duration(days: 365)),
    );

    test('without one, a holding falls back to what was paid', () {
      // Nothing has been fetched in this view model, so there is no quote to
      // price it at.
      expect(AssetViewModel().getCurrentGoldPrice(gold()), 100000000);
    });

    test('a hand-typed price values every holding of that kind', () {
      final vm = AssetViewModel()
        ..setGoldSellPrice(GoldAssetType.sjcPiece.label, 143500000);

      expect(vm.goldSellPrice(GoldAssetType.sjcPiece.label), 143500000);
      expect(vm.getCurrentGoldPrice(gold()), 143500000);
      // A second holding of the same kind, bought at a different price on a
      // different day, is valued at the same price today.
      expect(
        vm.getCurrentGoldPrice(
          AssetGold(
            id: 'g2',
            goldType: GoldAssetType.sjcPiece.label,
            quantity: 1,
            buyPrice: 80000000,
            buyDate: DateTime.now(),
          ),
        ),
        143500000,
      );
    });

    test('another kind of gold keeps its own price', () {
      final vm = AssetViewModel()
        ..setGoldSellPrice(GoldAssetType.sjcPiece.label, 143500000);
      final ring = AssetGold(
        id: 'g3',
        goldType: GoldAssetType.ring9999.label,
        quantity: 1,
        buyPrice: 100000000,
        buyDate: DateTime.now(),
      );

      expect(vm.goldSellPrice(GoldAssetType.ring9999.label), isNull);
      expect(vm.getCurrentGoldPrice(ring), 100000000);
    });

    test('clearing it hands the holding back to the feed', () {
      final vm = AssetViewModel()
        ..setGoldSellPrice(GoldAssetType.sjcPiece.label, 143500000);
      vm.setGoldSellPrice(GoldAssetType.sjcPiece.label, null);

      expect(vm.goldSellPrice(GoldAssetType.sjcPiece.label), isNull);
      expect(vm.getCurrentGoldPrice(gold()), 100000000);
    });

    test('the gain it implies is spread over how long it was held', () {
      final vm = AssetViewModel()
        ..setGoldSellPrice(GoldAssetType.sjcPiece.label, 150000000);
      final estimate = vm.getGoldEstimatedReturn(gold());

      // 2 taels bought a year ago at 100tr, now worth 150tr each: 100tr over
      // the year, a twelfth of it a month.
      expect(estimate, isNotNull);
      expect(estimate!.perYear, closeTo(100000000, 500000));
      expect(estimate.perMonth, closeTo(estimate.perYear / 12, 1));
      expect(estimate.perYearPercent, closeTo(50, 0.5));
      expect(
        estimate.perMonthPercent,
        closeTo(estimate.perYearPercent / 12, 1),
      );
    });

    test('a holding bought days ago is too young to annualise', () {
      final vm = AssetViewModel()
        ..setGoldSellPrice(GoldAssetType.sjcPiece.label, 150000000);
      final young = AssetGold(
        id: 'g1',
        goldType: GoldAssetType.sjcPiece.label,
        quantity: 2,
        buyPrice: 100000000,
        buyDate: DateTime.now().subtract(const Duration(days: 3)),
      );

      expect(vm.getGoldEstimatedReturn(young), isNull);
    });
  });

  group('year filter', () {
    test('an empty portfolio offers no years and filters to nothing', () {
      final vm = AssetViewModel();

      expect(vm.availableYears, isEmpty);
      expect(vm.selectedYear, isNull);

      vm.selectYear(2025);
      expect(vm.selectedYear, 2025);
      expect(vm.filteredGold, isEmpty);
      expect(vm.filteredSavings, isEmpty);
      expect(vm.filteredInvestments, isEmpty);

      vm.selectYear(null);
      expect(vm.selectedYear, isNull);
    });
  });

  _priceInputTests();

  group('crypto pricing', () {
    AssetInvestment coin({double buyPrice = 100, double quantity = 2}) {
      return AssetInvestment(
        id: 'i1',
        symbol: 'BTCUSDT',
        type: InvestmentType.crypto,
        quantity: quantity,
        buyPrice: buyPrice,
        buyDate: DateTime.now().subtract(const Duration(days: 365)),
      );
    }

    test('a pair is read as the coin inside it', () {
      expect(AssetViewModel.baseOf('BTCUSDT'), 'BTC');
      expect(AssetViewModel.baseOf('1000PEPEUSDT'), '1000PEPE');
      // Not a USDT pair: nothing to strip, so it is left as it is.
      expect(AssetViewModel.baseOf('BTC'), 'BTC');
      // USDT itself is the coin, not an empty pair quoted in itself.
      expect(AssetViewModel.baseOf('USDT'), 'USDT');
    });

    test('USDT is worth one of itself without asking a feed', () {
      final vm = AssetViewModel();
      final usdt = AssetInvestment(
        id: 'i2',
        symbol: 'USDT',
        type: InvestmentType.crypto,
        quantity: 500,
        buyPrice: 1,
        buyDate: DateTime.now(),
      );

      expect(vm.marketInvestmentPrice('USDT'), 1);
      expect(vm.getCurrentInvestmentPrice(usdt), vm.usdRate);
    });

    test('a balance bought at a lower rate has gained on the rate alone', () {
      final vm = AssetViewModel();
      // Every USDT figure is unchanged — one USDT is one USDT — so the only
      // thing that can have moved is the đồng, and it must show up.
      final usdt = AssetInvestment(
        id: 'i3',
        symbol: 'USDT',
        type: InvestmentType.crypto,
        quantity: 500,
        buyPrice: 1,
        buyFxRate: vm.usdRate - 1800,
        buyDate: DateTime.now().subtract(const Duration(days: 365)),
      );

      expect(vm.getBuyPriceInVnd(usdt), vm.usdRate - 1800);
      final profit =
          usdt.quantity *
          (vm.getCurrentInvestmentPrice(usdt) - vm.getBuyPriceInVnd(usdt));
      expect(profit, closeTo(500 * 1800, 1));
    });

    test('a record made before the rate was kept uses today\'s', () {
      final vm = AssetViewModel();

      expect(vm.getBuyPriceInVnd(coin()), 100 * vm.usdRate);
    });

    test('a price in USDT is counted in đồng', () {
      final vm = AssetViewModel();
      // Nothing has been fetched, so the holding is priced at what was paid —
      // converted at the rate the view model falls back to.
      final rate = vm.usdRate;

      expect(vm.getBuyPriceInVnd(coin()), 100 * rate);
      expect(vm.getCurrentInvestmentPrice(coin()), 100 * rate);
    });

    test('a hand-typed rate is what every coin is counted in', () {
      final vm = AssetViewModel();
      final market = vm.marketUsdRate;
      vm.setUsdRate(market + 1000);

      expect(vm.usdRate, market + 1000);
      expect(vm.customUsdRate, market + 1000);
      // The coin's own price is untouched — only what a USDT is worth moved.
      expect(vm.getCurrentInvestmentPrice(coin()), 100 * (market + 1000));

      vm.setUsdRate(null);
      expect(vm.usdRate, market);
      expect(vm.customUsdRate, isNull);
    });

    test('a rate typed by hand does not rewrite what a holding cost', () {
      final vm = AssetViewModel();
      final bought = AssetInvestment(
        id: 'i4',
        symbol: 'BTCUSDT',
        type: InvestmentType.crypto,
        quantity: 2,
        buyPrice: 100,
        buyFxRate: 24000,
        buyDate: DateTime.now(),
      );
      vm.setUsdRate(27000);

      expect(vm.getBuyPriceInVnd(bought), 100 * 24000);
      expect(vm.getCurrentInvestmentPrice(bought), 100 * 27000);
    });
  });

  group('market currency', () {
    test('the dollar-quoted markets are the ones that get converted', () {
      expect(MarketCode.xauUSD.isUsdQuoted, isTrue);
      expect(MarketCode.btcUSDT.isUsdQuoted, isTrue);
      expect(MarketCode.apple.isUsdQuoted, isTrue);
      expect(MarketCode.sp500.isUsdQuoted, isTrue);
    });

    test('a Vietnamese index is already in đồng', () {
      expect(MarketCode.vnIndex.isUsdQuoted, isFalse);
      expect(MarketCode.vn30.isUsdQuoted, isFalse);
    });

    test('a commodity not paired against USD is not converted', () {
      expect(MarketCode.rice.isUsdQuoted, isFalse);
      expect(MarketCode.usOil.isUsdQuoted, isFalse);
    });
  });
}

/// A price written into an input field has to survive the round trip: the
/// field parses it back by stripping commas, and a coin can be worth a
/// millionth of a dollar.
void _priceInputTests() {
  group('price input', () {
    final format = AssetFormat();

    test('a six-figure price keeps its grouping', () {
      expect(format.priceInput(76559.94), '76,559.94');
      expect('76,559.94'.toMoney(), 76559.94);
    });

    test('a price below a cent keeps every digit', () {
      expect(format.priceInput(0.00000812), '0.00000812');
      expect('0.00000812'.toMoney(), 0.00000812);
    });

    test('a whole number carries no decimals', () {
      expect(format.priceInput(1), '1');
      expect(format.priceInput(26000), '26,000');
    });
  });
}
