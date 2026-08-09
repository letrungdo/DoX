import 'package:auto_route/auto_route.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:do_x/constants/dimens.dart';
import 'package:do_x/constants/enum/market_code.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/extensions/date_extensions.dart';
import 'package:do_x/extensions/double_extensions.dart';
import 'package:do_x/extensions/string_extensions.dart';
import 'package:do_x/extensions/text_style_extensions.dart';
import 'package:do_x/extensions/widget_extensions.dart';
import 'package:do_x/gen/assets.gen.dart';
import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/model/fx/gold_model.dart';
import 'package:do_x/model/news/gold_news.dart';
import 'package:do_x/router/app_router.gr.dart';
import 'package:do_x/screen/core/screen_state.dart';
import 'package:do_x/screen/core/tab_reselect.mixin.dart';
import 'package:do_x/services/fx_rate_service.dart';
import 'package:do_x/services/web_socket/web_socket_service.dart';
import 'package:do_x/view_model/news/coin_chart.dart';
import 'package:do_x/view_model/news/news_view_model.dart';
import 'package:do_x/widgets/app_bar/app_bar_base.dart';
import 'package:do_x/widgets/app_scaffold.dart';
import 'package:do_x/widgets/chart/line_area_chart.dart';
import 'package:do_x/widgets/text/text_auto_scale_widget.dart';
import 'package:do_x/widgets/app_bar/app_bar_sync_icon.dart';
import 'package:do_x/widgets/neu/neu_card.dart';
import 'package:do_x/widgets/neu/neu_surface.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:visibility_detector/visibility_detector.dart';

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

class _NewsScreenState<V extends NewsViewModel>
    extends ScreenState<NewsScreen, V>
    with TabReselect {
  final colsRatio = [40, 30, 30];
  final _scrollController = ScrollController();

  /// The push socket only needs to run while this tab is actually on screen.
  bool _isVisible = true;

  WebSocketService get _socketService => context.read<WebSocketService>();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  String get tabRouteName => NewsRoute.name;

  @override
  ScrollController get tabScrollController => _scrollController;

  @override
  Future<void> onTabRefresh() => vm.onRefresh();

  @override
  void onResume() {
    super.onResume();
    vm.onRefresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      if (_isVisible) _socketService.connect(context);
    } else if (state == AppLifecycleState.paused) {
      _socketService.disconnect();
    }
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    final visible = info.visibleFraction > 0;
    if (visible == _isVisible || !mounted) return;
    _isVisible = visible;
    if (visible) {
      _socketService.connect(context);
    } else {
      _socketService.disconnect();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return VisibilityDetector(
      key: const Key('news-screen'),
      onVisibilityChanged: _onVisibilityChanged,
      child: AppScaffold(
        appBar: DoAppBar(
          title: l10n.news, //
          titleSuffix: AppBarSyncIcon<V>(selector: (vm) => vm.isFetching),
        ),
        body: RefreshIndicator.adaptive(
          onRefresh: () => vm.onRefresh(showLoading: true), //
          child: _buildBody(l10n),
        ),
      ),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    return CustomScrollView(
      controller: _scrollController,
      physics: AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverLayoutBuilder(
          builder: (context, constraints) {
            // The page padding sits inside the shared content cap, exactly as
            // `contentConstrainedBox()` puts it on the other pages — so a card
            // here is the same width as a card anywhere else.
            final overflow =
                constraints.crossAxisExtent - Dimens.contentMaxWidth;
            final horizontalPadding =
                Dimens.pagePadding + (overflow > 0 ? overflow / 2 : 0);
            return SliverPadding(
              // 16, not 15: a card's shadow reaches ~17px, so a tighter page
              // padding lets the viewport clip the first/last card's rim.
              padding: EdgeInsets.symmetric(
                vertical: 16,
                horizontal: horizontalPadding,
              ), //
              sliver: SliverList(
                delegate: SliverChildListDelegate(_buildPrice(l10n)),
              ),
            );
          },
        ),
      ],
    );
  }

  List<Widget> _buildPrice(AppLocalizations l10n) {
    final colors = context.colors;
    return [
      _SectionHeader(
        icon: Icons.currency_exchange_rounded, //
        color: colors.info,
        title: l10n.exchangeRate,
        badge: "JPY/VND",
      ),
      const SizedBox(height: 10),
      _buildFxCard(),
      const SizedBox(height: 22),
      _SectionHeader(
        icon: Icons.workspace_premium_rounded, //
        color: colors.warning,
        title: l10n.goldPrice,
      ),
      const SizedBox(height: 10),
      _buildGoldCard(l10n),
      const SizedBox(height: 22),
      _SectionHeader(
        icon: Icons.auto_awesome_rounded, //
        color: colors.warning,
        title: l10n.goldNews,
        badge: "AI",
      ),
      const SizedBox(height: 10),
      _buildGoldNewsCard(l10n),
      const SizedBox(height: 22),
      _SectionHeader(
        icon: Icons.show_chart_rounded, //
        color: colors.money,
        title: l10n.market,
      ),
      const SizedBox(height: 10),
      _buildMarketCard(),
    ];
  }

  /// The four JPY→VND sources as a 2×2 grid of tinted tiles. A bordered table
  /// squeezed all four into one row, which clipped the longer provider names.
  Widget _buildFxCard() {
    final colors = context.colors;
    final tiles = [
      _buildFxTile(
        "Google",
        colors.info,
        colors.infoSoft,
        (vm) => vm.googleRate,
      ),
      _buildFxTile(
        "Smile",
        colors.success,
        colors.successSoft,
        (vm) => vm.smileRate,
      ),
      _buildFxTile(
        "MoneyGram",
        colors.danger,
        colors.dangerSoft,
        (vm) => vm.moneyGramRate,
      ),
      _buildFxTile(
        "Dcom",
        colors.warning,
        colors.warningSoft,
        (vm) => vm.dcomRate,
      ),
    ];
    // 14, not 8: the tiles are raised panels now, and a gap narrower than their
    // shadow reach lets one tile's lit rim land on the next one's shade.
    return Column(
      spacing: 14,
      children: [
        Row(spacing: 14, children: [tiles[0].expaned(1), tiles[1].expaned(1)]),
        Row(spacing: 14, children: [tiles[2].expaned(1), tiles[3].expaned(1)]),
      ],
    );
  }

  Widget _buildFxTile(
    String name,
    Color color,
    Color softColor,
    String? Function(V vm) selector,
  ) {
    return NeuCard(
      color: softColor,
      radius: 10,
      depth: 0.5,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      child: Row(
        spacing: 6,
        children: [
          // Expanded, not Flexible: it pushes the rate to the right edge and
          // gives the label the leftover width to shrink into.
          Expanded(
            child: AutoSizeText(
              name,
              maxLines: 1,
              style: context.textTheme.title.size13.medium.fit,
            ),
          ),
          Selector<V, String?>(
            selector: (_, vm) => selector(vm),
            builder: (context, value, _) {
              // Blank until the first value lands: a dash next to a spinning
              // sync icon reads as "no data" rather than "still loading".
              return AutoSizeText(
                value ?? "",
                maxLines: 1,
                style: context.textTheme.primary.size15.bold.fit.textColor(
                  color,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildGoldCard(AppLocalizations l10n) {
    final headerStyle = context.textTheme.title.size13.medium;
    return NeuCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Text(l10n.index, style: headerStyle).expaned(colsRatio[0]), //
                  Text(
                    l10n.buy,
                    style: headerStyle,
                    textAlign: TextAlign.right,
                  ).expaned(colsRatio[1]),
                  Text(
                    l10n.sell,
                    style: headerStyle,
                    textAlign: TextAlign.right,
                  ).expaned(colsRatio[2]),
                ],
              ),
            ),
            Selector<V, List<GoldSymbol>>(
              selector: (_, vm) => vm.goldPrices,
              builder: (context, data, _) {
                return Column(
                  children: [
                    for (final item in data) ...[
                      const Divider(height: 1),
                      _buildGoldPriceItem(item),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// The daily digest: one AI paragraph, the headlines behind it, and the
  /// articles they came from. The whole thing is built server-side, in both of
  /// the app's languages, so switching language needs no extra fetch — only
  /// the source titles stay in whatever language the outlet published them.
  Widget _buildGoldNewsCard(AppLocalizations l10n) {
    final lang = l10n.localeName;
    return Selector<V, GoldNews?>(
      selector: (_, vm) => vm.goldNews,
      builder: (context, news, _) {
        return NeuCard(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: news == null
                ? Text(
                    l10n.goldNewsEmpty,
                    style: context.textTheme.title.size13, //
                  )
                : _buildDigest(l10n, news, lang),
          ),
        );
      },
    );
  }

  Widget _buildDigest(AppLocalizations l10n, GoldNews news, String lang) {
    final reason = news.sentimentReason(lang);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildSentimentChip(l10n, news.sentiment),
            const Spacer(),
            Text(
              _digestTime(l10n, news),
              style: context.textTheme.title.size13,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          news.summary(lang),
          style: context.textTheme.primary.size17.copyWith(height: 1.45),
        ),
        if (reason != null) ...[
          const SizedBox(height: 6),
          Text(
            reason,
            style: context.textTheme.title.size15.copyWith(height: 1.4),
          ),
        ],
        for (final item in news.highlights) ...[
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          _buildHighlight(item, news.sourceOf(item), lang),
        ],
      ],
    );
  }

  /// When the digest was put together. It is rebuilt once a day, so the time
  /// of day is what tells the reader how stale the card is; the date is only
  /// spelled out once the digest is no longer from today.
  String _digestTime(AppLocalizations l10n, GoldNews news) {
    final updatedAt = news.updatedAt?.toLocal();
    if (updatedAt == null) return news.date.toStringFormat("dd/MM");
    final now = DateTime.now();
    final isToday =
        updatedAt.year == now.year &&
        updatedAt.month == now.month &&
        updatedAt.day == now.day;
    return l10n.goldNewsUpdatedAt(
      updatedAt.toStringFormat(isToday ? "HH:mm" : "HH:mm dd/MM"),
    );
  }

  Widget _buildSentimentChip(AppLocalizations l10n, GoldImpact sentiment) {
    final (color, icon, label) = switch (sentiment) {
      GoldImpact.up => (
        context.colors.success,
        Icons.trending_up_rounded,
        l10n.trendUp,
      ),
      GoldImpact.down => (
        context.colors.danger,
        Icons.trending_down_rounded,
        l10n.trendDown,
      ),
      GoldImpact.neutral => (
        context.colors.info,
        Icons.trending_flat_rounded,
        l10n.trendNeutral,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: context.neuTint(color, amount: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 5,
        children: [
          Icon(icon, size: 15, color: color),
          Text(
            label,
            style: context.textTheme.secondary.size13.bold.textColor(color),
          ),
        ],
      ),
    );
  }

  /// One bullet of the digest. Tapping it opens the article it came from —
  /// the AI text is a summary, so the original stays one tap away.
  Widget _buildHighlight(
    GoldNewsHighlight item,
    GoldNewsSource? source,
    String lang,
  ) {
    final color = switch (item.impact) {
      GoldImpact.up => context.colors.success,
      GoldImpact.down => context.colors.danger,
      GoldImpact.neutral => context.colors.info,
    };
    final icon = switch (item.impact) {
      GoldImpact.up => Icons.arrow_drop_up_rounded,
      GoldImpact.down => Icons.arrow_drop_down_rounded,
      GoldImpact.neutral => Icons.remove_rounded,
    };
    return InkWell(
      onTap: source == null ? null : () => _openSource(source),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 6,
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: context.neuTint(color, amount: 0.14),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title(lang),
                    style: context.textTheme.primary.size16.bold,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.detail(lang),
                    style: context.textTheme.title.size15.copyWith(height: 1.4),
                  ),
                  if (source != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      spacing: 4,
                      children: [
                        Icon(
                          Icons.open_in_new_rounded,
                          size: 13,
                          color: context.colors.info,
                        ),
                        Flexible(
                          child: Text(
                            source.source ?? source.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.textTheme.secondary.size13.textColor(
                              context.colors.info,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openSource(GoldNewsSource source) async {
    final uri = Uri.tryParse(source.url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Widget _buildMarketCard() {
    return NeuCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Selector<V, List<MarketCode>>(
          selector: (_, vm) => vm.coinChartMap.keys.toList(),
          builder: (context, codes, _) {
            return Column(
              children: [
                for (final (index, code) in codes.indexed) ...[
                  if (index > 0)
                    const Divider(height: 1, indent: 8, endIndent: 8),
                  _buildMarketItem(code),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildMarketItem(MarketCode code) {
    return Selector<V, ChartData?>(
      selector: (_, vm) => vm.coinChartMap[code],
      builder: (context, data, _) {
        final trend = _trendColor(data);
        final lineColor = trend ?? context.colors.info;
        return InkWell(
          onTap: () => context.router.push(MarketDetailRoute(code: code)),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: SizedBox(
              height: 52,
              child: Row(
                spacing: 8,
                children: [
                  SizedBox(
                    width: 116,
                    child: Row(
                      spacing: 8,
                      children: [
                        _buildCurrencyIcon(code),
                        Expanded(
                          child: TextAutoScaleWidget(
                            code.getName(),
                            style: context.textTheme.primary.size15.bold,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 50,
                    child: data == null
                        ? const SizedBox.shrink()
                        : LineAreaChart(
                            data: data.chartData,
                            times: data.times,
                            lineColor: lineColor,
                            areaColor: lineColor.withValues(alpha: 0.12),
                            strokeWidth: 2.0,
                            showArea: true,
                          ),
                  ),
                  Expanded(
                    flex: 46,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        TextAutoScaleWidget(
                          (data?.price).formatUnit(digit: 3),
                          style: context.textTheme.primary.size15.bold,
                          textAlign: TextAlign.right,
                        ),
                        _buildTrendChip(data),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Percentage move across the visible window, tinted like the sparkline so
  /// the row reads at a glance without comparing the chart's endpoints.
  Widget _buildTrendChip(ChartData? data) {
    final points = data?.chartData ?? const <double>[];
    if (points.length < 2 || points.first == 0) return const SizedBox.shrink();
    final diff = points.last - points.first;
    final percent = diff / points.first * 100;
    final color = _trendColor(data) ?? context.textTheme.title.color!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          diff > 0
              ? Icons.arrow_drop_up_rounded
              : diff < 0
              ? Icons.arrow_drop_down_rounded
              : Icons.remove_rounded,
          size: 16,
          color: color,
        ),
        Text(
          "${percent.abs().toStringAsFixed(2)}%",
          style: context.textTheme.secondary.size13.medium.textColor(color),
        ),
      ],
    );
  }

  /// Semantic trend color. The view model tags charts with raw
  /// `Colors.green`/`Colors.red`, which wash out on light surfaces, so the
  /// sign is re-mapped onto the theme's accents here.
  Color? _trendColor(ChartData? data) {
    final points = data?.chartData ?? const <double>[];
    if (points.length < 2) return null;
    final diff = points.last - points.first;
    if (diff > 0) return context.colors.success;
    if (diff < 0) return context.colors.danger;
    return null;
  }

  Color? _changeColor(double? value) {
    if (value == null || value == 0) return null;
    return value > 0 ? context.colors.success : context.colors.danger;
  }

  Widget _buildCurrencyIcon(MarketCode code) {
    IconData? iconData;
    Color? iconColor;
    AssetGenImage? image;
    switch (code) {
      case MarketCode.xauUSD:
        image = Assets.images.gold;
        break;
      case MarketCode.xagUSD:
        image = Assets.images.silver;
        break;
      case MarketCode.btcUSDT:
        image = Assets.images.btc;
        break;
      case MarketCode.bnbUSDT:
        image = Assets.images.bnb;
        break;
      case MarketCode.ethUSDT:
        image = Assets.images.eth;
        break;
      case MarketCode.vnIndex:
        iconData = Icons.trending_up;
        iconColor = context.colors.success;
        break;
    }
    if (iconData != null) {
      return Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: iconColor == null
              ? null
              : context.neuTint(iconColor, amount: 0.14),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(iconData, size: 20, color: iconColor),
      );
    }
    return image!.image(width: 32, height: 32);
  }

  Widget _buildGoldPriceItem(GoldSymbol item) {
    return SizedBox(
      height: 54,
      child: Row(
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name.toDashIfNull,
                style: context.textTheme.primary.size15.bold,
              ), //
              Text(
                item.desc.toDashIfNull,
                style: context.textTheme.title.size13,
                overflow: TextOverflow.fade,
                maxLines: 1,
                softWrap: false,
              ), //
            ],
          ).expaned(colsRatio[0]),
          _buildGoldValue(item.bid, item.bidDayChange).expaned(colsRatio[1]),
          _buildGoldValue(item.ask, item.askDayChange).expaned(colsRatio[2]),
        ],
      ),
    );
  }

  Widget _buildGoldValue(double? price, double? change) {
    final changeColor = _changeColor(change);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          price.formatUnit(),
          style: context.textTheme.primary.size15.medium, //
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (changeColor != null)
              Icon(
                (change ?? 0) > 0
                    ? Icons.arrow_drop_up_rounded
                    : Icons.arrow_drop_down_rounded,
                size: 16,
                color: changeColor,
              ),
            Text(
              change.formatUnit(hasPlus: true), //
              style: context.textTheme.secondary.size13.medium.copyWith(
                color: changeColor ?? context.textTheme.title.color,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Section label: a tinted icon chip, the title, and an optional badge on the
/// right. Repeated for each block on the screen so the three data groups read
/// as separate cards instead of one long list.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon, //
    required this.color,
    required this.title,
    this.badge,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final badge = this.badge;
    return Row(
      spacing: 8,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: context.neuTint(color, amount: 0.14),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 17, color: color),
        ),
        Expanded(
          child: Text(
            title,
            style: context.textTheme.primary.size16.bold, //
          ),
        ),
        if (badge != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: context.neuTint(color, amount: 0.14),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              badge,
              style: context.textTheme.secondary.size13.bold.textColor(color),
            ),
          ),
      ],
    );
  }
}
