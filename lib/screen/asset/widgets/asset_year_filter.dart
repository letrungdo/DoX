import 'package:do_x/constants/dimens.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/extensions/widget_extensions.dart';
import 'package:do_x/widgets/input/cute_segmented_button.dart';
import 'package:flutter/material.dart';

/// Narrows all three asset lists to one year, or to every year at once.
///
/// One row above the tabs rather than one per tab: the question ("how did 2025
/// go?") is the same whichever list is open, and a per-tab filter would answer
/// it three times over.
class AssetYearFilter extends StatelessWidget {
  const AssetYearFilter({
    super.key,
    required this.years,
    required this.selected,
    required this.onChanged,
  });

  final List<int> years;
  final int? selected;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    // A single year is the same list either way, so the row would only take up
    // space to say nothing.
    if (years.length < 2) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Dimens.pagePadding,
        Dimens.pagePadding,
        Dimens.pagePadding,
        0,
      ),
      child: CuteSegmentedButton<int?>(
        value: selected,
        onChanged: onChanged,
        segments: [
          ButtonSegment(value: null, label: Text(context.l10n.assetYearAll)),
          for (final year in years)
            ButtonSegment(value: year, label: Text('$year')),
        ],
      ),
    ).contentConstrainedBox();
  }
}
