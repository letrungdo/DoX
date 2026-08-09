import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/model/movie_model.dart';
import 'package:do_x/widgets/dialog/app_modal.dart';
import 'package:do_x/widgets/neu/neu_chip.dart';
import 'package:flutter/material.dart';

/// Result of the filter sheet: `null` means dismissed, a record with a `null`
/// category means "All" (clear the filter).
typedef MovieFilterResult = ({MovieCategory? category});

/// Country / genre picker opened from the movie browser. Only the primary
/// (Ophim) server exposes these lists, so it is shown for that server alone.
class MovieFilterSheet extends StatelessWidget {
  const MovieFilterSheet({
    super.key,
    required this.options,
    required this.selectedId,
  });

  final List<MovieCategory> options;
  final String? selectedId;

  static Future<MovieFilterResult?> show(
    BuildContext context, {
    required String title,
    required List<MovieCategory> options,
    required String? selectedId,
  }) {
    return showAppBottomSheet<MovieFilterResult>(
      context,
      title: title,
      builder: (context) =>
          MovieFilterSheet(options: options, selectedId: selectedId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        NeuChip(
          label: l10n.all,
          isSelected: selectedId == null,
          onTap: () => Navigator.pop(context, (category: null)),
        ),
        for (final option in options)
          NeuChip(
            label: option.name,
            isSelected: option.id == selectedId,
            onTap: () => Navigator.pop(context, (category: option)),
          ),
      ],
    );
  }
}
