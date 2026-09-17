import 'package:auto_route/auto_route.dart';
import 'package:do_x/constants/dimens.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/extensions/widget_extensions.dart';
import 'package:do_x/screen/asset/widgets/asset_summary_card.dart';
import 'package:do_x/screen/asset/widgets/asset_summary_stats.dart';
import 'package:do_x/screen/core/screen_state.dart';
import 'package:do_x/view_model/asset_view_model.dart';
import 'package:do_x/widgets/app_bar/app_bar_base.dart';
import 'package:do_x/widgets/app_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

@RoutePage()
class AssetSummaryScreen extends StatefulScreen implements AutoRouteWrapper {
  const AssetSummaryScreen({super.key, required this.assetVm});

  final AssetViewModel assetVm;

  @override
  State<AssetSummaryScreen> createState() => _AssetSummaryScreenState();

  @override
  Widget wrappedRoute(BuildContext context) {
    return ChangeNotifierProvider.value(value: assetVm, child: this);
  }
}

class _AssetSummaryScreenState
    extends ScreenState<AssetSummaryScreen, AssetViewModel> {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AppScaffold(
      appBar: DoAppBar(title: l10n.assetSummary),
      body: Consumer<AssetViewModel>(
        builder: (context, vm, child) {
          final summary = vm.summary;
          if (summary == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return RefreshIndicator(
            onRefresh: vm.refresh,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Padding(
                padding: Dimens.screenPadding,
                child: Column(
                  spacing: 16,
                  children: [
                    AssetSummaryCard(summary: summary),
                    AssetReturnCard(summary: summary),
                    AssetAllocationCard(summary: summary),
                    AssetStatsCard(summary: summary),
                    if (summary.best != null)
                      AssetPerformanceCard(summary: summary),
                  ],
                ),
              ).contentConstrainedBox(),
            ),
          );
        },
      ),
    );
  }
}
