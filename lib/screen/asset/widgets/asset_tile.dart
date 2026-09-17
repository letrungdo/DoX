import 'package:auto_size_text/auto_size_text.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/extensions/text_style_extensions.dart';
import 'package:do_x/widgets/chicken_list_tile_card.dart';
import 'package:flutter/material.dart';

/// The card every asset row is built on.
///
/// [ListTile]'s default 16px side padding sat on top of the list's own page
/// padding and pushed every amount a further 16px in from the edge; zero left
/// the content touching the card's rounded corners. [sidePadding] is the
/// middle: enough to breathe, little enough that the figures still read as a
/// column down the right-hand side of the page.
class AssetTileCard extends StatelessWidget {
  /// The gap between the card's edge and its contents, on both sides.
  static const sidePadding = 10.0;

  const AssetTileCard({
    super.key,
    required this.leading,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.onLongPress,
  });

  final Widget leading;
  final Widget title;
  final Widget subtitle;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return ChickenListTileCard(
      onTap: onTap,
      onLongPress: onLongPress,
      contentPadding: const EdgeInsets.symmetric(horizontal: sidePadding),
      leading: leading,
      title: title,
      subtitle: subtitle,
    );
  }
}

/// A round badge in the tile's leading slot.
class AssetTileBadge extends StatelessWidget {
  const AssetTileBadge({super.key, required this.color, required this.child});

  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: child,
    );
  }
}

/// The tile's headline: what it is on the left, what it is worth on the right.
class AssetTileHeader extends StatelessWidget {
  const AssetTileHeader({super.key, required this.name, required this.value});

  final String name;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;

    return Row(
      children: [
        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.primary.bold,
          ),
        ),
        const SizedBox(width: 8),
        // Expanded, not Flexible: a Flexible shrink-wraps the figure, and text
        // aligned to the end of a box that is already the width of the text
        // stops short of the tile's edge — which is the line the detail row
        // below it lands on.
        Expanded(
          child: AutoSizeText(
            value,
            maxLines: 1,
            minFontSize: 11,
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            style: textTheme.primary.bold,
          ),
        ),
      ],
    );
  }
}

/// A detail line: facts on the left, the figure they add up to on the right.
///
/// The two sides are given fixed shares of the width rather than letting the
/// left one take whatever it wants, which is what left every tile's columns
/// landing in a different place.
class AssetTileRow extends StatelessWidget {
  const AssetTileRow({
    super.key,
    required this.left,
    required this.right,
    required this.group,
    this.rightColor,
  });

  final String left;
  final String right;
  final AutoSizeGroup group;
  final Color? rightColor;

  @override
  Widget build(BuildContext context) {
    final style = context.textTheme.secondary.size12;

    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: AutoSizeText(
              left,
              group: group,
              maxLines: 1,
              minFontSize: 8,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 4,
            child: AutoSizeText(
              right,
              group: group,
              maxLines: 1,
              minFontSize: 8,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: rightColor != null ? style.textColor(rightColor!) : style,
            ),
          ),
        ],
      ),
    );
  }
}

/// A full-width note under the detail row: the estimate, the maturity date, the
/// đồng value of a dollar price. Sized on its own rather than in the row's
/// [AutoSizeGroup] — being the longest line, it would otherwise drag the whole
/// tile down to its own scale.
class AssetTileNote extends StatelessWidget {
  const AssetTileNote({super.key, required this.text, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final style = context.textTheme.secondary.size11;

    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: AutoSizeText(
        text,
        maxLines: 1,
        minFontSize: 8,
        overflow: TextOverflow.ellipsis,
        style: color == null ? style : style.textColor(color!),
      ),
    );
  }
}
