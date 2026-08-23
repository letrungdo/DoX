import 'dart:io';

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
import 'package:do_x/model/market/market_overview.dart';
import 'package:do_x/model/news/gold_news.dart';
import 'package:do_x/model/news/news_source.dart';
import 'package:do_x/model/news/storm_news.dart';
import 'package:do_x/router/app_router.gr.dart';
import 'package:do_x/screen/news/market_picker_sheet.dart';
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
import 'package:do_x/widgets/neu/neu_button.dart';
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

  /// The digest opens collapsed: the paragraph is the headline, the bullets and
  /// their source links only come out once the reader asks for them.
  bool _isNewsExpanded = false;

  /// Same for the storm bulletin: the headline and the summary carry the alert,
  /// the per-source bullets wait behind the toggle.
  bool _isStormExpanded = false;

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
      if (!Platform.isMacOS) _socketService.disconnect();
    }
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    final visible = info.visibleFraction > 0;
    if (visible == _isVisible || !mounted) return;
    _isVisible = visible;
    if (visible) {
      _socketService.connect(context);
    } else {
      if (!Platform.isMacOS) _socketService.disconnect();
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
      // A live storm warning outranks every price on the page, so it sits above
      // them — and takes its own vertical gap with it, since the whole section
      // disappears whenever there is nothing to warn about.
      _buildStormSection(l10n),
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
        action: NeuIconButton(
          icon: Icons.tune_rounded,
          size: 32,
          iconSize: 17,
          tooltip: l10n.marketPicker,
          onPressed: _pickMarkets,
        ),
      ),
      const SizedBox(height: 10),
      _buildMarketCard(l10n),
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
                  Expanded(
                    flex: colsRatio[0],
                    child: AutoSizeText(
                      l10n.index,
                      style: headerStyle,
                      maxLines: 1,
                      minFontSize: 11,
                    ),
                  ),
                  Expanded(
                    flex: colsRatio[1],
                    child: AutoSizeText(
                      l10n.buy,
                      style: headerStyle,
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      minFontSize: 11,
                    ),
                  ),
                  Expanded(
                    flex: colsRatio[2],
                    child: AutoSizeText(
                      l10n.sell,
                      style: headerStyle,
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      minFontSize: 11,
                    ),
                  ),
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

  /// The storm bulletin, shown only while a storm is actually affecting
  /// Vietnam: with nothing to warn about the view model hands back null and
  /// the whole section — header, card and gap — is left out of the page.
  Widget _buildStormSection(AppLocalizations l10n) {
    return Selector<V, StormNews?>(
      selector: (_, vm) => vm.stormNews,
      builder: (context, news, _) {
        if (news == null) return const SizedBox.shrink();
        final color = _stormColor(news.severity);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(
              icon: Icons.cyclone_rounded, //
              color: color,
              title: l10n.stormAlert,
              badge: _stormSeverityLabel(l10n, news.severity),
            ),
            const SizedBox(height: 10),
            _buildStormCard(l10n, news, color),
            const SizedBox(height: 22),
          ],
        );
      },
    );
  }

  Widget _buildStormCard(AppLocalizations l10n, StormNews news, Color color) {
    final lang = l10n.localeName;
    final name = news.name(lang);
    final headline = news.headline(lang);
    final advice = news.advice(lang);
    final expanded = _isStormExpanded;
    // With no bullets there is no toggle, so nothing would ever open the
    // advice: show it straight away instead of hiding it for good.
    final showAdvice = expanded || news.highlights.isEmpty;
    return NeuCard(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    name.isEmpty ? l10n.stormAlert : name,
                    style: context.textTheme.primary.size17.bold.textColor(
                      color,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _bulletinTime(l10n, news.updatedAt, news.date),
                  style: context.textTheme.title.size13,
                ),
              ],
            ),
            if (headline != null) ...[
              const SizedBox(height: 6),
              Text(
                headline,
                style: context.textTheme.primary.size16.copyWith(height: 1.4),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              news.summary(lang),
              maxLines: expanded ? null : 3,
              overflow: expanded ? null : TextOverflow.ellipsis,
              style: context.textTheme.title.size15.copyWith(height: 1.45),
            ),
            if (advice != null && showAdvice) ...[
              const SizedBox(height: 10),
              _buildStormAdvice(l10n, advice, color),
            ],
            if (news.highlights.isNotEmpty) ...[
              AnimatedSize(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                alignment: Alignment.topCenter,
                child: expanded
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final item in news.highlights) ...[
                            const SizedBox(height: 12),
                            const Divider(height: 1),
                            const SizedBox(height: 12),
                            _buildNewsHighlight(
                              title: item.title(lang),
                              detail: item.detail(lang),
                              icon: Icons.chevron_right_rounded,
                              color: color,
                              source: news.sourceOf(item),
                            ),
                          ],
                        ],
                      )
                    : const SizedBox(width: double.infinity),
              ),
              _buildExpandToggle(
                l10n,
                count: news.highlights.length,
                expanded: expanded,
                color: color,
                onTap: () => setState(() => _isStormExpanded = !expanded),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// What to do about it, set apart from the reporting above it: the one part
  /// of the bulletin the reader may need to act on.
  Widget _buildStormAdvice(AppLocalizations l10n, String advice, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: context.neuTint(color, amount: 0.14),
        borderRadius: BorderRadius.circular(Dimens.radiusPanel),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 3,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 5,
            children: [
              Icon(Icons.shield_outlined, size: 15, color: color),
              Text(
                l10n.stormAdvice,
                style: context.textTheme.secondary.size13.bold.textColor(color),
              ),
            ],
          ),
          Text(
            advice,
            style: context.textTheme.title.size15.copyWith(height: 1.4),
          ),
        ],
      ),
    );
  }

  Color _stormColor(StormSeverity severity) => switch (severity) {
    StormSeverity.watch => context.colors.info,
    StormSeverity.warning => context.colors.warning,
    StormSeverity.emergency => context.colors.danger,
  };

  String _stormSeverityLabel(AppLocalizations l10n, StormSeverity severity) =>
      switch (severity) {
        StormSeverity.watch => l10n.stormSeverityWatch,
        StormSeverity.warning => l10n.stormSeverityWarning,
        StormSeverity.emergency => l10n.stormSeverityEmergency,
      };

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
    final expanded = _isNewsExpanded;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildSentimentChip(l10n, news.sentiment),
            const Spacer(),
            Text(
              _bulletinTime(l10n, news.updatedAt, news.date),
              style: context.textTheme.title.size13,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          news.summary(lang),
          maxLines: expanded ? null : 3,
          overflow: expanded ? null : TextOverflow.ellipsis,
          style: context.textTheme.primary.size17.copyWith(height: 1.45),
        ),
        if (reason != null && expanded) ...[
          const SizedBox(height: 6),
          Text(
            reason,
            style: context.textTheme.title.size15.copyWith(height: 1.4),
          ),
        ],
        if (news.highlights.isNotEmpty) ...[
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: expanded
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final item in news.highlights) ...[
                        const SizedBox(height: 12),
                        const Divider(height: 1),
                        const SizedBox(height: 12),
                        _buildHighlight(item, news.sourceOf(item), lang),
                      ],
                    ],
                  )
                : const SizedBox(width: double.infinity),
          ),
          _buildExpandToggle(
            l10n,
            count: news.highlights.length,
            expanded: expanded,
            color: context.colors.info,
            onTap: () => setState(() => _isNewsExpanded = !expanded),
          ),
        ],
      ],
    );
  }

  /// The one control that opens a bulletin. Collapsed it reads as "n bullets
  /// waiting"; expanded it is the way back to the short card.
  Widget _buildExpandToggle(
    AppLocalizations l10n, {
    required int count,
    required bool expanded,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Dimens.radiusControlSmall),
      child: Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 4,
          children: [
            Text(
              expanded ? l10n.newsCollapse : l10n.newsDetails(count),
              style: context.textTheme.secondary.size13.bold.textColor(color),
            ),
            AnimatedRotation(
              turns: expanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 180),
              child: Icon(Icons.expand_more_rounded, size: 18, color: color),
            ),
          ],
        ),
      ),
    );
  }

  /// When a bulletin was put together. The time of day is what tells the reader
  /// how stale the card is; the date is only spelled out once the bulletin is
  /// no longer from today.
  String _bulletinTime(
    AppLocalizations l10n,
    DateTime? updatedAtUtc,
    DateTime date,
  ) {
    final updatedAt = updatedAtUtc?.toLocal();
    if (updatedAt == null) return date.toStringFormat("dd/MM");
    final now = DateTime.now();
    final isToday =
        updatedAt.year == now.year &&
        updatedAt.month == now.month &&
        updatedAt.day == now.day;
    return l10n.newsUpdatedAt(
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
        borderRadius: BorderRadius.circular(Dimens.radiusPanel),
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

  /// One bullet of the gold digest: the impact decides its colour and arrow,
  /// the rest is the shared bullet row.
  Widget _buildHighlight(
    GoldNewsHighlight item,
    NewsSource? source,
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
    return _buildNewsHighlight(
      title: item.title(lang),
      detail: item.detail(lang),
      icon: icon,
      color: color,
      source: source,
    );
  }

  /// One bullet of a bulletin. Tapping it opens the article it came from — the
  /// AI text is a summary, so the original stays one tap away.
  Widget _buildNewsHighlight({
    required String title,
    required String detail,
    required IconData icon,
    required Color color,
    required NewsSource? source,
  }) {
    return InkWell(
      onTap: source == null ? null : () => _openSource(source),
      borderRadius: BorderRadius.circular(Dimens.radiusControlSmall),
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
                borderRadius: BorderRadius.circular(Dimens.radiusSmall),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.textTheme.primary.size16.bold),
                  const SizedBox(height: 3),
                  Text(
                    detail,
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

  Future<void> _openSource(NewsSource source) async {
    final uri = Uri.tryParse(source.url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _pickMarkets() async {
    final picked = await showMarketPickerSheet(
      context,
      selected: vm.markets, //
    );
    if (picked == null) return;
    await vm.setMarkets(picked);
  }

  Widget _buildMarketCard(AppLocalizations l10n) {
    return NeuCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        // Driven by the picked list rather than the fetched charts, so a market
        // added from the sheet gets its row straight away and fills in when the
        // bars arrive.
        child: Selector<V, List<MarketCode>>(
          selector: (_, vm) => vm.markets,
          builder: (context, codes, _) {
            if (codes.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 12,
                ),
                child: Text(
                  l10n.marketEmpty,
                  style: context.textTheme.title.size13,
                ),
              );
            }
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
    return Selector<V, (ChartData?, MarketOverview?)>(
      selector: (_, vm) => (vm.coinChartMap[code], vm.marketOverviews[code]),
      builder: (context, value, _) {
        final (data, overview) = value;
        final trend = _trendColor(data);
        final lineColor = trend ?? context.colors.info;
        return InkWell(
          onTap: () => context.router.push(MarketDetailRoute(code: code)),
          borderRadius: BorderRadius.circular(Dimens.radiusControlSmall),
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
                          (data?.price ?? overview?.price).formatUnit(digit: 3),
                          style: context.textTheme.primary.size15.bold,
                          textAlign: TextAlign.right,
                        ),
                        _buildTrendChip(data, overview),
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

  /// The day's move, from the overview snapshot — the number a reader expects
  /// next to a price. Until that lands (or where a group publishes no day
  /// change) it falls back to the move across the sparkline's own window, which
  /// is why the tint follows the value being shown rather than the line.
  Widget _buildTrendChip(ChartData? data, MarketOverview? overview) {
    final points = data?.chartData ?? const <double>[];
    final dayPercent = overview?.dayChangePercent;
    final double percent;
    if (dayPercent != null) {
      percent = dayPercent;
    } else {
      if (points.length < 2 || points.first == 0) {
        return const SizedBox.shrink();
      }
      percent = (points.last - points.first) / points.first * 100;
    }
    final diff = percent;
    final color = _changeColor(percent) ?? context.textTheme.title.color!;
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

  /// Semantic trend color. The view model reports the window's points and
  /// nothing about their colour, so the sign is mapped onto the theme's accents
  /// here — where there is a `context` to read the palette from.
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

  /// The five markets that shipped with the app have their own artwork; every
  /// other code in the catalogue falls back to a tinted glyph for its group,
  /// which keeps the column aligned without an asset per symbol.
  Widget _buildCurrencyIcon(MarketCode code) {
    final AssetGenImage? image = switch (code) {
      MarketCode.xauUSD => Assets.images.gold,
      MarketCode.xagUSD => Assets.images.silver,
      MarketCode.btcUSDT => Assets.images.btc,
      MarketCode.bnbUSDT => Assets.images.bnb,
      MarketCode.ethUSDT => Assets.images.eth,
      _ => null,
    };
    if (image != null) return image.image(width: 32, height: 32);

    final colors = context.colors;
    final (iconData, iconColor) = switch (code.group) {
      MarketGroup.commodity => (Icons.oil_barrel_rounded, colors.warning),
      MarketGroup.crypto => (Icons.currency_bitcoin_rounded, colors.money),
      MarketGroup.vnIndex => (Icons.trending_up, colors.success),
      MarketGroup.worldIndex => (Icons.public_rounded, colors.info),
      MarketGroup.usStock => (Icons.business_rounded, colors.info),
    };
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: context.neuTint(iconColor, amount: 0.14),
        borderRadius: BorderRadius.circular(Dimens.radiusControlSmall),
      ),
      child: Icon(iconData, size: 20, color: iconColor),
    );
  }

  Widget _buildGoldPriceItem(GoldSymbol item) {
    return SizedBox(
      height: 54,
      child: Row(
        children: [
          Expanded(
            flex: colsRatio[0],
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AutoSizeText(
                  item.name.toDashIfNull,
                  maxLines: 1,
                  minFontSize: 12,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.primary.size15.bold,
                ), //
                AutoSizeText(
                  item.desc.toDashIfNull,
                  maxLines: 1,
                  minFontSize: 10,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.title.size13,
                ), //
              ],
            ),
          ),
          Expanded(
            flex: colsRatio[1],
            child: _buildGoldValue(item.bid, item.bidDayChange),
          ),
          Expanded(
            flex: colsRatio[2],
            child: _buildGoldValue(item.ask, item.askDayChange),
          ),
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
        AutoSizeText(
          price.formatUnit(),
          maxLines: 1,
          minFontSize: 11,
          textAlign: TextAlign.right,
          style: context.textTheme.primary.size15.medium,
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (changeColor != null)
              Icon(
                (change ?? 0) > 0
                    ? Icons.arrow_drop_up_rounded
                    : Icons.arrow_drop_down_rounded,
                size: 16,
                color: changeColor,
              ),
            Flexible(
              child: AutoSizeText(
                change.formatUnit(hasPlus: true),
                maxLines: 1,
                minFontSize: 9,
                textAlign: TextAlign.right,
                style: context.textTheme.secondary.size13.medium.copyWith(
                  color: changeColor ?? context.textTheme.title.color,
                ),
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
    this.action,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String? badge;

  /// Control pinned to the right of the title, e.g. the market picker.
  final Widget? action;

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
            borderRadius: BorderRadius.circular(Dimens.radiusSmall),
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
              borderRadius: BorderRadius.circular(Dimens.radiusPanel),
            ),
            child: Text(
              badge,
              style: context.textTheme.secondary.size13.bold.textColor(color),
            ),
          ),
        ?action,
      ],
    );
  }
}
