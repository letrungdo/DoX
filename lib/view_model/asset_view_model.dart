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
import 'package:do_x/services/fx_rate_service.dart';
import 'package:do_x/view_model/core/core_view_model.dart';

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
  double _usdRate = 25450; // Default fallback

  AssetSummary? _summary;
  AssetSummary? get summary => _summary;

  double getCurrentInvestmentPrice(AssetInvestment investment) {
    final marketCode = MarketCode.from(investment.symbol);
    double price = _marketOverviews[marketCode]?.price ?? investment.buyPrice;
    
    // If it's a crypto, US stock, world index or international commodity (priced in USD), convert to VND
    if (marketCode != null && 
        (marketCode.group == MarketGroup.crypto || 
         marketCode.group == MarketGroup.usStock ||
         marketCode.group == MarketGroup.worldIndex ||
         (marketCode.group == MarketGroup.commodity && marketCode.code.endsWith("USD")))) {
      price *= _usdRate;
    }
    return price;
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
    } catch (e) {
      // Handle error
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
      _marketOverviews = marketResults[0].data as Map<MarketCode, MarketOverview>;
    }
    if (marketResults[1].data is List<GoldSymbol>?) {
      _goldPrices = (marketResults[1].data as List<GoldSymbol>?) ?? [];
    }
    if (marketResults[2].data is Map<String, double>) {
      final rates = marketResults[2].data as Map<String, double>;
      // Try common codes for USD/VND
      _usdRate = rates['google_usd_vnd'] ?? 
                 rates['vcb_usd_vnd'] ?? 
                 25450;
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
      weightedReturnSum += s.amount * s.interestRate;
      totalAssetsForReturn += s.amount;
    }

    double totalInvestmentsCurrent = 0;
    double totalInvestmentsProfitLoss = 0;
    for (final inv in _investments) {
      final currentPrice = getCurrentInvestmentPrice(inv);
      final currentValue = inv.quantity * currentPrice;
      final buyValue = inv.quantity * inv.buyPrice;
      totalInvestmentsCurrent += currentValue;
      totalInvestmentsProfitLoss += currentValue - buyValue;

      // Annualized return
      final years = DateTime.now().difference(inv.buyDate).inDays / 365.0;
      final totalReturn = buyValue > 0 ? (currentValue - buyValue) / buyValue : 0.0;
      final annualReturn = years > 0.01 ? (totalReturn / years) * 100 : 0.0;
      
      weightedReturnSum += buyValue * (annualReturn == 0 ? 0 : annualReturn);
      totalAssetsForReturn += buyValue;
    }

    double totalGoldCurrent = 0;
    double totalGoldProfitLoss = 0;
    for (final g in _gold) {
      final currentPrice = getCurrentGoldPrice(g);
      final currentValue = g.quantity * currentPrice;
      final buyValue = g.quantity * g.buyPrice;
      totalGoldCurrent += currentValue;
      totalGoldProfitLoss += currentValue - buyValue;

      // Annualized return
      final years = DateTime.now().difference(g.buyDate).inDays / 365.0;
      final totalReturn = buyValue > 0 ? (currentValue - buyValue) / buyValue : 0.0;
      final annualReturn = years > 0.01 ? (totalReturn / years) * 100 : 0.0;

      weightedReturnSum += buyValue * (annualReturn == 0 ? 0 : annualReturn);
      totalAssetsForReturn += buyValue;
    }

    final avgAnnualReturn = totalAssetsForReturn > 0 
        ? weightedReturnSum / totalAssetsForReturn 
        : 0.0;

    _summary = AssetSummary(
      totalSavings: totalSavingsPrincipal + totalSavingsInterest,
      totalInvestments: totalInvestmentsCurrent,
      totalGold: totalGoldCurrent,
      monthlyInterest: monthlyInterest,
      totalProfitLoss: totalSavingsInterest + totalInvestmentsProfitLoss + totalGoldProfitLoss,
      averageAnnualReturn: avgAnnualReturn,
    );
  }

  // CRUD Operations with refresh
  Future<void> upsertSaving(AssetSaving saving) async {
    await _repository.upsertSaving(saving);
    await refresh();
  }

  Future<void> deleteSaving(String id) async {
    await _repository.deleteSaving(id);
    await refresh();
  }

  Future<void> upsertInvestment(AssetInvestment investment) async {
    await _repository.upsertInvestment(investment);
    await refresh();
  }

  Future<void> deleteInvestment(String id) async {
    await _repository.deleteInvestment(id);
    await refresh();
  }

  Future<void> upsertGold(AssetGold gold) async {
    await _repository.upsertGold(gold);
    await refresh();
  }

  Future<void> deleteGold(String id) async {
    await _repository.deleteGold(id);
    await refresh();
  }
}
