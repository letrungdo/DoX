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

  /// One line of name, cut where it runs out.
  ///
  /// A grid of stations is read by their logos; the name underneath is there
  /// to settle which of two similar ones this is, and a second line of it
  /// only takes room from the logo that does the work.
  static const _nameLines = 1;

  /// The line box of the name, as a multiple of its font size.
  ///
  /// Spelled out rather than left to the font because the strip below the
  /// logo reserves room for [_nameLines] of it whatever the name is. A strip
  /// that grew with the name would take the room out of the logo above it,
  /// and the logos would then be a different size on every card — which is
  /// what the eye reads down a row of them, not the names.
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
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
            child: SizedBox(
              height: lineHeight * _nameLines,
              child: TvChannelName(
                name: channel.name,
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
                // The strut keeps the base size whatever the name shrinks
                // to, so a card with a long name is the same height as the
                // one beside it.
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

/// A channel's name on one line, shrunk to fit before it is cut.
///
/// Station names run from `HTV7` to `Báo và Phát thanh – Truyền hình Lâm
/// Đồng`, and a grid has one width for all of them. Cutting every long one
/// at the same place leaves a column of cards ending in `…`, which says
/// nothing about which channel it is; shrinking the type a little says the
/// whole name instead. Only a little, though — past [_minScale] the name is
/// smaller than a sofa can read, and three dots are the better answer.
class TvChannelName extends StatelessWidget {
  const TvChannelName({
    super.key,
    required this.name,
    required this.style,
    this.strutStyle,
    this.textAlign = TextAlign.center,
  });

  final String name;

  /// The size the name is drawn at when it fits, and the largest it is ever
  /// drawn at.
  final TextStyle style;

  final StrutStyle? strutStyle;
  final TextAlign textAlign;

  /// How far the type may be taken down before the name is cut instead.
  ///
  /// A fifth of the size is as much as a sofa can give up: below that the
  /// name is no longer being read across a room, which is the only reason
  /// it was being kept whole.
  static const minScale = 0.8;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: name, style: style),
          maxLines: 1,
          textDirection: Directionality.of(context),
          textScaler: scaler,
        )..layout();
        final width = constraints.maxWidth;
        // One measurement is enough: type laid out on one line is as wide
        // as its size, so the size that fits is the size it has now times
        // how much of the room it is over by.
        final scale = width <= 0 || painter.width <= width
            ? 1.0
            : (width / painter.width).clamp(minScale, 1.0);
        final fontSize = (style.fontSize ?? 14) * scale;

        return Text(
          name,
          maxLines: 1,
          textAlign: textAlign,
          overflow: TextOverflow.ellipsis,
          style: style.copyWith(fontSize: fontSize),
          strutStyle: strutStyle,
        );
      },
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
      // Decoded once, at the size it is drawn, and shared from there — see
      // [Dimens.tvChannelLogoDecodeWidth].
      memCacheWidth: Dimens.tvChannelLogoDecodeWidth,
      // A grid brings a screenful of logos up at once, and a fade each is
      // a screenful of animations running on a television that has a live
      // stream to decode. They appear as they arrive instead.
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
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
