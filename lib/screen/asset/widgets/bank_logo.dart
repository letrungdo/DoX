import 'package:cached_network_image/cached_network_image.dart';
import 'package:do_x/constants/dimens.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/extensions/string_extensions.dart';
import 'package:do_x/screen/asset/widgets/asset_tile.dart';
import 'package:flutter/material.dart';

/// A bank's logo from the VietQR directory, falling back to the generic bank
/// icon.
///
/// The directory's logos are wide wordmarks — roughly three times as wide as
/// they are tall — so they are drawn on a rounded rectangle rather than inside
/// the round badge the other tiles use. A circle of the same width can only
/// fit such a logo by shrinking it until the bank's name is a smudge; the
/// rectangle spends its height on the logo instead of on empty corners.
///
/// The chip is white in both themes because the logos are dark ink on
/// transparent: on a dark surface most of them vanish.
class BankLogo extends StatelessWidget {
  const BankLogo({super.key, required this.logo, this.size = 44});

  final String? logo;

  /// The height of the slot. The chip is wider than this, in the proportion
  /// the logos themselves come in.
  final double size;

  /// How much wider than tall the chip is, following the wordmarks.
  static const _aspect = 2.0;

  @override
  Widget build(BuildContext context) {
    final url = logo;
    if (url == null || url.isEmpty) return _fallback(context);

    return Container(
      width: size * _aspect,
      height: size,
      padding: EdgeInsets.all(size * 0.1),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(Dimens.radiusSmall),
      ),
      child: CachedNetworkImage(
        imageUrl: url.withProxy(),
        fadeInDuration: Durations.medium1,
        fit: BoxFit.contain,
        // Not the icon: a bank badge that turns into a logo chip a moment
        // later makes the whole row jump sideways.
        placeholder: (_, _) => const SizedBox.shrink(),
        errorWidget: (_, _, _) => Center(
          child: Icon(
            Icons.account_balance_rounded,
            color: context.colors.info,
            size: size * 0.5,
          ),
        ),
      ),
    );
  }

  /// A bank the directory has never heard of, or a name typed by hand that
  /// matches nothing, keeps the round badge every other tile wears.
  Widget _fallback(BuildContext context) {
    return AssetTileBadge(
      color: context.colors.infoSoft,
      size: size,
      child: Icon(
        Icons.account_balance_rounded,
        color: context.colors.info,
        size: size * 0.5,
      ),
    );
  }
}
