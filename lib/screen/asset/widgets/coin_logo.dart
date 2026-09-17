import 'package:cached_network_image/cached_network_image.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/extensions/string_extensions.dart';
import 'package:do_x/extensions/text_style_extensions.dart';
import 'package:flutter/material.dart';

/// A coin's logo from Binance's asset directory, on the round badge the asset
/// tiles use.
///
/// Coin marks are round or square, so unlike a bank's wordmark this one fills
/// its badge. A coin the directory has not heard of — or one whose logo is
/// still loading — wears its own ticker instead, which is what the tab showed
/// before any logo existed.
class CoinLogo extends StatelessWidget {
  const CoinLogo({super.key, required this.base, this.logo, this.size = 44});

  /// The coin on its own, e.g. "BTC".
  final String base;
  final String? logo;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = logo;

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: context.theme.colorScheme.surfaceContainerHighest,
        shape: BoxShape.circle,
      ),
      child: url == null || url.isEmpty
          ? _ticker(context)
          : CachedNetworkImage(
              imageUrl: url.withProxy(),
              fadeInDuration: Durations.medium1,
              fit: BoxFit.cover,
              placeholder: (_, _) => _ticker(context),
              errorWidget: (_, _, _) => _ticker(context),
            ),
    );
  }

  Widget _ticker(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(2),
      child: FittedBox(
        child: Text(
          // Four characters is as much as a 44px circle reads at: "MATIC"
          // shrinks to a smudge, "MATI" still says which coin it is.
          base.length > 4 ? base.substring(0, 4) : base,
          style: context.textTheme.secondary.bold,
        ),
      ),
    );
  }
}
