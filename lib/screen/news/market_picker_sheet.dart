import 'package:do_x/constants/enum/market_code.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/extensions/text_style_extensions.dart';
import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/widgets/dialog/app_modal.dart';
import 'package:do_x/widgets/neu/neu_button.dart';
import 'package:flutter/material.dart';

/// Picks which markets the news page charts. Returns the new list — already in
/// display order — or `null` if the sheet was dismissed without saving.
///
/// The order is meaningful: markets already on the card keep their position,
/// and anything newly ticked is appended in catalogue order, so saving never
/// reshuffles rows the user was reading.
Future<List<MarketCode>?> showMarketPickerSheet(
  BuildContext context, {
  required List<MarketCode> selected,
}) {
  final l10n = AppLocalizations.of(context);
  return showAppBottomSheet<List<MarketCode>>(
    context,
    title: l10n.marketPicker,
    scrollable: false,
    useBottomSafeArea: false,
    padding: EdgeInsets.zero,
    builder: (_) => _MarketPickerBody(selected: selected),
  );
}

class _MarketPickerBody extends StatefulWidget {
  const _MarketPickerBody({required this.selected});

  final List<MarketCode> selected;

  @override
  State<_MarketPickerBody> createState() => _MarketPickerBodyState();
}

/// Tighter than the button's own default: these two sit side by side at the
/// foot of a list, where a full-height pill each would crowd the last rows.
const _actionPadding = EdgeInsets.symmetric(horizontal: 28, vertical: 10);

class _MarketPickerBodyState extends State<_MarketPickerBody> {
  late final _selected = widget.selected.toSet();

  void _toggle(MarketCode code, bool value) {
    setState(() => value ? _selected.add(code) : _selected.remove(code));
  }

  /// Ticks or unticks a whole slice of the catalogue. Passing every code makes
  /// it the sheet-wide toggle; passing one group's codes makes it that group's.
  void _toggleAll(Iterable<MarketCode> codes, bool value) {
    setState(
      () => value ? _selected.addAll(codes) : _selected.removeAll(codes),
    );
  }

  /// Kept-order save: the previous list first (minus whatever was unticked),
  /// then the new picks in catalogue order.
  void _save() {
    final result = [
      ...widget.selected.where(_selected.contains),
      ...MarketCode.values.where(
        (e) => _selected.contains(e) && !widget.selected.contains(e),
      ),
    ];
    Navigator.of(context).pop(result);
  }

  String _groupLabel(AppLocalizations l10n, MarketGroup group) {
    return switch (group) {
      MarketGroup.commodity => l10n.marketGroupCommodity,
      MarketGroup.crypto => l10n.marketGroupCrypto,
      MarketGroup.vnIndex => l10n.marketGroupVnIndex,
      MarketGroup.worldIndex => l10n.marketGroupWorldIndex,
      MarketGroup.usStock => l10n.marketGroupUsStock,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.only(bottom: 8),
            children: [
              _AllToggle(
                label: l10n.marketSelected(_selected.length),
                allSelected: _selected.length == MarketCode.values.length,
                onChanged: (v) => _toggleAll(MarketCode.values, v),
                l10n: l10n,
              ),
              for (final group in MarketGroup.values) ...[
                _GroupHeader(
                  label: _groupLabel(l10n, group),
                  selected: MarketCode.values
                      .where((e) => e.group == group)
                      .every(_selected.contains),
                  onChanged: (v) => _toggleAll(
                    MarketCode.values.where((e) => e.group == group),
                    v,
                  ),
                ),
                for (final code in MarketCode.values.where(
                  (e) => e.group == group,
                ))
                  CheckboxListTile(
                    value: _selected.contains(code),
                    onChanged: (v) => _toggle(code, v ?? false),
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    // Indented past the group's own checkbox, so a market reads
                    // as sitting under its heading.
                    contentPadding: const EdgeInsets.only(left: 28, right: 12),
                    title: Text(
                      code.name,
                      style: context.textTheme.primary.size15,
                    ),
                    subtitle: Text(
                      code.code,
                      style: context.textTheme.title.size13,
                    ),
                  ),
              ],
            ],
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + bottomInset),
          // Close lives in the sheet's own top-right corner, so the foot of the
          // list carries only the action that commits the picks.
          child: Center(
            child: NeuButton(
              accent: context.colors.info,
              padding: _actionPadding,
              onPressed: _selected.isEmpty ? null : _save,
              child: Text(l10n.save, textAlign: TextAlign.center),
            ),
          ),
        ),
      ],
    );
  }
}

/// The sheet's one bulk action: how many are ticked on the left, and the switch
/// for the whole catalogue on the right.
class _AllToggle extends StatelessWidget {
  const _AllToggle({
    required this.label,
    required this.allSelected,
    required this.onChanged,
    required this.l10n,
  });

  final String label;
  final bool allSelected;
  final ValueChanged<bool> onChanged;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final color = context.colors.info;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 12, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: context.textTheme.primary.size15.bold),
          ),
          TextButton(
            onPressed: () => onChanged(!allSelected),
            style: TextButton.styleFrom(
              foregroundColor: color,
              visualDensity: VisualDensity.compact,
            ),
            child: Text(
              allSelected ? l10n.unselectAll : l10n.selectAll,
              style: context.textTheme.secondary.size13.bold.textColor(color),
            ),
          ),
        ],
      ),
    );
  }
}

/// A group's label with its own checkbox in front of it, so the whole block is
/// ticked from the same column the individual rows are ticked in — the header
/// reads as the parent of the boxes under it rather than a separate control.
class _GroupHeader extends StatelessWidget {
  const _GroupHeader({
    required this.label,
    required this.selected,
    required this.onChanged,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!selected),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 20, 4),
        child: Row(
          children: [
            // Sized and offset to sit in the same column as the tiles' boxes,
            // which Material insets by 12 inside a dense ListTile.
            SizedBox(
              width: 40,
              child: Checkbox(
                value: selected,
                onChanged: (v) => onChanged(v ?? false),
                visualDensity: VisualDensity.compact,
              ),
            ),
            Expanded(
              child: Text(label, style: context.textTheme.title.size13.bold),
            ),
          ],
        ),
      ),
    );
  }
}
