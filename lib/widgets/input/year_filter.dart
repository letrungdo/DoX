import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// Year filter: a label plus a tappable pill that opens a bottom sheet to pick
/// a year. Pass [includeAll] to add an "All" option represented by year `0`.
class YearFilter extends StatelessWidget {
  final int selectedYear;
  final List<int> years;
  final ValueChanged<int> onChanged;
  final bool includeAll;

  const YearFilter({
    super.key,
    required this.selectedYear,
    required this.years,
    required this.onChanged,
    this.includeAll = false,
  });

  String _labelFor(AppLocalizations l10n, int year) =>
      year == 0 ? l10n.all : "$year";

  Future<void> _openSheet(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final options = [if (includeAll) 0, ...years];

    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: context.theme.scaffoldBackgroundColor,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Text(
                  l10n.selectYear,
                  textAlign: TextAlign.center,
                  style: context.theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: options.map((year) {
                    final selected = year == selectedYear;
                    return ListTile(
                      title: Text(_labelFor(l10n, year)),
                      trailing: selected
                          ? Icon(
                              Icons.check,
                              color: context.theme.colorScheme.primary,
                            )
                          : null,
                      selected: selected,
                      onTap: () => Navigator.of(sheetContext).pop(year),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (picked != null && picked != selectedYear) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.filter_alt_outlined, size: 20),
        const SizedBox(width: 4),
        Text(
          l10n.yearLabel,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 8),
        InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _openSheet(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              border: Border.all(
                color: context.theme.colorScheme.outlineVariant,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _labelFor(l10n, selectedYear),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.keyboard_arrow_down,
                  size: 20,
                  color: context.theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
