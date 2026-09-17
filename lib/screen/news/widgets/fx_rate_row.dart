import 'package:auto_size_text/auto_size_text.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/extensions/text_style_extensions.dart';
import 'package:do_x/widgets/neu/neu_card.dart';
import 'package:flutter/material.dart';

/// One rate on the news page: the currency pair on the left, the figure on the
/// right, and — for a pair that has more than one source behind it — the name
/// of the source quoting it plus a chevron that opens the rest.
///
/// Every row lines its figure up on the same right-hand edge. Two things used
/// to break that, and both are worth knowing before this layout is changed:
///
/// * The chevron's slot is held open even on a row that has no chevron.
///   Otherwise the expandable row's figure sat a chevron's width further left
///   than the plain row's.
/// * The caption takes the slack, rather than a `Spacer` taking it. A `Spacer`
///   beside a `Flexible` caption is two flex children of equal weight, so they
///   split the free space in half — and the half the caption did not need was
///   left stranded *after* the figure, pushing it in from the edge.
class FxRateRow extends StatelessWidget {
  const FxRateRow({
    super.key,
    required this.pair,
    required this.color,
    required this.softColor,
    required this.value,
    this.caption,
    this.onTap,
    this.isExpanded = false,
  });

  /// Kept in step with the spacer that holds its slot open on rows that have
  /// no chevron of their own.
  static const chevronSize = 18.0;

  final String pair;
  final Color color;
  final Color softColor;

  /// Null until the first value lands: a dash next to a spinning sync icon
  /// reads as "no data" rather than "still loading", so the slot stays blank.
  final String? value;

  /// Who is quoting [value], when that is not obvious from the pair.
  final String? caption;

  final VoidCallback? onTap;
  final bool isExpanded;

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;
    final caption = this.caption;

    return NeuCard(
      color: softColor,
      radius: 10,
      depth: 0.5,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      child: Row(
        spacing: 8,
        children: [
          Text(pair, style: textTheme.title.size13.medium.fit),
          Expanded(
            child: caption == null
                ? const SizedBox.shrink()
                : AutoSizeText(
                    caption,
                    maxLines: 1,
                    textAlign: TextAlign.end,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.secondary.size12.fit,
                  ),
          ),
          AutoSizeText(
            value ?? "",
            maxLines: 1,
            style: textTheme.primary.size16.bold.fit.textColor(color),
          ),
          SizedBox(
            width: chevronSize,
            child: onTap == null
                ? null
                : AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: Icon(
                      Icons.expand_more_rounded,
                      size: chevronSize,
                      color: context.colors.iconColor,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
