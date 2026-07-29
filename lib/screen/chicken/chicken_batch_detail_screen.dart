import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:collection/collection.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/extensions/number_extensions.dart';
import 'package:do_x/extensions/widget_extensions.dart';
import 'package:do_x/gen/assets.gen.dart';
import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/model/chicken/batch_sale.dart';
import 'package:do_x/model/chicken/chicken_batch.dart';
import 'package:do_x/model/chicken/expense.dart';
import 'package:do_x/model/chicken/vaccination.dart';
import 'package:do_x/repository/chicken_repository.dart';
import 'package:do_x/screen/core/screen_state.dart';
import 'package:do_x/utils/chicken_date.dart';
import 'package:do_x/utils/lunar_calendar.dart';
import 'package:do_x/view_model/chicken_view_model.dart';
import 'package:do_x/widgets/app_bar/app_bar_base.dart';
import 'package:do_x/widgets/app_bar/app_bar_sync_icon.dart';
import 'package:do_x/widgets/chicken_change_badge.dart';
import 'package:do_x/widgets/chicken_stale_banner.dart';
import 'package:do_x/widgets/cute_dialog.dart';
import 'package:do_x/widgets/dialog/low_price_warning_dialog.dart';
import 'package:do_x/widgets/expense_dialog.dart';
import 'package:do_x/widgets/input/cute_text_field.dart';
import 'package:do_x/widgets/input/cute_money_field.dart';
import 'package:do_x/widgets/input/lunar_date_field.dart';
import 'package:do_x/widgets/input/note_field.dart';
import 'package:do_x/widgets/neu/neu_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

@RoutePage()
class ChickenBatchDetailScreen extends StatefulScreen
    implements AutoRouteWrapper {
  final String batchId;
  const ChickenBatchDetailScreen({super.key, required this.batchId});

  @override
  State<ChickenBatchDetailScreen> createState() =>
      _ChickenBatchDetailScreenState();

  @override
  Widget wrappedRoute(BuildContext context) => this;
}

class _ChickenBatchDetailScreenState
    extends ScreenState<ChickenBatchDetailScreen, ChickenViewModel> {
  String _fmt(DateTime date) =>
      ChickenDate.format(date, useLunar: vm.useLunarCalendar);

  /// Runs a write and reports a failure to the user. The view model has already
  /// undone the change locally by the time this returns false, so the screen
  /// only has to say so.
  Future<bool> _runWrite(Future<void> write) async {
    final l10n = AppLocalizations.of(context);
    try {
      await write;
      return true;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.saveFailed(error.toString()))),
        );
      }
      return false;
    }
  }

  /// Refreshes just the year this batch lives in rather than every batch ever
  /// recorded. Falls back to all years when the batch is not in memory yet,
  /// which is the case when this screen is opened straight from a notification.
  void _refresh() {
    final batch = vm.batches.firstWhereOrNull((e) => e.id == widget.batchId);
    vm.ensureLoaded(
      {ChickenSection.batches},
      year: batch == null
          ? null
          : vm.displayYear(batch.actualHatchDate ?? batch.expectedHatchDate),
    );
  }

  @override
  void initData() {
    super.initData();
    _refresh();
  }

  @override
  void onResume() {
    super.onResume();
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: DoAppBar(
        title: l10n.batchDetailTitle,
        titleSuffix: AppBarSyncIcon<ChickenViewModel>(
          selector: (vm) => vm.isFetching,
        ),
      ),
      body: Consumer<ChickenViewModel>(
        builder: (context, vm, child) {
          final batch = vm.batches.firstWhereOrNull(
            (e) => e.id == widget.batchId,
          );
          if (batch == null) {
            return Center(child: Text(l10n.batchNotFound));
          }

          return Column(
            children: [
              const ChickenStaleBanner(sections: {ChickenSection.batches}),
              Expanded(child: _buildBody(batch)),
            ],
          );
        },
      ).webConstrainedBox(),
    );
  }

  Widget _buildBody(ChickenBatch batch) {
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoSection(batch),
          const SizedBox(height: 16),
          _buildSaleSection(batch),
          const SizedBox(height: 16),
          _buildExpenseSection(batch),
          const SizedBox(height: 16),
          _buildVaccinationSection(batch),
          const SizedBox(height: 28),
          Center(
            child: TextButton.icon(
              onPressed: () => _confirmDelete(batch),
              icon: const Icon(Icons.delete_outline, size: 18),
              label: Text(l10n.deleteThisBatch),
              style: TextButton.styleFrom(
                foregroundColor: context.colors.danger,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// A rounded card holding one section, with a small icon + title header and
  /// an optional trailing widget (a total, a count or an add button).
  Widget _buildSectionCard({
    required Widget icon,
    required String title,
    Widget? trailing,
    Color? color,
    required List<Widget> children,
  }) {
    return NeuCard(
      color: color,
      radius: 16,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              icon,
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: context.theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  /// Small square holding a section's svg icon, lifted off the card.
  Widget _buildIconBadge(SvgGenImage asset, {double size = 22}) {
    return Container(
      padding: const EdgeInsets.all(6),
      // Opaque so the badge keeps the same look on the tinted section cards.
      decoration: context.neu.raised(radius: 10, depth: 0.45),
      child: asset.svg(width: size, height: size),
    );
  }

  /// Tinted, rounded edit affordance. Used everywhere a row or card opens an
  /// edit dialog, so the action reads the same way in every section.
  Widget _buildEditButton(VoidCallback onTap, {double size = 18}) {
    final color = context.theme.colorScheme.primary;
    return Material(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Icon(Icons.edit_outlined, size: size, color: color),
        ),
      ),
    );
  }

  /// One of the three headline numbers (initial / sold / remaining).
  ///
  /// Nested inside a raised card, so it gets a shallow lift of its own rather
  /// than a deep one that would compete with the card it sits on.
  Widget _buildStatTile(String value, String label, {Color? valueColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: context.neu.raised(radius: 12, depth: 0.5),
      child: Column(
        children: [
          Text(
            value,
            style: context.theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: context.theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// Colored pill summarising the batch state (age, or days left to hatch).
  Widget _buildStatusChip(ChickenBatch batch) {
    final l10n = AppLocalizations.of(context);
    final hatched = batch.ageInDays >= 0;
    final color = hatched
        ? context.theme.colorScheme.primary
        : context.colors.warning;
    final text = hatched
        ? ChickenDate.formatAge(l10n, batch.ageInDays)
        : l10n.notHatchedYet(-batch.ageInDays);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: context.theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hatched ? Icons.cake_outlined : Icons.hourglass_bottom,
            size: 13,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// A label/value line prefixed with a muted icon.
  Widget _buildIconInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: context.theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: context.theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildInfoSection(ChickenBatch batch) {
    final l10n = AppLocalizations.of(context);
    final hatched = batch.ageInDays >= 0;
    final hasSales = batch.sales.isNotEmpty;
    final soldOut = hasSales && batch.remainingQuantity <= 0;
    return NeuCard(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildIconBadge(
                  hatched ? Assets.images.chickCute : Assets.images.eggCute,
                  size: 30,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        batch.name,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: context.theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Badge next to the age pill, on the same line.
                      Row(
                        children: [
                          _buildStatusChip(batch),
                          ChickenChangeBadge(vm.changeBadgeOf(batch.id)),
                        ],
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _buildEditButton(
                    () => _showEditInfoDialog(batch),
                    size: 20,
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 6, top: 14),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatTile(
                          "${batch.quantity}",
                          l10n.initialQuantity,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatTile(
                          "${batch.soldQuantity}",
                          l10n.soldLabel,
                          // Same green as the "sold" number in the sale summary.
                          valueColor: batch.soldQuantity > 0
                              ? context.colors.success
                              : context.theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatTile(
                          "${batch.remainingQuantity}",
                          l10n.remainingLabel,
                          // Same amber as the "remaining" number in the sale
                          // summary, so the two agree at a glance.
                          valueColor: batch.remainingQuantity > 0
                              ? context.colors.warning
                              : context.theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  if (hasSales && batch.quantity > 0) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (batch.soldQuantity / batch.quantity).clamp(
                          0.0,
                          1.0,
                        ),
                        minHeight: 6,
                        backgroundColor:
                            context.theme.colorScheme.surfaceContainerHighest,
                        color: soldOut
                            ? context.colors.success
                            : context.theme.colorScheme.primary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  _buildIconInfoRow(
                    Icons.egg_outlined,
                    l10n.incubationDay,
                    _fmt(batch.incubationDate),
                  ),
                  if (batch.actualHatchDate == null)
                    _buildIconInfoRow(
                      Icons.event_outlined,
                      l10n.expectedHatch,
                      _fmt(batch.expectedHatchDate),
                    )
                  else
                    _buildIconInfoRow(
                      Icons.event_available_outlined,
                      l10n.actualHatchDateLabel,
                      _fmt(batch.actualHatchDate!),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVaccinationSection(ChickenBatch batch) {
    final l10n = AppLocalizations.of(context);
    final done = batch.vaccinations.where((v) => v.isCompleted).length;
    final total = batch.vaccinations.length;
    return _buildSectionCard(
      icon: _buildIconBadge(Assets.images.medicineCute),
      title: l10n.vaccinationSchedule,
      trailing: total == 0
          ? null
          : Text(
              "$done/$total",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: done == total
                    ? context.colors.success
                    : context.theme.colorScheme.onSurfaceVariant,
              ),
            ),
      children: batch.vaccinations
          .map((v) => _buildVaccinationRow(batch, v))
          .toList(),
    );
  }

  Widget _buildVaccinationRow(ChickenBatch batch, Vaccination v) {
    final overdue =
        !v.isCompleted &&
        LunarCalendar.lunarDateTimeToSolar(
          v.scheduledDate,
        ).isBefore(DateTime.now());
    final accent = v.isCompleted
        ? context.colors.success
        : overdue
        ? context.colors.danger
        : context.theme.colorScheme.onSurfaceVariant;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        vm.setCurrentContext(context);
        unawaited(_runWrite(vm.toggleVaccination(batch.id, v.id)));
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
        child: Row(
          children: [
            Icon(
              v.isCompleted
                  ? Icons.check_circle
                  : overdue
                  ? Icons.error_outline
                  : Icons.radio_button_unchecked,
              size: 20,
              color: accent,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                v.title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: v.isCompleted
                      ? context.theme.colorScheme.onSurfaceVariant
                      : null,
                  decoration: v.isCompleted ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _fmt(v.scheduledDate),
              style: TextStyle(
                fontSize: 12,
                fontWeight: overdue ? FontWeight.bold : FontWeight.normal,
                color: overdue
                    ? context.colors.danger
                    : context.theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpenseSection(ChickenBatch batch) {
    final l10n = AppLocalizations.of(context);
    return _buildSectionCard(
      icon: _buildIconBadge(Assets.images.feedCute),
      title: l10n.expensesTitle,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "${batch.totalExpenses.toCurrency()}đ",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: context.colors.money,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            visualDensity: VisualDensity.compact,
            onPressed: () => _showExpenseDialog(batch),
          ),
        ],
      ),
      children: [
        if (batch.expenses.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              l10n.noExpensesYet,
              style: TextStyle(
                color: context.theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ...batch.expenses.map(
          (e) => InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => _showExpenseDialog(batch, expense: e),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 2),
              child: Row(
                children: [
                  _getExpenseSvg(e.type),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            ChickenChangeBadge(
                              vm.changeBadgeOf(e.id),
                              compact: true,
                              leading: true,
                            ),
                            Flexible(
                              child: Text(
                                _getExpenseLabel(e.type),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "${_fmt(e.date)}${e.note != null ? ' · ${e.note}' : ''}",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: context.theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "${e.amount.toCurrency()}đ",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: context.colors.money,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSaleSection(ChickenBatch batch) {
    final l10n = AppLocalizations.of(context);
    final hasSold = batch.sales.isNotEmpty;
    final soldOut = hasSold && batch.remainingQuantity <= 0;

    // Theme-aware tint: green once the batch is sold out, amber while there are
    // still chickens left to sell.
    final cardColor = soldOut
        ? context.colors.successSoft
        : context.colors.warningSoft;

    return _buildSectionCard(
      color: cardColor,
      icon: _buildIconBadge(Assets.images.coinCute),
      title: l10n.saleAndProfit,
      trailing: hasSold
          ? Text(
              l10n.saleCount(batch.sales.length),
              style: TextStyle(
                fontSize: 12,
                color: context.theme.colorScheme.onSurfaceVariant,
              ),
            )
          : null,
      children: [
        if (!hasSold) ...[
          Text(
            l10n.notSoldHint,
            style: TextStyle(color: context.theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          _buildSummaryBox([
            _buildRowInfo(
              l10n.suggestedPrice,
              l10n.pricePerChicken(
                "${vm.suggestPrice(batch.ageInDays).toCurrency()}đ",
              ),
              color: context.colors.money,
              isBold: true,
            ),
          ]),
        ] else ...[
          ...batch.sales.map((sale) => _buildSaleRow(batch, sale)),
          const SizedBox(height: 4),
          _buildSummaryBox([
            _buildRowInfo(
              l10n.soldLabel,
              l10n.soldAndRemaining(
                batch.soldQuantity,
                batch.remainingQuantity,
              ),
              // Sold count in green, what is left in amber: the two numbers
              // mean opposite things and shouldn't blend together.
              highlightNumbers: [
                context.colors.success,
                batch.remainingQuantity > 0
                    ? context.colors.warning
                    : context.theme.colorScheme.onSurfaceVariant,
              ],
            ),
            _buildRowInfo(
              l10n.totalRevenueLabel,
              "${batch.totalSaleAmount.toCurrency()}đ",
            ),
            // Fighting and meat sales are listed apart: lumping them together
            // hid the meat revenue behind a "fighting rooster" label.
            if (batch.totalFightingSales > 0)
              _buildRowInfo(
                l10n.cockRevenue,
                "${batch.totalFightingSales.toCurrency()}đ",
              ),
            if (batch.totalMeatSales > 0)
              _buildRowInfo(
                l10n.meatRevenue,
                "${batch.totalMeatSales.toCurrency()}đ",
              ),
            _buildRowInfo(
              l10n.totalExpensesLabel,
              "-${batch.totalExpenses.toCurrency()}đ",
            ),
            const Divider(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.profitUpper,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: context.theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  "${batch.profit.toCurrency()}đ",
                  style: context.theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: batch.profit >= 0
                        ? context.colors.money
                        : context.colors.danger,
                  ),
                ),
              ],
            ),
          ]),
        ],
        // Sold out: nothing left to sell, so hide the record button.
        if (!soldOut) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showSaleDialog(batch),
              icon: const Icon(Icons.add, size: 18),
              label: Text(l10n.recordNewSale),
            ),
          ),
        ],
      ],
    );
  }

  /// Rounded panel used for the money summary inside a tinted section card.
  Widget _buildSummaryBox(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      // Opaque base fill, so the section's tint can't bleed through and dull
      // the numbers on it.
      decoration: context.neu.raised(radius: 12, depth: 0.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildSaleRow(ChickenBatch batch, BatchSale sale) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showSaleDialog(batch, sale: sale),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          decoration: BoxDecoration(
            color: context.theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            // Outline + soft shadow so each sale round reads as its own
            // tappable card on top of the tinted section.
            border: Border.all(
              color: context.colors.money.withValues(alpha: 0.35),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: context.theme.colorScheme.shadow.withValues(alpha: 0.07),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        ChickenChangeBadge(
                          vm.changeBadgeOf(sale.id),
                          compact: true,
                          leading: true,
                        ),
                        Flexible(
                          child: Text.rich(
                            TextSpan(
                              children: [
                                if (sale.quantity > 0)
                                  ..._highlightNumberSpans(
                                    l10n.chickenQuantity(sale.quantity),
                                    [context.theme.colorScheme.primary],
                                  )
                                else
                                  TextSpan(text: l10n.chickenSale),
                                if (sale.note != null)
                                  TextSpan(text: " - ${sale.note}"),
                                _buildSaleAgeSpan(
                                  l10n.statusDaysOld(
                                    batch.ageInDaysAt(sale.date),
                                  ),
                                  batch.ageInDaysAt(sale.date),
                                ),
                              ],
                            ),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: _fmt(sale.date),
                            style: TextStyle(
                              color: context.theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          if (sale.quantity > 0) ...[
                            TextSpan(
                              text: " · ",
                              style: TextStyle(
                                color:
                                    context.theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            TextSpan(
                              text: l10n.pricePerChicken(
                                "${(sale.amount / sale.quantity).round().toCurrency()}đ",
                              ),
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: context.colors.money,
                              ),
                            ),
                          ],
                        ],
                      ),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                "${sale.amount.toCurrency()}đ",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: context.colors.money,
                ),
              ),
              const SizedBox(width: 8),
              // Edit affordance: same target as tapping the row itself.
              _buildEditButton(() => _showSaleDialog(batch, sale: sale)),
            ],
          ),
        ),
      ),
    );
  }

  TextSpan _buildSaleAgeSpan(String ageLabel, int ageInDays) {
    final ageText = ageInDays.toString();
    final ageTextIndex = ageLabel.indexOf(ageText);

    if (ageTextIndex < 0) {
      return TextSpan(
        text: " ($ageLabel)",
        style: const TextStyle(fontWeight: FontWeight.normal),
      );
    }

    return TextSpan(
      style: const TextStyle(fontWeight: FontWeight.normal),
      children: [
        TextSpan(text: " (${ageLabel.substring(0, ageTextIndex)}"),
        TextSpan(
          text: ageText,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: ageInDays < 0
                ? context.colors.danger
                : context.theme.colorScheme.primary,
          ),
        ),
        TextSpan(text: "${ageLabel.substring(ageTextIndex + ageText.length)})"),
      ],
    );
  }

  void _confirmDeleteSale(ChickenBatch batch, BatchSale sale) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => CuteDialog(
        icon: Assets.images.coinCute,
        title: l10n.deleteSaleRound,
        accent: context.colors.danger,
        confirmText: l10n.delete,
        isDestructive: true,
        onConfirm: () {
          unawaited(_runWrite(vm.deleteBatchSale(batch.id, sale.id)));
          Navigator.pop(context);
        },
        children: [
          Text(
            l10n.confirmDeleteSaleRound(
              _fmt(sale.date),
              "${sale.amount.toCurrency()}đ",
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _confirmDeleteExpense(ChickenBatch batch, Expense expense) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => CuteDialog(
        icon: Assets.images.feedCute,
        title: l10n.deleteExpense,
        accent: context.colors.danger,
        confirmText: l10n.delete,
        isDestructive: true,
        onConfirm: () {
          unawaited(_runWrite(vm.deleteExpense(batch.id, expense.id)));
          Navigator.pop(context);
        },
        children: [
          Text(
            l10n.confirmDeleteExpense(
              _getExpenseLabel(expense.type),
              "${expense.amount.toCurrency()}đ",
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Splits a localized string so its digit groups stand out from the wording
  /// around them — "12 con, còn 8 con" reads as counts first, words second.
  ///
  /// [colors] is applied per number in order; the last entry repeats once the
  /// numbers outnumber it.
  List<InlineSpan> _highlightNumberSpans(String text, List<Color> colors) {
    final spans = <InlineSpan>[];
    var last = 0;
    var index = 0;
    for (final match in RegExp(r'\d+').allMatches(text)) {
      if (match.start > last) {
        spans.add(TextSpan(text: text.substring(last, match.start)));
      }
      spans.add(
        TextSpan(
          text: match[0],
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: colors[index.clamp(0, colors.length - 1)],
          ),
        ),
      );
      last = match.end;
      index++;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
    return spans;
  }

  Widget _buildRowInfo(
    String label,
    String value, {
    Color? color,
    bool isBold = false,
    List<Color>? highlightNumbers,
  }) {
    final valueStyle = TextStyle(
      color: color,
      fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: context.theme.colorScheme.onSurfaceVariant),
          ),
          if (highlightNumbers != null)
            Text.rich(
              TextSpan(
                children: _highlightNumberSpans(value, highlightNumbers),
              ),
              style: valueStyle,
            )
          else
            Text(value, style: valueStyle),
        ],
      ),
    );
  }

  void _showExpenseDialog(ChickenBatch batch, {Expense? expense}) {
    final l10n = AppLocalizations.of(context);
    showExpenseDialog(
      context,
      expense: expense,
      useLunar: vm.useLunarCalendar,
      addTitle: l10n.addExpense,
      editTitle: l10n.editExpense,
      noteSuggestions: vm.expenseNoteSuggestions,
      onDelete: () async => _confirmDeleteExpense(batch, expense!),
      onSubmit: (updatedExpense) => _runWrite(
        expense != null
            ? vm.updateExpense(batch.id, updatedExpense)
            : vm.addExpense(batch.id, updatedExpense),
      ),
    );
  }

  void _showSaleDialog(ChickenBatch batch, {BatchSale? sale}) {
    final l10n = AppLocalizations.of(context);
    final isEditing = sale != null;
    final quantity =
        sale?.quantity ??
        (batch.remainingQuantity > 0
            ? batch.remainingQuantity
            : batch.quantity);
    // Available to sell = remaining, plus this sale's own quantity when editing
    // (it is already counted in the remaining figure).
    final maxQuantity = batch.remainingQuantity + (sale?.quantity ?? 0);

    // For a new sale, leave the price fields empty so the user types them in;
    // only pre-fill when editing an existing record.
    final unitPriceController = TextEditingController(
      text: isEditing && sale.quantity > 0
          ? (sale.amount / sale.quantity).toCurrency()
          : '',
    );
    final qtyController = TextEditingController(text: quantity.toString());
    final totalAmountController = TextEditingController(
      text: isEditing ? sale.amount.toCurrency() : '',
    );
    final noteController = TextEditingController(text: sale?.note ?? '');
    DateTime saleDate =
        sale?.date ?? LunarCalendar.solarToLunarDateTime(DateTime.now());
    String? qtyError;
    String? amountError;

    void updateTotal() {
      final unitPrice = unitPriceController.text.toMoney() ?? 0;
      final qty = int.tryParse(qtyController.text) ?? 0;
      totalAmountController.text = (unitPrice * qty).toCurrency();
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => CuteDialog(
          icon: Assets.images.coinCute,
          title: isEditing ? l10n.editSaleRound : l10n.recordSale,
          accent: context.colors.success,
          confirmText: isEditing ? l10n.update : l10n.confirm,
          destructiveText: isEditing ? l10n.delete : null,
          onDestructive: isEditing
              ? () {
                  Navigator.pop(context);
                  _confirmDeleteSale(batch, sale);
                }
              : null,
          onConfirm: () async {
            final amount = totalAmountController.text.toMoney() ?? 0;
            final qty = int.tryParse(qtyController.text) ?? 0;
            if (qty <= 0 || qty > maxQuantity || amount <= 0) {
              setState(() {
                qtyError = qty <= 0
                    ? l10n.errorEnterQuantity
                    : qty > maxQuantity
                    ? l10n.errorQuantityExceedsRemaining(maxQuantity)
                    : null;
                amountError = amount <= 0 ? l10n.errorEnterAmount : null;
              });
              return;
            }
            // A price per chicken below the threshold is most likely a missing
            // zero, so ask before saving it.
            final unitPrice = (amount / qty).round();
            if (unitPrice < kSuspiciousPriceThreshold) {
              final saveAnyway = await confirmSuspiciousPrice(
                context,
                unitPrice,
              );
              if (!saveAnyway || !context.mounted) return;
            }
            final newSale = BatchSale(
              id: sale?.id ?? const Uuid().v4(),
              date: saleDate,
              quantity: qty,
              amount: amount,
              note: noteController.text.isEmpty ? null : noteController.text,
            );
            unawaited(
              _runWrite(
                isEditing
                    ? vm.updateBatchSale(batch.id, newSale)
                    : vm.addBatchSale(batch.id, newSale),
              ),
            );
            Navigator.pop(context);
          },
          children: [
            Row(
              children: [
                Expanded(
                  child: CuteTextField(
                    controller: qtyController,
                    label: l10n.quantityLabel,
                    autofocus: !isEditing,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      NoLeadingZeroInputFormatter(),
                    ],
                    errorText: qtyError,
                    onChanged: (_) => setState(() {
                      qtyError = null;
                      updateTotal();
                    }),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CuteMoneyField(
                    controller: unitPriceController,
                    label: l10n.pricePerUnit,
                    presetSuggestions: const [
                      20000,
                      25000,
                      30000,
                      35000,
                      40000,
                      45000,
                      50000,
                    ],
                    onChanged: (_) => setState(() {
                      amountError = null;
                      updateTotal();
                    }),
                  ),
                ),
              ],
            ),
            CuteMoneyField(
              controller: totalAmountController,
              label: l10n.totalAutoCalculated,
              errorText: amountError,
              onChanged: (_) {
                if (amountError != null) setState(() => amountError = null);
              },
            ),
            NoteField(
              controller: noteController,
              label: l10n.saleNoteHint,
              suggestions: vm.batchSaleNoteSuggestions,
            ),
            LunarDateField(
              label: l10n.saleDate,
              value: saleDate,
              useLunar: vm.useLunarCalendar,
              onChanged: (d) => setState(() => saleDate = d),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(ChickenBatch batch) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => CuteDialog(
        icon: Assets.images.henCute,
        title: l10n.deleteBatch,
        accent: context.colors.danger,
        confirmText: l10n.delete,
        isDestructive: true,
        onConfirm: () {
          unawaited(_runWrite(vm.deleteBatch(batch.id)));
          Navigator.pop(context);
          context.router.back();
        },
        children: [
          Text(
            l10n.confirmDeleteBatch(batch.name),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showEditInfoDialog(ChickenBatch batch) {
    final l10n = AppLocalizations.of(context);
    final nameController = TextEditingController(text: batch.name);
    final quantityController = TextEditingController(
      text: batch.quantity.toString(),
    );
    DateTime incubationDate = batch.incubationDate;
    DateTime? actualHatchDate = batch.actualHatchDate;
    String? nameError;
    String? qtyError;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => CuteDialog(
          icon: Assets.images.chickCute,
          title: l10n.editBatchInfo,
          confirmText: l10n.save,
          onConfirm: () {
            final name = nameController.text.trim();
            final qty = int.tryParse(quantityController.text);
            if (name.isEmpty || qty == null || qty < 0) {
              setState(() {
                nameError = name.isEmpty ? l10n.errorEnterBatchName : null;
                qtyError = (qty == null || qty < 0)
                    ? l10n.errorEnterQuantity
                    : null;
              });
              return;
            }
            unawaited(
              _runWrite(
                vm.updateBatch(
                  batch.copyWith(
                    name: name,
                    quantity: qty,
                    incubationDate: incubationDate,
                    actualHatchDate: actualHatchDate,
                  ),
                ),
              ),
            );
            Navigator.pop(context);
          },
          children: [
            CuteTextField(
              controller: nameController,
              label: l10n.batchName,
              errorText: nameError,
              onChanged: (_) {
                if (nameError != null) setState(() => nameError = null);
              },
            ),
            CuteTextField(
              controller: quantityController,
              label: l10n.initialQuantity,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                NoLeadingZeroInputFormatter(),
              ],
              errorText: qtyError,
              onChanged: (_) {
                if (qtyError != null) setState(() => qtyError = null);
              },
            ),
            LunarDateField(
              label: l10n.incubationDate,
              value: incubationDate,
              useLunar: vm.useLunarCalendar,
              onChanged: (d) => setState(() => incubationDate = d),
            ),
            LunarDateField(
              label: l10n.actualHatchDateLabel,
              value: actualHatchDate,
              useLunar: vm.useLunarCalendar,
              onChanged: (d) => setState(() => actualHatchDate = d),
            ),
          ],
        ),
      ),
    );
  }

  String _getExpenseLabel(ExpenseType type) {
    final l10n = AppLocalizations.of(context);
    return switch (type) {
      ExpenseType.feed => l10n.expenseFeed,
      ExpenseType.medicine => l10n.expenseMedicine,
      ExpenseType.electricity => l10n.expenseElectricity,
      ExpenseType.water => l10n.expenseWater,
      ExpenseType.other => l10n.expenseOther,
    };
  }

  Widget _getExpenseSvg(ExpenseType type) {
    final asset = switch (type) {
      ExpenseType.feed => Assets.images.feedCute,
      ExpenseType.medicine => Assets.images.medicineCute,
      ExpenseType.electricity => Assets.images.lampCute,
      ExpenseType.water => Assets.images.waterCute,
      ExpenseType.other => Assets.images.starCute,
    };
    return asset.svg(width: 30, height: 30);
  }
}
