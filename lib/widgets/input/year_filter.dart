import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/widgets/dialog/app_modal.dart';
import 'package:do_x/widgets/neu/neu_card.dart';
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
    final picked = await showAppOptionSheet<int>(
      context,
      title: l10n.selectYear,
      options: [if (includeAll) 0, ...years],
      selected: selectedYear,
      labelBuilder: (year) => _labelFor(l10n, year),
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
        NeuCard(
          radius: 20,
          depth: 0.5,
          onTap: () => _openSheet(context),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
      ],
    );
  }
}
