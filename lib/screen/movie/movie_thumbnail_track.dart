import 'package:flutter/material.dart';

/// One entry of a WebVTT sprite track: the crop of [imageUrl] to show while the
/// playhead preview sits between [start] and [end].
class ThumbnailCue {
  const ThumbnailCue({
    required this.start,
    required this.end,
    required this.imageUrl,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final Duration start;
  final Duration end;
  final String imageUrl;
  final double x;
  final double y;
  final double width;
  final double height;
}

class ThumbnailTrack {
  const ThumbnailTrack({required this.cues, required this.spriteUrl, required this.spriteWidth, required this.spriteHeight});

  final List<ThumbnailCue> cues;
  final String spriteUrl;
  final double spriteWidth;
  final double spriteHeight;

  ThumbnailCue? cueAt(Duration position) {
    for (final cue in cues) {
      if (position >= cue.start && position < cue.end) return cue;
    }
    if (cues.isNotEmpty && position >= cues.last.end) return cues.last;
    return null;
  }

  static ThumbnailTrack? parse(String trackUrl, String source) {
    final cuePattern = RegExp(
      r'^(\d{2}:\d{2}:\d{2}\.\d{3})\s+-->\s+'
      r'(\d{2}:\d{2}:\d{2}\.\d{3})\s*\r?\n'
      r'([^\r\n#]+)#xywh=(\d+),(\d+),(\d+),(\d+)',
      multiLine: true,
    );
    final cues = <ThumbnailCue>[];
    var spriteWidth = 0.0;
    var spriteHeight = 0.0;

    for (final match in cuePattern.allMatches(source)) {
      final x = double.parse(match.group(4)!);
      final y = double.parse(match.group(5)!);
      final width = double.parse(match.group(6)!);
      final height = double.parse(match.group(7)!);
      final imageUrl = Uri.parse(trackUrl).resolve(match.group(3)!.trim()).toString();
      cues.add(
        ThumbnailCue(
          start: _parseTimestamp(match.group(1)!),
          end: _parseTimestamp(match.group(2)!),
          imageUrl: imageUrl,
          x: x,
          y: y,
          width: width,
          height: height,
        ),
      );
      spriteWidth = spriteWidth < x + width ? x + width : spriteWidth;
      spriteHeight = spriteHeight < y + height ? y + height : spriteHeight;
    }

    if (cues.isEmpty) return null;
    return ThumbnailTrack(cues: cues, spriteUrl: cues.first.imageUrl, spriteWidth: spriteWidth, spriteHeight: spriteHeight);
  }

  static Duration _parseTimestamp(String timestamp) {
    final parts = timestamp.split(RegExp(r'[:.]'));
    return Duration(
      hours: int.parse(parts[0]),
      minutes: int.parse(parts[1]),
      seconds: int.parse(parts[2]),
      milliseconds: int.parse(parts[3]),
    );
  }
}

/// Draws the sprite crop for [cue], or [fallback] when there is no track.
class ThumbnailPreview extends StatelessWidget {
  const ThumbnailPreview({
    super.key,
    required this.track,
    required this.cue,
    required this.width,
    required this.referer,
    required this.fallback,
  });

  final ThumbnailTrack? track;
  final ThumbnailCue? cue;
  final double width;
  final String referer;

  /// Shown while the sprite track is still missing.
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    final cue = this.cue;
    final track = this.track;
    if (cue == null || track == null) return fallback;

    final scale = width / cue.width;
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            left: -cue.x * scale,
            top: -cue.y * scale,
            width: track.spriteWidth * scale,
            height: track.spriteHeight * scale,
            child: Image.network(
              cue.imageUrl,
              headers: {'Referer': referer},
              fit: BoxFit.fill,
              gaplessPlayback: true,
              filterQuality: FilterQuality.low,
              errorBuilder: (_, _, _) => const ColoredBox(
                color: Colors.black,
                child: Center(child: Icon(Icons.image_not_supported, color: Colors.white38)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
