import 'dart:io';

import 'package:do_x/extensions/double_extensions.dart';
import 'package:do_x/model/fx/jpy_source.dart';
import 'package:do_x/model/fx/gold_model.dart';
import 'package:do_x/model/news/gold_news.dart';
import 'package:do_x/model/news/storm_news.dart';
import 'package:do_x/view_model/core/core_view_model.dart';
import 'package:do_x/view_model/news/coin_chart.dart';

class NewsViewModel extends CoreViewModel with CoinChartMixin {
  List<GoldSymbol> _goldPrices = [];
  List<GoldSymbol> get goldPrices => _goldPrices;

  GoldNews? _goldNews;
  GoldNews? get goldNews => _goldNews;

  StormNews? _stormNews;

  /// Only a live, freshly-rebuilt bulletin reaches the screen: with no storm
  /// around this stays null and the page shows no storm section at all.
  StormNews? get stormNews {
    final news = _stormNews;
    return news != null && news.shouldShow ? news : null;
  }

  String? _googleRate;
  String? get googleRate => _googleRate;

  String? _smileRate;
  String? get smileRate => _smileRate;

  String? _moneyGramRate;
  String? get moneyGramRate => _moneyGramRate;

  String? _dcomRate;
  String? get dcomRate => _dcomRate;

  /// USDT/VND off the Binance P2P book, the rate a dollar-denominated holding
  /// actually converts at here. It rides in the same `fx_rates` table as the
  /// JPY sources, so it costs no extra request.
  String? _usdtRate;
  String? get usdtRate => _usdtRate;

  /// The best of the four JPY→VND sources — the most đồng per yen, which is
  /// what someone sending money home is shopping for. The card leads with this
  /// and keeps the other three folded away, because the only question the row
  /// usually has to answer is "who is paying most today".
  ({String source, String rate})? _bestJpy;
  ({String source, String rate})? get bestJpy => _bestJpy;

  bool _isFetching = false;
  bool get isFetching => _isFetching;

  bool _isLoading = false;

  /// True only during an explicitly-requested load (first load or a manual
  /// reload). Background refreshes on tab switch / resume leave this false.
  /// The app bar spinner watches [isFetching] instead, so any fetch shows up.
  bool get isLoading => _isLoading;

  @override
  void initState() {
    super.initState();
    socketService.connect(context);
  }

  @override
  void dispose() {
    // On macOS, we keep the socket alive for the status bar
    if (!Platform.isMacOS) {
      socketService.disconnect();
    }
    super.dispose();
  }

  @override
  void initData() {
    super.initData();
    _fetchData(showLoading: true);
  }

  Future<void> _fetchData({bool showLoading = false}) async {
    _isFetching = true;
    if (showLoading) _isLoading = true;
    notifyListenersSafe();
    try {
      await Future.wait([
        _getGoldPrice(), //
        _getGoldNews(),
        _getStormNews(),
        _getFxRates(),
        getMarket(),
      ]);
    } finally {
      _isFetching = false;
      _isLoading = false;
      notifyListenersSafe();
    }
  }

  Future<void> onRefresh({bool showLoading = false}) {
    renewCancelToken("onRefresh");
    return _fetchData(showLoading: showLoading);
  }

  Future<void> _getGoldPrice() async {
    final res = await fxRateService.getGoldPrice(cancelToken: cancelToken);
    if (res.isError) {
      showAppError(
        // ignore: use_build_context_synchronously
        context,
        res.error, //
        onRetry: _getGoldPrice,
      );
      return;
    }
    // Same as the FX rates: hold on to the previous table when a fetch fails.
    final data = res.data;
    if (data == null) return;
    _goldPrices = data;
    notifyListenersSafe();
  }

  /// The digest is rebuilt once a day on the server, so a failed fetch is not
  /// worth an error dialog: the previous card stays on screen and the next
  /// refresh picks it up.
  Future<void> _getGoldNews() async {
    final res = await fxRateService.getGoldNews(cancelToken: cancelToken);
    final news = res.data;
    if (news == null) return;
    _goldNews = news;
    notifyListenersSafe();
  }

  /// Same as the gold digest: a failed fetch keeps whatever is on screen and
  /// waits for the next refresh instead of raising a dialog.
  Future<void> _getStormNews() async {
    final res = await fxRateService.getStormNews(cancelToken: cancelToken);
    final news = res.data;
    if (news == null) return;
    _stormNews = news;
    notifyListenersSafe();
  }

  // Every rate the page shows lives in one Supabase table, so a single query
  // fetches them all at once instead of one request per source.
  //
  // The rates already on screen are kept until the new ones arrive — a reload
  // shouldn't blank out values that are still perfectly readable.
  Future<void> _getFxRates() async {
    final res = await fxRateService.getFxRates(cancelToken: cancelToken);
    if (res.isCancelByUser) {
      return;
    }
    final rates = res.data;
    if (rates != null) {
      _googleRate = rates['google_jpy_vnd'].formatUnit();
      _smileRate = rates['smile_jpy_vnd'].formatUnit();
      _moneyGramRate = rates['moneygram_jpy_vnd'].formatUnit();
      _dcomRate = rates['dcom_jpy_vnd'].formatUnit();
      _usdtRate = rates['usdt_vnd'].formatUnit(digit: 0);
      final best = JpySource.best(rates);
      _bestJpy = best == null
          ? null
          : (source: best.source.label, rate: best.rate.formatUnit());
      notifyListenersSafe();
    }
    if (res.isError) {
      showAppError(
        // ignore: use_build_context_synchronously
        context,
        res.error, //
        onRetry: _getFxRates,
      );
    }
  }
}
