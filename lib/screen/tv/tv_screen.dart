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
import 'package:do_x/view_model/tv/tv_view_model.dart';
import 'package:do_x/widgets/app_bar/app_bar_base.dart';
import 'package:do_x/widgets/app_bar/app_bar_sync_icon.dart';
import 'package:do_x/widgets/app_scaffold.dart';
import 'package:do_x/widgets/dialog/app_modal.dart';
import 'package:do_x/widgets/loading.dart';
import 'package:do_x/widgets/neu/neu_button.dart';
import 'package:do_x/widgets/neu/neu_chip.dart';
import 'package:flutter/material.dart';
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

  @override
  String get tabRouteName => TvRoute.name;

  @override
  ScrollController get tabScrollController => _scrollController;

  @override
  Future<void> onTabRefresh() => vm.onRefresh();

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final viewModel = context.watch<TvViewModel>();

    return AppScaffold(
      appBar: DoAppBar(
        title: l10n.tvChannels,
        titleSuffix: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 8,
          children: [
            // How much this country has on air, which is the one number that
            // changes with every pick of the flag beside it.
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
        actions: [_buildCountryButton(viewModel, l10n)],
      ),
      body: RefreshIndicator.adaptive(
        onRefresh: viewModel.onRefresh,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // The content cap has to be applied by hand in a sliver tree: the
            // padding is what centres the column, so it carries half of
            // whatever the viewport has over [Dimens.contentMaxWidth].
            final overflow = constraints.maxWidth - Dimens.contentMaxWidth;
            final horizontalPadding =
                Dimens.pagePadding + (overflow > 0 ? overflow / 2 : 0);

            return CustomScrollView(
              controller: _scrollController,
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    12,
                    horizontalPadding,
                    4,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: _buildSearchField(viewModel, l10n),
                  ),
                ),
                if (viewModel.groups.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _buildGroupChips(viewModel, l10n, horizontalPadding),
                  ),
                _buildContent(viewModel, l10n, horizontalPadding),
              ],
            );
          },
        ),
      ),
    );
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

  Widget _buildSearchField(TvViewModel viewModel, AppLocalizations l10n) {
    return TextField(
      controller: _searchController,
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

  /// Category chips. Full-bleed on purpose — the row scrolls, so its first and
  /// last chip sit at the content edge while the rest can run past it.
  Widget _buildGroupChips(
    TvViewModel viewModel,
    AppLocalizations l10n,
    double horizontalPadding,
  ) {
    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          8,
          horizontalPadding,
          8,
        ),
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
          maxCrossAxisExtent: 150,
          childAspectRatio: 0.85,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: viewModel.channels.length,
        itemBuilder: (context, index) {
          final channel = viewModel.channels[index];
          return TvChannelCard(
            channel: channel,
            onTap: () => _openChannel(channel),
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

  void _openChannel(TvChannel channel) {
    context.pushRoute(TvPlayerRoute(channel: channel));
  }
}
