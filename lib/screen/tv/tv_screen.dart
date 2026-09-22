import 'package:auto_route/auto_route.dart';
import 'package:do_x/constants/dimens.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/extensions/tv_category_extensions.dart';
import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/model/tv_channel.dart';
import 'package:do_x/model/tv_country.dart';
import 'package:do_x/router/app_router.gr.dart';
import 'package:do_x/screen/core/screen_state.dart';
import 'package:do_x/screen/core/tab_reselect.mixin.dart';
import 'package:do_x/screen/tv/tv_channel_card.dart';
import 'package:do_x/utils/device_type.dart';
import 'package:do_x/view_model/tv/tv_view_model.dart';
import 'package:do_x/widgets/app_bar/app_bar_base.dart';
import 'package:do_x/widgets/app_bar/app_bar_sync_icon.dart';
import 'package:do_x/widgets/app_scaffold.dart';
import 'package:do_x/widgets/dialog/app_modal.dart';
import 'package:do_x/widgets/loading.dart';
import 'package:do_x/widgets/neu/neu_button.dart';
import 'package:do_x/widgets/neu/neu_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

/// Live television: the channel list of the picked country from the iptv-org
/// playlist, and a tap to watch one.
@RoutePage()
class TvScreen extends StatefulScreen implements AutoRouteWrapper {
  const TvScreen({super.key});

  @override
  State<TvScreen> createState() => _TvScreenState();

  @override
  Widget wrappedRoute(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => TvViewModel(), //
      child: this,
    );
  }
}

/// Whether the page is waiting on the playlist, for the app bar's spinner.
bool _isBusy(TvViewModel vm) => vm.isLoading || vm.isRefreshing;

class _TvScreenState extends ScreenState<TvScreen, TvViewModel>
    with TabReselect {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode(debugLabel: 'tv-search');
  final Map<String, FocusNode> _channelFocusNodes = {};

  /// Whether the remote has been pointed at the grid since the page opened.
  ///
  /// A television opens a page with the focus on the route's own scope, and
  /// the first thing an arrow key then finds is whatever sits highest — the
  /// country flag up in the app bar. The channels are what the page is for,
  /// so the remote starts on them.
  bool _hasAimedRemote = false;

  FocusNode _getFocusNodeForChannel(String url) {
    return _channelFocusNodes.putIfAbsent(
      url,
      () => FocusNode(debugLabel: 'tv-channel-$url'),
    );
  }

  @override
  String get tabRouteName => TvRoute.name;

  @override
  ScrollController get tabScrollController => _scrollController;

  @override
  Future<void> onTabRefresh() => vm.onRefresh();

  @override
  void onResume() {
    super.onResume();
    // Coming back to the tab is opening the page again as far as the remote
    // is concerned, so it is aimed at the channels once more — but only if it
    // has nowhere else to be, which [_aimRemoteAtChannels] checks.
    _hasAimedRemote = false;
  }

  /// Puts the remote on the first channel, once there is one to put it on.
  void _aimRemoteAtChannels(TvViewModel viewModel) {
    if (!deviceType.isTv || _hasAimedRemote) return;
    if (viewModel.channels.isEmpty) return;
    _hasAimedRemote = true;
    final url = viewModel.channels.first.url;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Only while the remote is still homeless: between the frame the
      // channels arrived on and this one the viewer may have moved it
      // somewhere themselves, and that is not ours to undo.
      final current = FocusManager.instance.primaryFocus;
      if (current != null && current is! FocusScopeNode) return;
      _channelFocusNodes[url]?.requestFocus();
    });
  }

  @override
  void dispose() {
    for (final node in _channelFocusNodes.values) {
      node.dispose();
    }
    _searchFocusNode.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final viewModel = context.watch<TvViewModel>();
    _aimRemoteAtChannels(viewModel);

    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && _isSearchKey(event.logicalKey)) {
          _openSearch();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: AppScaffold(
        appBar: DoAppBar(
          title: l10n.tvChannels,
          titleSuffix: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 8,
            children: [
              // How much this country has on air, which is the one number
              // that changes with every pick of the flag beside it.
              if (viewModel.totalChannels > 0)
                Text(
                  l10n.tvChannelCount(viewModel.totalChannels),
                  style: context.theme.textTheme.bodySmall?.copyWith(
                    color: context.theme.hintColor,
                  ),
                ),
              const AppBarSyncIcon<TvViewModel>(selector: _isBusy),
            ],
          ),
          actions: [
            // In the bar rather than on the page, the way the movie page
            // carries its own search: the page below is then nothing but
            // channels, which is what a television is there to show.
            if (deviceType.isTv) ...[
              _buildSearchButton(l10n),
              const SizedBox(width: 8),
            ],
            _buildCountryButton(viewModel, l10n),
          ],
        ),
        body: Column(
          children: [
            // Above the scroll view rather than pinned inside it: the
            // box is how anyone reaches a channel in a list this
            // long, so it stays put, and a field has no height a
            // header could be told in advance — it grows with the
            // text scale.
            //
            // A television has no box here at all: it searches from
            // the button in the app bar, into a layer of its own.
            if (!deviceType.isTv)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  Dimens.pagePadding,
                  12,
                  Dimens.pagePadding,
                  4,
                ),
                child: _buildSearchField(viewModel, l10n),
              ),
            Expanded(
              child: RefreshIndicator.adaptive(
                onRefresh: viewModel.onRefresh,
                child: CustomScrollView(
                  controller: _scrollController,
                  // The grid can be shorter than the viewport — one
                  // search result, or none — and pull to refresh has
                  // to keep working when it is.
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    if (viewModel.groups.isNotEmpty)
                      SliverToBoxAdapter(
                        child: _buildGroupChips(
                          viewModel,
                          l10n,
                          Dimens.pagePadding,
                        ),
                      ),
                    _buildContent(viewModel, l10n, Dimens.pagePadding),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The search button on a remote, under each of the names one arrives by.
  ///
  /// Android's `KEYCODE_SEARCH` is the one Flutter has a name for; the mic and
  /// voice-assist keys of a television remote have none, so they come through
  /// on Flutter's Android plane — the raw Android key code with the plane
  /// added — and have to be matched by number.
  bool _isSearchKey(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.browserSearch) return true;
    const androidPlane = 0x1100000000;
    const androidSearch = 84; // KEYCODE_SEARCH
    const androidVoiceDial = 92; // KEYCODE_VOICE_DIAL
    return key.keyId == androidPlane + androidSearch ||
        key.keyId == androidPlane + androidVoiceDial;
  }

  /// Opens the search.
  ///
  /// On a television that is a page of its own — a full-screen keyboard leaves
  /// no room to type into a box wedged onto this one. Anywhere else the box is
  /// already on the page and the keyboard only has to be put in it.
  Future<void> _openSearch() async {
    if (!deviceType.isTv) {
      _searchFocusNode.requestFocus();
      return;
    }
    // The same view model travels with it, so the results are this country's
    // channels; the search page clears the query again on its way out.
    await context.pushRoute(TvSearchRoute(tvVm: vm));
    if (!mounted) return;
    // The page took the remote with it, so this one aims it again — at the
    // channels, where it starts when the page opens.
    setState(() => _hasAimedRemote = false);
  }

  /// The country whose playlist is on screen, and the way to change it. The
  /// flag alone: it is what tells two countries apart at a glance, and the
  /// name would leave no room for the title.
  Widget _buildCountryButton(TvViewModel viewModel, AppLocalizations l10n) {
    final country = viewModel.country;
    return Tooltip(
      message: country.name.isEmpty ? l10n.tvCountry : country.name,
      child: NeuChip(
        label: country.flag.isEmpty ? country.code : country.flag,
        isSelected: false,
        fontSize: 18,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        trailing: Icons.expand_more_rounded,
        onTap: () => _pickCountry(viewModel, l10n),
      ),
    );
  }

  Future<void> _pickCountry(
    TvViewModel viewModel,
    AppLocalizations l10n,
  ) async {
    if (viewModel.countries.isEmpty) return;
    final picked = await showAppSearchSheet<TvCountry>(
      context,
      title: l10n.tvCountry,
      options: viewModel.countries,
      selected: viewModel.country,
      labelBuilder: (country) => country.label,
      searchIndex: (country) => country.searchIndex,
      searchHint: l10n.tvCountryHint,
    );
    if (picked == null || !mounted) return;
    await viewModel.selectCountry(picked);
  }

  /// The way into the search on a television: one button in the app bar,
  /// like the movie page's.
  Widget _buildSearchButton(AppLocalizations l10n) {
    return NeuIconButton(
      size: Dimens.appBarActionSize,
      iconSize: 18,
      depth: Dimens.appBarActionDepth,
      tooltip: l10n.tvSearchHint,
      icon: Icons.search_rounded,
      onPressed: _openSearch,
    );
  }

  Widget _buildSearchField(TvViewModel viewModel, AppLocalizations l10n) {
    return TextField(
      controller: _searchController,
      focusNode: _searchFocusNode,
      onChanged: viewModel.search,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: l10n.tvSearchHint,
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: _searchController.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.clear_rounded),
                onPressed: () {
                  _searchController.clear();
                  viewModel.search('');
                  setState(() {});
                },
              ),
      ),
      // Only the clear button depends on this, and the view model already
      // rebuilds the list.
      onTapOutside: (_) => FocusScope.of(context).unfocus(),
    );
  }

  /// Keep the clip inside the page margins and the viewport inside fixed
  /// gutters, so chip shadows have room without painting into the page padding.
  Widget _buildGroupChips(
    TvViewModel viewModel,
    AppLocalizations l10n,
    double horizontalPadding,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: ClipRect(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: SizedBox(
            height: 46,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const ClampingScrollPhysics(),
              clipBehavior: Clip.none,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: viewModel.groups.length + 1,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return NeuChip(
                    label: l10n.all,
                    isSelected: viewModel.selectedGroup == null,
                    onTap: () => viewModel.selectGroup(null),
                  );
                }
                final group = viewModel.groups[index - 1];
                return NeuChip(
                  label: tvCategoryLabel(group, l10n),
                  isSelected: viewModel.selectedGroup == group,
                  onTap: () => viewModel.selectGroup(group),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    TvViewModel viewModel,
    AppLocalizations l10n,
    double horizontalPadding,
  ) {
    if (viewModel.isLoading) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: Loading()),
      );
    }
    if (viewModel.hasError) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _buildMessage(
          icon: Icons.cloud_off_rounded,
          message: l10n.tvLoadFailed,
          action: NeuButton(
            onPressed: viewModel.onRefresh,
            child: Text(l10n.retry),
          ),
        ),
      );
    }
    if (viewModel.channels.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _buildMessage(
          icon: Icons.live_tv_rounded,
          message: viewModel.isFilteredEmpty
              ? l10n.tvNoResults
              : l10n.tvNoChannels,
        ),
      );
    }

    return SliverPadding(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        8,
        horizontalPadding,
        MediaQuery.paddingOf(context).bottom + 24,
      ),
      sliver: SliverGrid.builder(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: Dimens.tvChannelTileMaxWidth,
          childAspectRatio: Dimens.tvChannelTileAspect,
          crossAxisSpacing: Dimens.tvChannelTileSpacing,
          mainAxisSpacing: Dimens.tvChannelTileSpacing,
        ),
        itemCount: viewModel.channels.length,
        itemBuilder: (context, index) {
          final channel = viewModel.channels[index];
          return TvChannelCard(
            key: ValueKey(channel.url),
            channel: channel,
            focusNode: _getFocusNodeForChannel(channel.url),
            onTap: () => _openChannel(channel, viewModel.channels),
          );
        },
      ),
    );
  }

  Widget _buildMessage({
    required IconData icon,
    required String message,
    Widget? action,
  }) {
    return Padding(
      padding: Dimens.screenPadding,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: 12,
        children: [
          Icon(icon, size: 48, color: context.theme.disabledColor),
          Text(message, textAlign: TextAlign.center),
          ?action,
        ],
      ),
    );
  }

  Future<void> _openChannel(TvChannel channel, List<TvChannel> playlist) async {
    // The whole list travels with the channel: the player is a television,
    // and up and down there move to the next channel rather than back here.
    final finalChannel = await context.pushRoute<TvChannel?>(
      TvPlayerRoute(channel: channel, playlist: playlist),
    );
    if (!mounted) return;

    final targetChannel = finalChannel ?? channel;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final node = _channelFocusNodes[targetChannel.url];
      if (node != null) {
        node.requestFocus();
      }
    });
  }
}
