import 'package:auto_route/auto_route.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/model/asset/asset_gold.dart';
import 'package:do_x/model/asset/asset_investment.dart';
import 'package:do_x/model/asset/asset_saving.dart';
import 'package:do_x/router/app_router.gr.dart';
import 'package:do_x/screen/asset/widgets/add_gold_dialog.dart';
import 'package:do_x/screen/asset/widgets/add_investment_dialog.dart';
import 'package:do_x/screen/asset/widgets/add_saving_dialog.dart';
import 'package:do_x/screen/asset/widgets/asset_year_filter.dart';
import 'package:do_x/screen/asset/widgets/gold_list.dart';
import 'package:do_x/screen/asset/widgets/investment_list.dart';
import 'package:do_x/screen/asset/widgets/saving_list.dart';
import 'package:do_x/screen/core/screen_state.dart';
import 'package:do_x/screen/core/tab_reselect.mixin.dart';
import 'package:do_x/view_model/asset_view_model.dart';
import 'package:do_x/widgets/app_bar/app_bar_base.dart';
import 'package:do_x/widgets/app_bar/app_bar_sync_icon.dart';
import 'package:do_x/widgets/app_scaffold.dart';
import 'package:do_x/widgets/dialog/app_modal.dart';
import 'package:do_x/widgets/surface/app_button.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

@RoutePage()
class AssetScreen extends StatefulScreen implements AutoRouteWrapper {
  const AssetScreen({super.key});

  @override
  State<AssetScreen> createState() => _AssetScreenState();

  @override
  Widget wrappedRoute(BuildContext context) {
    return ChangeNotifierProvider(create: (_) => AssetViewModel(), child: this);
  }
}

class _AssetScreenState extends ScreenState<AssetScreen, AssetViewModel>
    with SingleTickerProviderStateMixin, TabReselect {
  late TabController _tabController;

  @override
  String get tabRouteName => AssetRoute.name;

  @override
  Future<void> onTabRefresh() => vm.refresh();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AppScaffold(
      appBar: DoAppBar(
        title: l10n.assetTitle,
        titleSuffix: AppBarSyncIcon<AssetViewModel>(
          selector: (vm) => vm.isBusy,
        ),
        actions: [
          AppIconButton(
            icon: Icons.account_balance_wallet_rounded,
            tooltip: l10n.assetSummary,
            size: 34,
            onPressed: () => context.pushRoute(AssetSummaryRoute(assetVm: vm)),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: l10n.assetSavings),
            Tab(text: l10n.assetInvestments),
            Tab(text: l10n.assetGold),
          ],
        ),
      ),
      body: Consumer<AssetViewModel>(
        builder: (context, vm, child) {
          if (vm.isBusy && vm.summary == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final year = vm.selectedYear;
          // A list emptied by the filter is not an account with nothing in it,
          // and saying so is what tells the user to widen the year again.
          final filteredEmpty = year == null
              ? null
              : l10n.assetYearEmpty('$year');

          return Column(
            children: [
              AssetYearFilter(
                years: vm.availableYears,
                selected: year,
                onChanged: vm.selectYear,
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    SavingList(
                      savings: vm.filteredSavings,
                      emptyMessage: filteredEmpty,
                      onRefresh: vm.refresh,
                      onEdit: (item) => _onAddAsset(saving: item),
                      onDelete: (id) => _onDeleteAsset(l10n.assetSavings, id),
                    ),
                    InvestmentList(
                      investments: vm.filteredInvestments,
                      emptyMessage: filteredEmpty,
                      onRefresh: vm.refresh,
                      onEdit: (item) => _onAddAsset(investment: item),
                      onDelete: (id) =>
                          _onDeleteAsset(l10n.assetInvestments, id),
                    ),
                    GoldList(
                      gold: vm.filteredGold,
                      emptyMessage: filteredEmpty,
                      onRefresh: vm.refresh,
                      onEdit: (item) => _onAddAsset(gold: item),
                      onDelete: (id) => _onDeleteAsset(l10n.assetGold, id),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _onAddAsset,
        child: const Icon(Icons.add),
      ),
    );
  }

  void _onAddAsset({
    AssetSaving? saving,
    AssetInvestment? investment,
    AssetGold? gold,
  }) async {
    final l10n = context.l10n;
    // Adding from the button means adding to the tab being looked at, so the
    // sheet that used to ask which kind only stood between the two.
    final String type;

    if (saving != null) {
      type = l10n.assetSavings;
    } else if (investment != null) {
      type = l10n.assetInvestments;
    } else if (gold != null) {
      type = l10n.assetGold;
    } else {
      type = switch (_tabController.index) {
        1 => l10n.assetInvestments,
        2 => l10n.assetGold,
        _ => l10n.assetSavings,
      };
    }

    if (type == l10n.assetSavings) {
      final result = await showAppModal<AssetSaving>(
        context,
        builder: (_) => AddSavingDialog(
          saving: saving,
          onDelete: saving == null
              ? null
              : () => _onDeleteAsset(l10n.assetSavings, saving.id),
        ),
      );
      if (result != null && mounted) vm.upsertSaving(result);
    } else if (type == l10n.assetInvestments) {
      final result = await showAppModal<AssetInvestment>(
        context,
        builder: (_) => AddInvestmentDialog(
          investment: investment,
          logo: investment == null
              ? null
              : vm.cryptoAssetOf(investment.symbol)?.logo,
          usdRate: vm.usdRate,
          onDelete: investment == null
              ? null
              : () => _onDeleteAsset(l10n.assetInvestments, investment.id),
        ),
      );
      if (result != null && mounted) vm.upsertInvestment(result);
    } else if (type == l10n.assetGold) {
      final result = await showAppModal<AssetGold>(
        context,
        builder: (_) => AddGoldDialog(
          gold: gold,
          onDelete: gold == null
              ? null
              : () => _onDeleteAsset(l10n.assetGold, gold.id),
        ),
      );
      if (result != null && mounted) vm.upsertGold(result);
    }
  }

  void _onDeleteAsset(String type, String id) async {
    final l10n = context.l10n;
    final confirmed = await showAppConfirmDialog(
      context,
      title: l10n.delete,
      message: "${l10n.assetDeleteConfirm} ($type)",
      isDestructive: true,
    );

    if (confirmed) {
      if (type == l10n.assetSavings) {
        vm.deleteSaving(id);
      } else if (type == l10n.assetInvestments) {
        vm.deleteInvestment(id);
      } else if (type == l10n.assetGold) {
        vm.deleteGold(id);
      }
    }
  }
}
