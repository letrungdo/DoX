import 'package:cached_network_image/cached_network_image.dart';
import 'package:do_x/constants/dimens.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/model/tv_channel.dart';
import 'package:do_x/utils/device_type.dart';
import 'package:do_x/widgets/neu/neu_card.dart';
import 'package:flutter/material.dart';

/// One channel in the grid: its logo over its name.
class TvChannelCard extends StatelessWidget {
  const TvChannelCard({
    super.key,
    required this.channel,
    required this.onTap,
    this.focusNode,
  });

  final TvChannel channel;
  final VoidCallback onTap;
  final FocusNode? focusNode;

  /// Chosen so that once the television's text scale has been applied the
  /// name is drawn at the 18sp the leanback guidance asks for.
  static const _tvNameSize = 18 / Dimens.tvTextScale;

  /// Two lines of name, always — see [_nameLineHeight].
  static const _nameLines = 2;

  /// The line box of the name, as a multiple of its font size.
  ///
  /// Spelled out rather than left to the font because the strip below the
  /// logo reserves room for [_nameLines] of it whatever the name is. A strip
  /// that grew with the name would take the room out of the logo above it,
  /// and the plates would then be a different height on every card — which
  /// is what the eye reads down a row of them, not the names.
  static const _nameLineHeight = 1.25;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fontSize = deviceType.isTv ? _tvNameSize : 12.0;
    // The scaler is applied by hand because the strip is sized by hand: the
    // text would otherwise grow past the room kept for it.
    final lineHeight =
        MediaQuery.textScalerOf(context).scale(fontSize) * _nameLineHeight;
    return NeuCard(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.zero,
      radius: Dimens.radiusCard,
      focusNode: focusNode,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            // No plate of its own: the card's own surface carries the logo,
            // so the tile is the colour of whichever theme is on. A logo
            // drawn as dark artwork for a white page loses contrast in the
            // dark theme, which is the price of the card being one colour.
            child: Stack(
              fit: StackFit.expand,
              children: [
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: TvChannelLogo(channel: channel),
                ),
                if (channel.isGeoBlocked || channel.isIntermittent)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: _Badge(
                      icon: channel.isGeoBlocked
                          ? Icons.public_off_rounded
                          : Icons.schedule_rounded,
                      tooltip: channel.isGeoBlocked
                          ? l10n.tvGeoBlocked
                          : l10n.tvNotAllDay,
                    ),
                  ),
                if (channel.quality != null)
                  Positioned(
                    bottom: 4,
                    left: 4,
                    child: _QualityTag(quality: channel.quality!),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
            child: SizedBox(
              height: lineHeight * _nameLines,
              child: Text(
                channel.name,
                maxLines: _nameLines,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  // The one label on this page that has to be read from a
                  // sofa. The television's own text scale carries the rest of
                  // the app most of the way, but it is held down to what the
                  // app's phone-sized rows can survive — so the name asks for
                  // the last of it here, where there is room for it.
                  fontSize: fontSize,
                  height: _nameLineHeight,
                  fontWeight: FontWeight.w600,
                ),
                strutStyle: StrutStyle(
                  fontSize: fontSize,
                  height: _nameLineHeight,
                  forceStrutHeight: true,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A channel's logo, with the same stand-in behind it wherever it is drawn:
/// the page's grid, and the grid the player opens over the picture.
class TvChannelLogo extends StatelessWidget {
  const TvChannelLogo({super.key, required this.channel, this.fallbackColor});

  final TvChannel channel;

  /// The colour of the stand-in icon. Left off it follows the theme, which
  /// is what the page wants; over the picture it is given one that reads on
  /// a moving frame.
  final Color? fallbackColor;

  @override
  Widget build(BuildContext context) {
    final fallback = _LogoFallback(color: fallbackColor);
    if (!channel.hasLogo) return fallback;
    return CachedNetworkImage(
      imageUrl: channel.logo!,
      fit: BoxFit.contain,
      placeholder: (context, url) => fallback,
      errorWidget: (context, url, error) => fallback,
    );
  }
}

class _LogoFallback extends StatelessWidget {
  const _LogoFallback({this.color});

  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(
        Icons.live_tv_rounded,
        size: 32,
        color: color ?? context.colors.disabled,
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.tooltip});

  final IconData icon;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(Dimens.radiusSmall),
        ),
        child: Icon(icon, size: 13, color: Colors.white),
      ),
    );
  }
}

class _QualityTag extends StatelessWidget {
  const _QualityTag({required this.quality});

  final String quality;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(Dimens.radiusTiny),
      ),
      child: Text(
        quality,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
