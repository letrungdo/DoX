import 'package:auto_route/auto_route.dart';
import 'package:do_x/constants/dimens.dart';
import 'package:do_x/constants/enum/market_code.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/extensions/double_extensions.dart';
import 'package:do_x/extensions/string_extensions.dart';
import 'package:do_x/extensions/text_style_extensions.dart';
import 'package:do_x/extensions/widget_extensions.dart';
import 'package:do_x/model/fx/gold_model.dart';
import 'package:do_x/screen/core/screen_state.dart';
import 'package:do_x/services/fx_rate_service.dart';
import 'package:do_x/services/web_socket/web_socket_service.dart';
import 'package:do_x/view_model/news/coin_chart.dart';
import 'package:do_x/view_model/news/news_view_model.dart';
import 'package:do_x/widgets/app_bar/app_bar_base.dart';
import 'package:do_x/widgets/text/text_loading.dart';
import 'package:financial_chart/financial_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sficon/flutter_sficon.dart';
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
        Provider(create: (_) => FxRateService()), //
        Provider<WebSocketService>(create: (_) => WebSocketService()),
      ],
      child: this,
    );
  }
}

class _NewsScreenState<V extends NewsViewModel> extends ScreenState<NewsScreen, V> with TickerProviderStateMixin {
  final colsRatio = [40, 30, 30];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: DoAppBar(
        title: "News", //
        actions: [
          IconButton(
            padding: EdgeInsets.zero,
            onPressed: vm.onRefresh, //
            icon: SFIcon(SFIcons.sf_arrow_clockwise),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => vm.onRefresh(), //
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    return CustomScrollView(
      physics: AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverLayoutBuilder(
          builder: (context, constraints) {
            final screenWidth = constraints.crossAxisExtent;
            const maxContentWidth = Dimens.webMaxWidth;
            double horizontalPadding = 15;
            if (screenWidth > maxContentWidth) {
              horizontalPadding = (screenWidth - maxContentWidth) / 2;
            }
            return SliverPadding(
              padding: EdgeInsets.symmetric(vertical: 15, horizontal: horizontalPadding), //
              sliver: SliverList(delegate: SliverChildListDelegate(_buildPrice())),
            );
          },
        ),
      ],
    );
  }

  List<Widget> _buildPrice() {
    return [
      Text(
        "JPY/VND",
        style: context.textTheme.primary.size16.bold, //
      ),
      SizedBox(height: 8),
      Table(
        border: TableBorder.all(
          color: context.theme.textTheme.bodyMedium!.color!, //
          borderRadius: BorderRadius.circular(5),
        ),
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          TableRow(
            children: [
              Text("Google", style: TextStyle(color: Colors.blue).bold, textAlign: TextAlign.center),
              Text("Smile", style: TextStyle(color: Colors.green).bold, textAlign: TextAlign.center),
              Text("MoneyGram", style: TextStyle(color: Colors.redAccent).bold, textAlign: TextAlign.center),
              Text("Dcom", style: TextStyle(color: Colors.orange).bold, textAlign: TextAlign.center),
            ],
          ),
          TableRow(
            children: [
              Selector<V, String?>(
                selector: (p0, p1) => p1.googleRate,
                builder: (context, value, _) {
                  return TextLoading(
                    value,
                    style: TextStyle(color: Colors.blue).bold, //
                    textAlign: TextAlign.center,
                  );
                },
              ),
              Selector<V, String?>(
                selector: (p0, p1) => p1.smileRate,
                builder: (context, value, _) {
                  return TextLoading(
                    value,
                    style: TextStyle(color: Colors.green).bold, //
                    textAlign: TextAlign.center,
                  );
                },
              ),
              Selector<V, String?>(
                selector: (p0, p1) => p1.moneyGramRate,
                builder: (context, value, _) {
                  return TextLoading(
                    value,
                    style: TextStyle(color: Colors.redAccent).bold, //
                    textAlign: TextAlign.center,
                  );
                },
              ),
              Selector<V, String?>(
                selector: (p0, p1) => p1.dcomRate,
                builder: (context, value, _) {
                  return TextLoading(
                    value,
                    style: TextStyle(color: Colors.orange).bold, //
                    textAlign: TextAlign.center,
                  );
                },
              ),
            ],
          ),
        ],
      ),
      SizedBox(height: 20),
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
      Selector<V, List<GoldSymbol>>(
        selector: (p0, p1) => p1.goldPrices,
        builder: (context, data, _) {
          return Column(
            children:
                data.map((item) {
                  return _buildGoldPriceItem(item);
                }).toList(),
          );
        },
      ),
      SizedBox(height: 20),
      Selector<V, List<MarketCode>>(
        selector: (p0, p1) => p1.coinChartMap.keys.toList(),
        builder: (context, codes, _) {
          return Column(
            children:
                codes.map((code) {
                  return Selector<V, ChartData>(
                    selector: (p0, p1) => p1.coinChartMap[code]!,
                    builder: (context, data, _) {
                      debugPrint("render $code");
                      return Row(
                        spacing: 8,
                        children: [
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(text: code.getName(), style: context.textTheme.primary.bold), //
                                TextSpan(text: "\n"), //
                                TextSpan(
                                  text: data.price.formatUnit(digit: 3), //
                                  style: TextStyle(color: data.color),
                                ),
                              ],
                            ),
                          ).expaned(30),
                          SizedBox(
                            height: 60, //
                            child: GChartWidget(chart: data.chart, tickerProvider: this),
                          ).expaned(70),
                        ],
                      );
                    },
                  );
                }).toList(),
          );
        },
      ),
    ];
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
              Text(
                item.desc.toDashIfNull,
                style: context.textTheme.secondary.size13,
                overflow: TextOverflow.fade,
                maxLines: 1,
                softWrap: false,
              ), //
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
