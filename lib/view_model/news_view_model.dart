import 'package:do_x/model/finpath/gold_model.dart';
import 'package:do_x/services/finpath_service.dart';
import 'package:do_x/view_model/core/core_view_model.dart';
import 'package:provider/provider.dart';

class NewsViewModel extends CoreViewModel {
  FinpathService get finPathService => context.read<FinpathService>();

  List<GoldSymbol> _goldPrices = [];
  List<GoldSymbol> get goldPrices => _goldPrices;

  @override
  void initData() {
    super.initData();
    getGoldPrice();
  }

  Future<void> getGoldPrice() async {
    final res = await finPathService.getGoldPrice(cancelToken: cancelToken);
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
