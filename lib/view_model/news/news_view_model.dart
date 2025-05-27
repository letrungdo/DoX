import 'package:do_x/extensions/double_extensions.dart';
import 'package:do_x/model/fx/gold_model.dart';
import 'package:do_x/view_model/core/core_view_model.dart';
import 'package:do_x/view_model/news/coin_chart.dart';

class NewsViewModel extends CoreViewModel with CoinChartMixin {
  List<GoldSymbol> _goldPrices = [];
  List<GoldSymbol> get goldPrices => _goldPrices;

  String? _googleRate;
  String? get googleRate => _googleRate;

  String? _smileRate;
  String? get smileRate => _smileRate;

  String? _moneyGramRate;
  String? get moneyGramRate => _moneyGramRate;

  String? _dcomRate;
  String? get dcomRate => _dcomRate;

  @override
  void initState() {
    super.initState();
    socketService.connect(context);
  }

  @override
  void dispose() {
    socketService.disconnect();
    super.dispose();
  }

  @override
  void initData() {
    super.initData();
    _fetchData();
  }

  Future<void> _fetchData() async {
    await Future.wait([
      _getGoldPrice(), //
      _getSmileRate(),
      _getDcomRate(),
      _getGoogleRate(),
      _getMoneyGramRate(),
      getMarket(),
    ]);
  }

  Future<void> onRefresh() {
    renewCancelToken("onRefresh");
    return _fetchData();
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
    _goldPrices = res.data ?? [];
    notifyListenersSafe();
  }

  Future<void> _getGoogleRate() async {
    _googleRate = null;
    notifyListenersSafe();
    final res = await fxRateService.getGoogleJpyVnd(cancelToken: cancelToken);
    if (res.isCancelByUser) {
      return;
    }
    _googleRate = res.data.formatUnit();
    notifyListenersSafe();
    if (res.isError) {
      showAppError(
        // ignore: use_build_context_synchronously
        context,
        res.error, //
        onRetry: _getGoogleRate,
      );
    }
  }

  Future<void> _getSmileRate() async {
    _smileRate = null;
    notifyListenersSafe();
    final res = await fxRateService.getSmileRate(cancelToken: cancelToken);
    if (res.isCancelByUser) {
      return;
    }
    _smileRate = res.data?["Currency_JPY_VND"]?.sellingRate.formatUnit();
    notifyListenersSafe();
    if (res.isError) {
      showAppError(
        // ignore: use_build_context_synchronously
        context,
        res.error, //
        onRetry: _getSmileRate,
      );
    }
  }

  Future<void> _getMoneyGramRate() async {
    _moneyGramRate = null;
    notifyListenersSafe();
    final res = await fxRateService.getMoneyGramRate(cancelToken: cancelToken);
    if (res.isCancelByUser) {
      return;
    }
    _moneyGramRate = res.data.formatUnit();
    notifyListenersSafe();
    if (res.isError) {
      showAppError(
        // ignore: use_build_context_synchronously
        context,
        res.error, //
        onRetry: _getMoneyGramRate,
      );
    }
  }

  Future<void> _getDcomRate() async {
    _dcomRate = null;
    notifyListenersSafe();
    final res = await fxRateService.getDcomRate(cancelToken: cancelToken);
    if (res.isCancelByUser) {
      return;
    }
    _dcomRate = res.data.formatUnit();
    notifyListenersSafe();
    if (res.isError) {
      showAppError(
        // ignore: use_build_context_synchronously
        context,
        res.error, //
        onRetry: _getDcomRate,
      );
    }
  }
}
