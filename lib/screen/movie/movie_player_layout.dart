import 'dart:math' as math;

import 'package:flutter/material.dart';

const titleMaxLines = 3;
const subtitleMaxLines = 2;

/// Keeps the inline player tall enough for the centre button and the progress
/// bar not to collide, however wide the video is.
const minPlayerHeight = 220.0;

/// Size of the collapsed mini player, kept in sync with the host overlay.
const miniPlayerHeight = 66.0;
const miniPlayerWidth = 116.0;

/// Fixed height of the original-title strip in the overlay header.
const embeddedSubtitleHeight = 26.0;

/// Ceiling for the inline player as a share of the space it is given. Without
/// it a wide desktop window makes a 16:9 video as tall as the page and there is
/// nothing left to scroll.
const maxPlayerHeightFraction = 0.6;

/// Height of the inline player: its aspect ratio, never under [minHeight] and
/// never over [maxPlayerHeightFraction] of [availableHeight].
double inlinePlayerHeight({
  required double width,
  required double aspectRatio,
  required double availableHeight,
  double minHeight = minPlayerHeight,
}) {
  final height = math.max(width / aspectRatio, minHeight);
  if (!availableHeight.isFinite || availableHeight <= 0) return height;
  // The cap wins even over minHeight: a page that cannot be scrolled is worse
  // than a short player.
  return math.min(height, availableHeight * maxPlayerHeightFraction);
}

/// Sizes the inline player to [aspectRatio] but never below [minHeight];
/// when [fill] is set it simply takes all the space its parent offers.
class PlayerBox extends StatelessWidget {
  const PlayerBox({
    super.key,
    required this.aspectRatio,
    required this.minHeight,
    required this.fill,
    required this.child,
  });

  final double aspectRatio;
  final double minHeight;
  final bool fill;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (fill) return child;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final height = inlinePlayerHeight(
          width: width,
          aspectRatio: aspectRatio,
          availableHeight: constraints.maxHeight,
          minHeight: minHeight,
        );
        return SizedBox(width: width, height: height, child: child);
      },
    );
  }
}

/// Result of shrinking a text to fit a line budget.
class TextFit {
  const TextFit({required this.fontSize, required this.height});
  final double fontSize;
  final double height;
}

/// Styles and toolbar height for the app bar title block.
class AppBarTitleFit {
  const AppBarTitleFit({
    required this.titleStyle,
    required this.subtitleStyle,
    required this.height,
  });
  final TextStyle titleStyle;

  /// Style for the alternate name under the title, already shrunk to fit its
  /// line budget. `null` when the title has no alternate name.
  final TextStyle? subtitleStyle;
  final double height;
}

/// Shrinks [style] until [text] fits in [maxLines] within [maxWidth], and
/// reports the height it occupies at that size.
TextFit fitText({
  required BuildContext context,
  required String text,
  required TextStyle style,
  required double maxWidth,
  required int maxLines,
  required double minFontSize,
}) {
  final textDirection = Directionality.of(context);
  final textScaler = MediaQuery.textScalerOf(context);
  double fontSize = style.fontSize ?? 14;

  while (true) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: style.copyWith(fontSize: fontSize),
      ),
      maxLines: maxLines,
      textDirection: textDirection,
      textScaler: textScaler,
    )..layout(maxWidth: maxWidth);
    final fits = !painter.didExceedMaxLines;
    final height = painter.height;
    painter.dispose();
    if (fits || fontSize <= minFontSize) {
      return TextFit(fontSize: fontSize, height: height);
    }
    fontSize = math.max(minFontSize, fontSize - 0.5);
  }
}

/// A title split into the name and the alternate name shown under it.
typedef MovieTitleParts = ({String title, String? subtitle});

/// Anywhere in the title, not just at its end — some servers write
/// `Tên phim (Tên khác) - Phần 2`.
final _bracketPattern = RegExp(r'\(([^()]+)\)');
final _repeatedSpaces = RegExp(r'\s{2,}');

/// The last title split and what it came out as. The player asks for the same
/// title on every build, so the regex runs once per title rather than once per
/// frame.
String? _lastSplitInput;
MovieTitleParts? _lastSplitResult;

/// A bracketed part of the title is another name for the movie, as in
/// `Kẻ Trộm Mặt Trăng 4 (Despicable Me 4)`, and reads as the app bar's second
/// line. It is not the original name, which has its own field and own strip.
MovieTitleParts splitMovieTitle(String rawTitle) {
  final cached = _lastSplitResult;
  if (cached != null && _lastSplitInput == rawTitle) return cached;
  final result = _splitMovieTitle(rawTitle);
  _lastSplitInput = rawTitle;
  _lastSplitResult = result;
  return result;
}

MovieTitleParts _splitMovieTitle(String rawTitle) {
  final title = rawTitle.trim();
  final alternates = _bracketPattern
      .allMatches(title)
      .map((match) => match.group(1)!.trim())
      .where((value) => value.isNotEmpty)
      .toSet();
  if (alternates.isEmpty) return (title: title, subtitle: null);

  final name = title
      .replaceAll(_bracketPattern, ' ')
      .replaceAll(_repeatedSpaces, ' ')
      .trim();
  // A title that is nothing but brackets keeps what it had.
  if (name.isEmpty) return (title: title, subtitle: null);

  return (title: name, subtitle: alternates.join(' • '));
}

/// How many fitted title blocks and strips are remembered. A handful covers
/// the detail page's own variants (bar, overlay header, strip) across a
/// rotation or two.
const _fitCacheLimit = 16;

/// Fitted results keyed on everything that decides them — text, styles,
/// width, text scale and direction. Fitting lays the text out at every half
/// point it tries, which is far too much to redo on every build.
final _fitCache = <Object, Object>{};

T _memoizedFit<T extends Object>(Object key, T Function() compute) {
  final hit = _fitCache.remove(key);
  if (hit is T) {
    // Re-inserted, so the map's insertion order doubles as recency.
    _fitCache[key] = hit;
    return hit;
  }
  final value = compute();
  _fitCache[key] = value;
  if (_fitCache.length > _fitCacheLimit) {
    _fitCache.remove(_fitCache.keys.first);
  }
  return value;
}

TextStyle _baseSubtitleStyle(ThemeData theme) =>
    theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
    ) ??
    const TextStyle(fontSize: 12);

/// Fits the title block of the bar, [subtitle] being the alternate name that
/// sits under the title. Both shrink rather than being cut off, and [height]
/// covers the pair.
AppBarTitleFit appBarTitleFit(
  BuildContext context,
  String title, {
  String? subtitle,
  int subtitleLines = subtitleMaxLines,
}) {
  final theme = Theme.of(context);
  final titleStyle =
      theme.appBarTheme.titleTextStyle ??
      theme.textTheme.titleLarge ??
      const TextStyle(fontSize: 20);
  final baseSubtitleStyle = _baseSubtitleStyle(theme);

  final screenWidth = MediaQuery.sizeOf(context).width;
  final availableWidth = screenWidth > 272 ? screenWidth - 160 : 120.0;

  final key = (
    #appBarTitle,
    title,
    subtitle,
    subtitleLines,
    availableWidth,
    titleStyle,
    baseSubtitleStyle,
    MediaQuery.textScalerOf(context),
    Directionality.of(context),
  );
  return _memoizedFit(
    key,
    () => _fitAppBarTitle(
      context,
      title,
      subtitle: subtitle,
      subtitleLines: subtitleLines,
      titleStyle: titleStyle,
      baseSubtitleStyle: baseSubtitleStyle,
      availableWidth: availableWidth,
    ),
  );
}

AppBarTitleFit _fitAppBarTitle(
  BuildContext context,
  String title, {
  required String? subtitle,
  required int subtitleLines,
  required TextStyle titleStyle,
  required TextStyle baseSubtitleStyle,
  required double availableWidth,
}) {
  final titleFit = fitText(
    context: context,
    text: title,
    style: titleStyle,
    maxWidth: availableWidth,
    maxLines: titleMaxLines,
    minFontSize: 12,
  );

  TextStyle? subtitleStyle;
  var subtitleHeight = 0.0;
  if (subtitle != null && subtitle.isNotEmpty) {
    final subtitleFit = fitText(
      context: context,
      text: subtitle,
      style: baseSubtitleStyle,
      maxWidth: availableWidth,
      maxLines: subtitleLines,
      minFontSize: 8,
    );
    subtitleStyle = baseSubtitleStyle.copyWith(fontSize: subtitleFit.fontSize);
    subtitleHeight = subtitleFit.height + 2;
  }

  // 12 = 6px breathing room above/below the title block.
  return AppBarTitleFit(
    titleStyle: titleStyle.copyWith(fontSize: titleFit.fontSize),
    subtitleStyle: subtitleStyle,
    height: math.max(56.0, titleFit.height + subtitleHeight + 12),
  );
}

/// Fitted style for the full-width strip under the bar, which carries the
/// original name. It reads a step up from the alternate name in the bar, and
/// shrinks to fit [maxLines] over the whole width.
TextStyle subtitleStripStyle(
  BuildContext context,
  String text, {
  int maxLines = subtitleMaxLines,
}) {
  final theme = Theme.of(context);
  final baseStyle =
      theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.85),
        fontWeight: FontWeight.w600,
      ) ??
      const TextStyle(fontSize: 14, fontWeight: FontWeight.w600);
  if (text.isEmpty) return baseStyle;
  final maxWidth = math.max(120.0, MediaQuery.sizeOf(context).width - 32);
  final key = (
    #subtitleStrip,
    text,
    maxLines,
    maxWidth,
    baseStyle,
    MediaQuery.textScalerOf(context),
    Directionality.of(context),
  );
  return _memoizedFit(key, () {
    final fit = fitText(
      context: context,
      text: text,
      style: baseStyle,
      maxWidth: maxWidth,
      maxLines: maxLines,
      minFontSize: 8,
    );
    return baseStyle.copyWith(fontSize: fit.fontSize);
  });
}

String formatDuration(Duration duration) {
  String twoDigits(int n) => n.toString().padLeft(2, '0');
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);
  if (hours > 0) {
    return '$hours:${twoDigits(minutes)}:${twoDigits(seconds)}';
  } else {
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }
}
