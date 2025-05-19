import 'package:auto_route/auto_route.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/extensions/double_extensions.dart';
import 'package:do_x/extensions/string_extensions.dart';
import 'package:do_x/extensions/text_style_extensions.dart';
import 'package:do_x/extensions/widget_extensions.dart';
import 'package:do_x/model/finpath/gold_model.dart';
import 'package:do_x/screen/core/screen_state.dart';
import 'package:do_x/services/finpath_service.dart';
import 'package:do_x/view_model/news_view_model.dart';
import 'package:do_x/widgets/app_bar/app_bar_base.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

@RoutePage()
class NewsScreen extends StatefulScreen implements AutoRouteWrapper {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();

  @override
  Widget wrappedRoute(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => NewsViewModel()),
        Provider(create: (_) => FinpathService()), //
      ],
      child: this,
    );
  }
}

class _NewsScreenState<V extends NewsViewModel> extends ScreenState<NewsScreen, V> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final colsRatio = [40, 30, 30];

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: DoAppBar(title: "News"),
      body: Padding(
        padding: const EdgeInsets.all(15), //
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Giá vàng",
          style: context.textTheme.primary.size16.bold, //
        ),
        SizedBox(height: 20),
        Row(
          children: [
            Text("Chỉ số").expaned(colsRatio[0]), //
            Text("Mua vào", textAlign: TextAlign.right).expaned(colsRatio[1]),
            Text("Bán ra", textAlign: TextAlign.right).expaned(colsRatio[2]),
          ],
        ),
        Expanded(
          child: Selector<V, List<GoldSymbol>>(
            selector: (p0, p1) => p1.goldPrices,
            builder: (context, data, _) {
              return RefreshIndicator(
                onRefresh: () => vm.getGoldPrice(),
                child: ListView.builder(
                  itemCount: data.length,
                  itemBuilder: (context, index) {
                    final item = data[index];
                    return _buildGoldPriceItem(item);
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGoldPriceItem(GoldSymbol item) {
    return SizedBox(
      height: 50,
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.name.toDashIfNull, style: context.textTheme.primary.bold), //
              Text(item.desc.toDashIfNull, style: context.textTheme.secondary.size13.copyWith(letterSpacing: -1)), //
            ],
          ).expaned(colsRatio[0]),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(item.bid.formatUnit()), //
              Text(
                item.bidDayChange.formatUnit(hasPlus: true), //
                style: TextStyle(color: item.bidDayChange.getColor()),
              ), //
            ],
          ).expaned(colsRatio[1]),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(item.ask.formatUnit()), //
              Text(
                item.askDayChange.formatUnit(hasPlus: true), //
                style: TextStyle(color: item.askDayChange.getColor()),
              ), //
            ],
          ).expaned(colsRatio[2]),
        ],
      ),
    );
  }
}
