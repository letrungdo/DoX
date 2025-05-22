import 'package:do_x/extensions/double_extensions.dart';
import 'package:do_x/model/finpath/gold_model.dart';
import 'package:do_x/services/fx_rate_service.dart';
import 'package:do_x/view_model/core/core_view_model.dart';
import 'package:provider/provider.dart';

class NewsViewModel extends CoreViewModel {
  FxRateService get fxRateService => context.read<FxRateService>();

  List<GoldSymbol> _goldPrices = [];
  List<GoldSymbol> get goldPrices => _goldPrices;

  String? _smileRate;
  String? get smileRate => _smileRate;

  String? _dcomRate;
  String? get dcomRate => _dcomRate;

  @override
  void initData() {
    super.initData();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setBusy(true);
    await Future.wait([
      _getGoldPrice(), //
      _getSmileRate(),
      _getDcomRate(),
    ]);
    setBusy(false);
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

  Future<void> _getSmileRate() async {
    final res = await fxRateService.getSmileRate(cancelToken: cancelToken);
    if (res.isError) {
      showAppError(
        // ignore: use_build_context_synchronously
        context,
        res.error, //
        onRetry: _getSmileRate,
      );
      return;
    }
    _smileRate = res.data?["Currency_JPY_VND"]?.sellingRate.formatUnit();
    notifyListenersSafe();
  }

  Future<void> _getDcomRate() async {
    final res = await fxRateService.getDcomRate(cancelToken: cancelToken);
    if (res.isError) {
      showAppError(
        // ignore: use_build_context_synchronously
        context,
        res.error, //
        onRetry: _getDcomRate,
      );
      return;
    }
    _dcomRate = res.data.formatUnit();
    notifyListenersSafe();
  }
}
