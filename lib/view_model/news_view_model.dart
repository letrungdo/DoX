import 'package:do_x/model/market/gold_model.dart';
import 'package:do_x/services/fx_rate_service.dart';
import 'package:do_x/view_model/core/core_view_model.dart';
import 'package:provider/provider.dart';

class NewsViewModel extends CoreViewModel {
  FxRateService get fxRateService => context.read<FxRateService>();

  List<GoldSymbol> _goldPrices = [];
  List<GoldSymbol> get goldPrices => _goldPrices;

  @override
  void initData() {
    super.initData();
    getGoldPrice();
  }

  Future<void> getGoldPrice() async {
    final res = await fxRateService.getGoldPrice(cancelToken: cancelToken);
    if (res.isError) {
      showAppError(
        // ignore: use_build_context_synchronously
        context,
        res.error, //
        onRetry: getGoldPrice,
      );
      return;
    }
    _goldPrices = res.data ?? [];
    notifyListenersSafe();
  }
}
