import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/model/movie_model.dart';
import 'package:do_x/widgets/neu/neu_chip.dart';
import 'package:flutter/material.dart';

/// Result of the filter sheet: `null` means dismissed, a record with a `null`
/// category means "All" (clear the filter).
typedef MovieFilterResult = ({MovieCategory? category});

/// Country / genre picker opened from the movie browser. Only the primary
/// (Ophim) server exposes these lists, so it is shown for that server alone.
class MovieFilterSheet extends StatelessWidget {
  const MovieFilterSheet({super.key, required this.title, required this.options, required this.selectedId});

  final String title;
  final List<MovieCategory> options;
  final String? selectedId;

  static Future<MovieFilterResult?> show(
    BuildContext context, {
    required String title,
    required List<MovieCategory> options,
    required String? selectedId,
  }) {
    return showModalBottomSheet<MovieFilterResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MovieFilterSheet(title: title, options: options, selectedId: selectedId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Divider(height: 20),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 16 + MediaQuery.paddingOf(context).bottom),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    NeuChip(label: l10n.all, isSelected: selectedId == null, onTap: () => Navigator.pop(context, (category: null))),
                    for (final option in options)
                      NeuChip(
                        label: option.name,
                        isSelected: option.id == selectedId,
                        onTap: () => Navigator.pop(context, (category: option)),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
