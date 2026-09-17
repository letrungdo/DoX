import 'package:do_x/model/asset/asset_gold.dart';
import 'package:do_x/model/asset/asset_investment.dart';
import 'package:do_x/model/asset/asset_saving.dart';
import 'package:do_x/model/asset/asset_summary.dart';
import 'package:do_x/model/asset/gold_type.dart';
import 'package:do_x/model/bank/bank.dart';
import 'package:do_x/model/crypto/crypto_symbol.dart';
import 'package:do_x/model/fx/gold_model.dart';
import 'package:do_x/repository/asset_repository.dart';
import 'package:do_x/repository/client/error_handler.dart';
import 'package:do_x/services/bank_service.dart';
import 'package:do_x/services/binance_service.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/services/fx_rate_service.dart';
import 'package:do_x/utils/logger.dart';
import 'package:do_x/view_model/core/core_view_model.dart';

/// A holding's gain averaged over how long it has been held.
class AssetReturnEstimate {
  const AssetReturnEstimate({
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
  final BankService _bankService = BankService();
  final BinanceService _binanceService = BinanceService();

  List<AssetSaving> _savings = [];
  List<AssetInvestment> _investments = [];
  List<AssetGold> _gold = [];

  List<AssetSaving> get savings => _savings;
  List<AssetInvestment> get investments => _investments;
  List<AssetGold> get gold => _gold;

  /// The VietQR directory, keyed by the lower-cased short name a savings
  /// record stores, so a tile can show the bank's logo. Empty until it loads,
  /// and it stays empty offline — the tiles fall back to their icon.
  Map<String, Bank> _banks = {};

  /// The directory entry behind a typed bank name, or null when nothing
  /// matches. A name is matched loosely because the field is free text: the
  /// picker fills in "Vietcombank", but someone can type "VCB" by hand.
  Bank? bankOf(String name) {
    if (_banks.isEmpty) return null;
    final key = name.trim().toLowerCase();
    final exact = _banks[key];
    if (exact != null) return exact;

    return _banks.values
        .where((bank) => bank.searchIndex.contains(key))
        .firstOrNull;
  }

  /// The last traded price of each pair held, in USDT, keyed by the pair a
  /// record stores ("BTCUSDT").
  Map<String, double> _cryptoPrices = {};

  /// The name and logo of each coin, keyed by the coin's own code ("BTC").
  Map<String, CryptoAsset> _cryptoAssets = {};

  /// The directory entry behind a pair, for a tile that wants to wear the
  /// coin's logo rather than its ticker.
  CryptoAsset? cryptoAssetOf(String symbol) => _cryptoAssets[baseOf(symbol)];

  /// The coin inside a pair: "BTCUSDT" is BTC quoted in USDT. "USDT" on its
  /// own is the coin, not an empty pair.
  static String baseOf(String symbol) {
    return symbol.length > _quote.length && symbol.endsWith(_quote)
        ? symbol.substring(0, symbol.length - _quote.length)
        : symbol;
  }

  /// Every price this app records a crypto holding in.
  static const _quote = 'USDT';
  List<GoldSymbol> _goldPrices = [];

  /// USDT/VND, refreshed from `fx_rates`. The fallback only covers the frames
  /// before that call lands, or a feed that is down.
  double _marketUsdRate = _fallbackUsdRate;
  static const _fallbackUsdRate = 25800.0;

  /// Sell prices typed by hand, standing in for the feed's quote.
  ///
  /// Keyed the way the quotes themselves are — by the kind of gold — so a price
  /// is entered once and every holding of that kind is valued at it. Deliberately not persisted: it is a "what would I get for
  /// this today" figure to compare against, not a fact about the holding, so it
  /// lives as long as the screen does and never overwrites what was paid.
  final Map<String, double> _goldSellPrices = {};

  double? goldSellPrice(String goldType) => _goldSellPrices[goldType];

  void setGoldSellPrice(String goldType, double? price) {
    _setSellPrice(_goldSellPrices, goldType, price);
  }

  void _setSellPrice(Map<String, double> store, String key, double? price) {
    if (price == null) {
      store.remove(key);
    } else {
      store[key] = price;
    }
    // Every total on the summary screen is priced off these, so they are
    // recomputed here rather than waiting for the next refresh.
    _calculateSummary();
    notifyListenersSafe();
  }

  bool _loadFailed = false;
  bool get loadFailed => _loadFailed;

  AssetSummary? _summary;
  AssetSummary? get summary => _summary;

  /// The rate a dollar converts at today, for the UI to label its own figures:
  /// the one typed by hand if there is one, else the feed's.
  double get usdRate => _customUsdRate ?? _marketUsdRate;

  /// What the feed says, whether or not it is the rate being used.
  double get marketUsdRate => _marketUsdRate;

  /// A rate typed by hand. Every crypto figure is priced through it, so it is
  /// the one number worth overriding on that tab — a coin's own price comes
  /// from Binance and needs no second opinion. Session-only, like the gold
  /// sell prices.
  double? get customUsdRate => _customUsdRate;
  double? _customUsdRate;

  void setUsdRate(double? rate) {
    _customUsdRate = rate;
    _calculateSummary();
    notifyListenersSafe();
  }

  /// The year every list is filtered to, or null for all of them. Shared by the
  /// three tabs so switching tab keeps answering the same question.
  int? _selectedYear;
  int? get selectedYear => _selectedYear;

  /// Every year any holding was opened in, newest first. Built from all three
  /// lists so the same chips show on every tab.
  List<int> get availableYears {
    final years = <int>{
      ..._savings.map((e) => e.startDate.year),
      ..._investments.map((e) => e.buyDate.year),
      ..._gold.map((e) => e.buyDate.year),
    }.toList();
    years.sort((a, b) => b.compareTo(a));

    return years;
  }

  void selectYear(int? year) {
    if (_selectedYear == year) return;
    _selectedYear = year;
    notifyListenersSafe();
  }

  List<AssetSaving> get filteredSavings {
    return _filterByYear(_savings, (e) => e.startDate);
  }

  List<AssetInvestment> get filteredInvestments {
    return _filterByYear(_investments, (e) => e.buyDate);
  }

  List<AssetGold> get filteredGold {
    return _filterByYear(_gold, (e) => e.buyDate);
  }

  /// Newest first. Two holdings bought on the same day fall back to the order
  /// they were recorded in, newest first as well, so the list never shuffles
  /// between refreshes.
  static List<T> sortByDateDesc<T>(
    List<T> items,
    DateTime Function(T item) dateOf,
    DateTime? Function(T item) createdAtOf,
  ) {
    final sorted = [...items];
    sorted.sort((a, b) {
      final byDate = dateOf(b).compareTo(dateOf(a));
      if (byDate != 0) return byDate;

      final createdA = createdAtOf(a);
      final createdB = createdAtOf(b);
      if (createdA == null || createdB == null) return 0;

      return createdB.compareTo(createdA);
    });

    return sorted;
  }

  List<T> _filterByYear<T>(List<T> items, DateTime Function(T item) dateOf) {
    final year = _selectedYear;
    if (year == null) return items;

    return items.where((e) => dateOf(e).year == year).toList();
  }

  /// Today's price of one coin, in VND.
  ///
  /// Every crypto price — what was paid, what Binance quotes, what was typed by
  /// hand — is in USDT, and the portfolio is counted in đồng, so the conversion
  /// happens here and nowhere else. A hand-typed sell price wins over Binance;
  /// a pair Binance no longer quotes falls back to what was paid, which reads
  /// as "no gain yet" rather than as a holding worth nothing.
  double getCurrentInvestmentPrice(AssetInvestment investment) {
    final price =
        marketInvestmentPrice(investment.symbol) ?? investment.buyPrice;

    return price * usdRate;
  }

  /// What was paid per coin, in VND: the USDT price at the rate of the day it
  /// was bought.
  ///
  /// Using today's rate on both sides would cancel the currency out — a USDT
  /// balance bought at 24,000 and worth 27,000 today would report no gain at
  /// all, when the rate is the only thing that ever moves for it. A record
  /// made before the rate was kept falls back to today's, which is the figure
  /// it has always shown.
  double getBuyPriceInVnd(AssetInvestment investment) {
    return investment.buyPrice * (investment.buyFxRate ?? usdRate);
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
  AssetReturnEstimate? getGoldEstimatedReturn(AssetGold gold) {
    return _estimatedReturn(
      buyValue: gold.quantity * gold.buyPrice,
      currentValue: gold.quantity * getCurrentGoldPrice(gold),
      buyDate: gold.buyDate,
    );
  }

  /// The same figure for an investment, both sides already in VND.
  AssetReturnEstimate? getInvestmentEstimatedReturn(AssetInvestment inv) {
    return _estimatedReturn(
      buyValue: inv.quantity * getBuyPriceInVnd(inv),
      currentValue: inv.quantity * getCurrentInvestmentPrice(inv),
      buyDate: inv.buyDate,
    );
  }

  AssetReturnEstimate? _estimatedReturn({
    required double buyValue,
    required double currentValue,
    required DateTime buyDate,
  }) {
    final days = DateTime.now().difference(buyDate).inDays;
    if (days < _minDaysToAnnualize) return null;

    final perYear = (currentValue - buyValue) / (days / 365.0);
    final perYearPercent = buyValue > 0 ? (perYear / buyValue) * 100 : 0.0;

    return AssetReturnEstimate(
      perYear: perYear,
      perMonth: perYear / 12,
      perYearPercent: perYearPercent,
      perMonthPercent: perYearPercent / 12,
    );
  }

  /// Today's price of one unit of gold, in VND: the price typed in by hand if
  /// there is one, else the feed's quote, else what was paid — which reads as
  /// "no gain yet" rather than as a holding worth nothing.
  double getCurrentGoldPrice(AssetGold gold) {
    return _goldSellPrices[gold.goldType] ??
        marketGoldPrice(gold.goldType) ??
        gold.buyPrice;
  }

  /// What the feed quotes for a kind of gold today, or null when it quotes
  /// nothing for it. The dialogs use it to show the price a manual entry would
  /// replace.
  double? marketGoldPrice(String? goldType) {
    final type = GoldAssetType.fromLabel(goldType);

    return type == null ? null : _goldPrices.findPrice(type);
  }

  /// What Binance last traded a pair at, in USDT, or null when it quotes none.
  /// USDT is the unit the others are quoted in, so it is worth one of itself
  /// and no feed is asked.
  double? marketInvestmentPrice(String symbol) {
    return symbol == _quote ? 1 : _cryptoPrices[symbol];
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

      // Newest first, by the day the money was put in rather than the day the
      // record was typed: a deposit entered late still belongs where it was
      // opened.
      _savings = sortByDateDesc(
        results[0] as List<AssetSaving>,
        (e) => e.startDate,
        (e) => e.createdAt,
      );
      _investments = sortByDateDesc(
        results[1] as List<AssetInvestment>,
        (e) => e.buyDate,
        (e) => e.createdAt,
      );
      _gold = sortByDateDesc(
        results[2] as List<AssetGold>,
        (e) => e.buyDate,
        (e) => e.createdAt,
      );

      await Future.wait([_fetchMarketData(), _fetchBanks(), _fetchCrypto()]);
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

  /// The directory is only worth a request once there is a deposit to label,
  /// and [BankService] keeps the first answer for the session, so this costs
  /// one call per app run rather than one per refresh.
  Future<void> _fetchBanks() async {
    if (_savings.isEmpty || _banks.isNotEmpty) return;

    final banks = (await _bankService.getBanks()).data;
    if (banks == null) return;

    _banks = {for (final bank in banks) bank.shortName.toLowerCase(): bank};
  }

  /// Binance prices for the pairs held, and the directory the logos come from.
  /// Asking for the held pairs by name keeps this to a few hundred bytes; the
  /// directory is fetched once per session, and only when there is a coin to
  /// label with it.
  Future<void> _fetchCrypto() async {
    if (_investments.isEmpty) return;

    final symbols = _investments
        .map((e) => e.symbol)
        .where((symbol) => symbol != _quote)
        .toSet()
        .toList();
    final results = await Future.wait([
      _binanceService.getPrices(symbols),
      _binanceService.getAssets(),
    ]);

    if (results[0] case Result(data: final Map<String, double> prices)) {
      _cryptoPrices = prices;
    }
    if (results[1] case final Map<String, CryptoAsset> assets) {
      _cryptoAssets = assets;
    }
  }

  Future<void> _fetchMarketData() async {
    final marketResults = await Future.wait([
      _fxService.getGoldPrice(),
      _fxService.getFxRates(),
    ]);

    if (marketResults[0].data is List<GoldSymbol>?) {
      _goldPrices = (marketResults[0].data as List<GoldSymbol>?) ?? [];
    }
    if (marketResults[1].data is Map<String, double>) {
      final rates = marketResults[1].data as Map<String, double>;
      // Try common codes for USD/VND
      _marketUsdRate = rates['usdt_vnd'] ?? _fallbackUsdRate;
    }
  }

  void _calculateSummary() {
    double savingsPrincipal = 0;
    double savingsInterest = 0;
    double monthlyInterest = 0;
    double weightedReturnSum = 0;
    double totalAssetsForReturn = 0;
    int maturedSavingsCount = 0;
    DateTime? nextMaturityDate;
    String? nextMaturityBank;
    final now = DateTime.now();

    for (final s in _savings) {
      savingsPrincipal += s.amount;
      savingsInterest += s.accruedInterest;
      monthlyInterest += s.monthlyInterest;
      // A matured deposit no longer earns its rate, so it stops counting
      // towards the portfolio's yearly return.
      if (s.isMatured) {
        maturedSavingsCount++;
      } else {
        weightedReturnSum += s.amount * s.interestRate;
        totalAssetsForReturn += s.amount;

        final maturity = s.maturityDate;
        // The soonest term still to run: what the next decision is about.
        if (maturity != null &&
            maturity.isAfter(now) &&
            (nextMaturityDate == null || maturity.isBefore(nextMaturityDate))) {
          nextMaturityDate = maturity;
          nextMaturityBank = s.bankName;
        }
      }
    }

    // Best and worst are ranked on the holdings that can move: a deposit only
    // ever accrues, so it would take the "best" slot on day one and say
    // nothing.
    final performers = <AssetPerformer>[];

    double investmentsCost = 0;
    double investmentsValue = 0;
    for (final inv in _investments) {
      final currentPrice = getCurrentInvestmentPrice(inv);
      final currentValue = inv.quantity * currentPrice;
      final buyValue = inv.quantity * getBuyPriceInVnd(inv);
      investmentsValue += currentValue;
      investmentsCost += buyValue;
      performers.add(_performer(inv.symbol, buyValue, currentValue));

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

    double goldCost = 0;
    double goldValue = 0;
    for (final g in _gold) {
      final currentPrice = getCurrentGoldPrice(g);
      final currentValue = g.quantity * currentPrice;
      final buyValue = g.quantity * g.buyPrice;
      goldValue += currentValue;
      goldCost += buyValue;
      performers.add(_performer(g.goldType, buyValue, currentValue));

      final annualReturn = _annualizedReturn(buyValue, currentValue, g.buyDate);
      if (annualReturn != null) {
        weightedReturnSum += buyValue * annualReturn;
        totalAssetsForReturn += buyValue;
      }
    }

    final avgAnnualReturn = totalAssetsForReturn > 0
        ? weightedReturnSum / totalAssetsForReturn
        : 0.0;

    performers.sort(
      (a, b) => b.profitLossPercent.compareTo(a.profitLossPercent),
    );

    _summary = AssetSummary(
      savings: AssetClassStat(
        cost: savingsPrincipal,
        value: savingsPrincipal + savingsInterest,
        count: _savings.length,
      ),
      investments: AssetClassStat(
        cost: investmentsCost,
        value: investmentsValue,
        count: _investments.length,
      ),
      gold: AssetClassStat(
        cost: goldCost,
        value: goldValue,
        count: _gold.length,
      ),
      monthlyInterest: monthlyInterest,
      averageAnnualReturn: avgAnnualReturn,
      maturedSavingsCount: maturedSavingsCount,
      nextMaturityDate: nextMaturityDate,
      nextMaturityBank: nextMaturityBank,
      best: performers.isEmpty ? null : performers.first,
      // With a single holding there is no worst to contrast it with — the same
      // card twice reads as a bug.
      worst: performers.length > 1 ? performers.last : null,
    );
  }

  AssetPerformer _performer(String name, double cost, double value) {
    final profit = value - cost;

    return AssetPerformer(
      name: name,
      profitLoss: profit,
      profitLossPercent: cost > 0 ? (profit / cost) * 100 : 0,
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
