import 'package:do_x/constants/enum/market_code.dart';
import 'package:do_x/model/asset/asset_gold.dart';
import 'package:do_x/model/asset/asset_investment.dart';
import 'package:do_x/model/asset/asset_saving.dart';
import 'package:do_x/model/asset/asset_summary.dart';
import 'package:do_x/model/asset/gold_type.dart';
import 'package:do_x/model/fx/gold_model.dart';
import 'package:do_x/model/market/market_overview.dart';
import 'package:do_x/repository/asset_repository.dart';
import 'package:do_x/repository/client/error_handler.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/services/fx_rate_service.dart';
import 'package:do_x/utils/logger.dart';
import 'package:do_x/view_model/core/core_view_model.dart';

/// A gold holding's gain averaged over how long it has been held.
class GoldReturnEstimate {
  const GoldReturnEstimate({
    required this.perYear,
    required this.perMonth,
    required this.perYearPercent,
    required this.perMonthPercent,
  });

  final double perYear;
  final double perMonth;
  final double perYearPercent;
  final double perMonthPercent;
}

class AssetViewModel extends CoreViewModel {
  final AssetRepository _repository = AssetRepository();
  final FxRateService _fxService = FxRateService();

  List<AssetSaving> _savings = [];
  List<AssetInvestment> _investments = [];
  List<AssetGold> _gold = [];

  List<AssetSaving> get savings => _savings;
  List<AssetInvestment> get investments => _investments;
  List<AssetGold> get gold => _gold;

  Map<MarketCode, MarketOverview> _marketOverviews = {};
  List<GoldSymbol> _goldPrices = [];

  /// USDT/VND, refreshed from `fx_rates`. The fallback only covers the frames
  /// before that call lands, or a feed that is down.
  double _usdRate = _fallbackUsdRate;
  static const _fallbackUsdRate = 25800.0;

  bool _loadFailed = false;
  bool get loadFailed => _loadFailed;

  AssetSummary? _summary;
  AssetSummary? get summary => _summary;

  /// The rate a dollar converts at today, for the UI to label its own figures.
  double get usdRate => _usdRate;

  /// Today's price of one unit, in VND. A market that quotes in dollars — and
  /// whose buy price is therefore recorded in dollars — is converted here, so
  /// both sides of every comparison are in the same currency.
  double getCurrentInvestmentPrice(AssetInvestment investment) {
    final marketCode = MarketCode.from(investment.symbol);
    final price = _marketOverviews[marketCode]?.price ?? investment.buyPrice;

    return _toVnd(price, marketCode);
  }

  /// What was paid per unit, in VND.
  double getBuyPriceInVnd(AssetInvestment investment) {
    return _toVnd(investment.buyPrice, MarketCode.from(investment.symbol));
  }

  double _toVnd(double price, MarketCode? marketCode) {
    return marketCode?.isUsdQuoted == true ? price * _usdRate : price;
  }

  /// A holding has to be held this long before its return says anything about
  /// a year. Annualising a few days of movement yields four-digit percentages,
  /// and a holding bought yesterday is left out of the average entirely rather
  /// than counted as a 0% year, which would drag the whole portfolio down.
  static const _minDaysToAnnualize = 30;

  /// The holding's gain restated as a yearly rate in %, or null when it is too
  /// young to annualise.
  double? _annualizedReturn(
    double buyValue,
    double currentValue,
    DateTime buyDate,
  ) {
    final days = DateTime.now().difference(buyDate).inDays;
    if (buyValue <= 0 || days < _minDaysToAnnualize) return null;

    final totalReturn = (currentValue - buyValue) / buyValue;

    return (totalReturn / (days / 365.0)) * 100;
  }

  /// What a gold holding has made, spread over the time it has been held: an
  /// amount in VND and the same figure as a rate on what was paid. Null until
  /// the holding is old enough for either to mean anything — see
  /// [_minDaysToAnnualize].
  GoldReturnEstimate? getGoldEstimatedReturn(AssetGold gold) {
    final days = DateTime.now().difference(gold.buyDate).inDays;
    if (days < _minDaysToAnnualize) return null;

    final buyValue = gold.quantity * gold.buyPrice;
    final profit = gold.quantity * (getCurrentGoldPrice(gold) - gold.buyPrice);
    final perYear = profit / (days / 365.0);
    final perYearPercent = buyValue > 0 ? (perYear / buyValue) * 100 : 0.0;

    return GoldReturnEstimate(
      perYear: perYear,
      perMonth: perYear / 12,
      perYearPercent: perYearPercent,
      perMonthPercent: perYearPercent / 12,
    );
  }

  double getCurrentGoldPrice(AssetGold gold) {
    final type = GoldAssetType.fromLabel(gold.goldType);
    if (type != null) {
      return _goldPrices.findPrice(type) ?? gold.buyPrice;
    }
    return gold.buyPrice;
  }

  @override
  Future<void> initData() async {
    super.initData();
    await refresh();
  }

  Future<void> refresh() async {
    setBusy(true);
    try {
      final results = await Future.wait([
        _repository.getSavings(),
        _repository.getInvestments(),
        _repository.getGold(),
      ]);

      _savings = results[0] as List<AssetSaving>;
      _investments = results[1] as List<AssetInvestment>;
      _gold = results[2] as List<AssetGold>;

      await _fetchMarketData();
      _calculateSummary();
      _loadFailed = false;
    } catch (e) {
      // Without this the screen simply stayed empty: no list, no message, no
      // way to tell an account with no assets from a request that never landed.
      logger.e('load assets failed', error: e);
      _loadFailed = true;
      if (context.mounted) {
        context.showToast(context.l10n.assetLoadFailed, isError: true);
      }
    } finally {
      setBusy(false);
      notifyListenersSafe();
    }
  }

  Future<void> _fetchMarketData() async {
    final investmentCodes = _investments
        .map((e) => MarketCode.from(e.symbol))
        .whereType<MarketCode>()
        .toList();

    final marketResults = await Future.wait([
      if (investmentCodes.isNotEmpty)
        _fxService.getMarketOverviews(markets: investmentCodes)
      else
        Future.value(const Result(data: <MarketCode, MarketOverview>{})),
      _fxService.getGoldPrice(),
      _fxService.getFxRates(),
    ]);

    if (marketResults[0].data is Map<MarketCode, MarketOverview>) {
      _marketOverviews =
          marketResults[0].data as Map<MarketCode, MarketOverview>;
    }
    if (marketResults[1].data is List<GoldSymbol>?) {
      _goldPrices = (marketResults[1].data as List<GoldSymbol>?) ?? [];
    }
    if (marketResults[2].data is Map<String, double>) {
      final rates = marketResults[2].data as Map<String, double>;
      // Try common codes for USD/VND
      _usdRate = rates['usdt_vnd'] ?? _fallbackUsdRate;
    }
  }

  void _calculateSummary() {
    double totalSavingsPrincipal = 0;
    double totalSavingsInterest = 0;
    double monthlyInterest = 0;
    double weightedReturnSum = 0;
    double totalAssetsForReturn = 0;

    for (final s in _savings) {
      totalSavingsPrincipal += s.amount;
      totalSavingsInterest += s.accruedInterest;
      monthlyInterest += s.monthlyInterest;
      // A matured deposit no longer earns its rate, so it stops counting
      // towards the portfolio's yearly return.
      if (!s.isMatured) {
        weightedReturnSum += s.amount * s.interestRate;
        totalAssetsForReturn += s.amount;
      }
    }

    double totalInvestmentsCurrent = 0;
    double totalInvestmentsProfitLoss = 0;
    for (final inv in _investments) {
      final currentPrice = getCurrentInvestmentPrice(inv);
      final currentValue = inv.quantity * currentPrice;
      final buyValue = inv.quantity * getBuyPriceInVnd(inv);
      totalInvestmentsCurrent += currentValue;
      totalInvestmentsProfitLoss += currentValue - buyValue;

      final annualReturn = _annualizedReturn(
        buyValue,
        currentValue,
        inv.buyDate,
      );
      if (annualReturn != null) {
        weightedReturnSum += buyValue * annualReturn;
        totalAssetsForReturn += buyValue;
      }
    }

    double totalGoldCurrent = 0;
    double totalGoldProfitLoss = 0;
    for (final g in _gold) {
      final currentPrice = getCurrentGoldPrice(g);
      final currentValue = g.quantity * currentPrice;
      final buyValue = g.quantity * g.buyPrice;
      totalGoldCurrent += currentValue;
      totalGoldProfitLoss += currentValue - buyValue;

      final annualReturn = _annualizedReturn(buyValue, currentValue, g.buyDate);
      if (annualReturn != null) {
        weightedReturnSum += buyValue * annualReturn;
        totalAssetsForReturn += buyValue;
      }
    }

    final avgAnnualReturn = totalAssetsForReturn > 0
        ? weightedReturnSum / totalAssetsForReturn
        : 0.0;

    _summary = AssetSummary(
      totalSavings: totalSavingsPrincipal + totalSavingsInterest,
      totalInvestments: totalInvestmentsCurrent,
      totalGold: totalGoldCurrent,
      monthlyInterest: monthlyInterest,
      totalProfitLoss:
          totalSavingsInterest +
          totalInvestmentsProfitLoss +
          totalGoldProfitLoss,
      averageAnnualReturn: avgAnnualReturn,
    );
  }

  /// Runs a write and reloads. A write that throws used to escape as an
  /// unhandled async error, leaving the dialog closed and the list unchanged
  /// with nothing said; now it is reported and the list still resyncs.
  Future<void> _write(String what, Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      logger.e('$what failed', error: e);
      if (context.mounted) {
        context.showToast(context.l10n.assetSaveFailed, isError: true);
      }
    }
    await refresh();
  }

  Future<void> upsertSaving(AssetSaving saving) {
    return _write('upsert saving', () => _repository.upsertSaving(saving));
  }

  Future<void> deleteSaving(String id) {
    return _write('delete saving', () => _repository.deleteSaving(id));
  }

  Future<void> upsertInvestment(AssetInvestment investment) {
    return _write(
      'upsert investment',
      () => _repository.upsertInvestment(investment),
    );
  }

  Future<void> deleteInvestment(String id) {
    return _write('delete investment', () => _repository.deleteInvestment(id));
  }

  Future<void> upsertGold(AssetGold gold) {
    return _write('upsert gold', () => _repository.upsertGold(gold));
  }

  Future<void> deleteGold(String id) {
    return _write('delete gold', () => _repository.deleteGold(id));
  }
}
