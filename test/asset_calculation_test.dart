import 'package:do_x/constants/enum/market_code.dart';
import 'package:do_x/model/asset/asset_saving.dart';
import 'package:do_x/model/asset/gold_type.dart';
import 'package:do_x/model/fx/gold_model.dart';
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

    test('a private ring is valued at the plain PNJ ring price', () {
      expect(
        prices.findPrice(GoldAssetType.privateRing),
        prices.findPrice(GoldAssetType.ring9999),
      );
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
