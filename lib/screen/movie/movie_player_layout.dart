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

/// App bar actions are sized so their neumorphic shadow (offset + blur, about
/// 5px at this depth) still fits inside the bar instead of spilling out of it.
const appBarActionSize = 32.0;
const appBarActionDepth = 0.4;

/// Fixed height of the original-title strip in the overlay header.
const embeddedSubtitleHeight = 24.0;

/// Sizes the inline player to [aspectRatio] but never below [minHeight];
/// when [fill] is set it simply takes all the space its parent offers.
class PlayerBox extends StatelessWidget {
  const PlayerBox({super.key, required this.aspectRatio, required this.minHeight, required this.fill, required this.child});

  final double aspectRatio;
  final double minHeight;
  final bool fill;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (fill) return child;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite ? constraints.maxWidth : MediaQuery.sizeOf(context).width;
        return SizedBox(width: width, height: math.max(width / aspectRatio, minHeight), child: child);
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
  const AppBarTitleFit({required this.titleStyle, required this.height});
  final TextStyle titleStyle;
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

AppBarTitleFit appBarTitleFit(BuildContext context, String title) {
  final theme = Theme.of(context);
  final titleStyle = theme.appBarTheme.titleTextStyle ?? theme.textTheme.titleLarge ?? const TextStyle(fontSize: 20);

  final screenWidth = MediaQuery.sizeOf(context).width;
  final availableWidth = screenWidth > 272 ? screenWidth - 160 : 120.0;

  final titleFit = fitText(
    context: context,
    text: title,
    style: titleStyle,
    maxWidth: availableWidth,
    maxLines: titleMaxLines,
    minFontSize: 12,
  );

  // 12 = 6px breathing room above/below the title block.
  return AppBarTitleFit(
    titleStyle: titleStyle.copyWith(fontSize: titleFit.fontSize),
    height: math.max(56.0, titleFit.height + 12),
  );
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
