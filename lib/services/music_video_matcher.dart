import 'package:collection/collection.dart';
import 'package:do_x/model/music_track.dart';
import 'package:do_x/model/music_video.dart';

/// The video picked for a track, and whether its sound replaces the track's.
class MusicVideoPick {
  const MusicVideoPick({required this.video, required this.useAudio});

  final YoutubeVideo video;
  final bool useAudio;
}

/// Decides which YouTube video, if any, belongs to a Music track.
///
/// A wrong picture is worse than none, so every rule here errs on the side of
/// turning a video down:
///
/// - The version has to be the same one. A remix on Music gets the remix's
///   video or nothing, never the original's — and the reverse, which matters
///   more: YouTube is full of karaoke, cover and "sped up" uploads of every
///   hit, and those are exactly what the track's own sound is there to avoid.
/// - Most of the track title's words have to be in the video's title or
///   channel.
/// - The lengths have to agree. A muted video is laid over the track's sound
///   from the same starting point, so it only lines up when the two last
///   about as long; an official video brings its own sound, so it is let off
///   with a looser bound — enough for a few seconds of logo, not for the
///   ten-minute short film some music videos are. Not for a remix or a cover,
///   though: there the name is shared by every remixer's take, and only the
///   same length says it is the same one.
abstract final class MusicVideoMatcher {
  /// How far apart a muted video and the track may run in length.
  static const syncTolerance = Duration(seconds: 4);

  /// How far apart an official video, played with its own sound, and the
  /// track may run in length.
  static const officialTolerance = Duration(seconds: 30);

  /// The share of the track title's words the video has to carry.
  static const _minCoverage = 0.6;

  /// Words that name a version of a song rather than the song. Either both
  /// titles have the same ones or they are two different recordings.
  static const _versionWords = {
    'remix',
    'cover',
    'lofi',
    'live',
    'acoustic',
    'karaoke',
    'instrumental',
    'beat',
    'nightcore',
    'slowed',
    'sped',
    'speed',
    'vinahouse',
    'house',
    'edm',
    'piano',
    'guitar',
    'mashup',
    'medley',
    'remake',
    'rework',
    'bootleg',
    'tiktok',
    '8d',
  };

  /// Words that describe the upload rather than the song.
  static const _noiseWords = {
    'official',
    'mv',
    'm',
    'v',
    'music',
    'video',
    'audio',
    'lyric',
    'lyrics',
    'lyrical',
    'visualizer',
    'hd',
    '4k',
    'ft',
    'feat',
    'featuring',
    'prod',
    'x',
    'vietsub',
  };

  /// What to ask YouTube for. A Music title is often already "Artist - Song";
  /// the uploader is added only when it is not, since on Music the uploader
  /// is as often a reposting channel as the artist.
  static String searchQuery(MusicTrack track) {
    final title = track.title.trim();
    final artist = track.artist.trim();
    if (title.contains(' - ') || artist.isEmpty) return title;
    final titleWords = tokens(title);
    if (tokens(artist).every(titleWords.contains)) return title;
    return '$artist $title';
  }

  static MusicVideoPick? pick(MusicTrack track, List<YoutubeVideo> videos) {
    // Without a length there is nothing to line a picture up against.
    if (track.duration <= Duration.zero) return null;

    final wanted = tokens(track.title);
    final wantedVersions = wanted.intersection(_versionWords);
    final wantedWords = wanted.difference(_versionWords);
    if (wantedWords.isEmpty) return null;
    final audioTolerance = wantedVersions.isEmpty
        ? officialTolerance
        : syncTolerance;

    MusicVideoPick? best;
    var bestScore = double.negativeInfinity;
    for (final video in videos) {
      if (video.id.isEmpty || video.duration <= Duration.zero) continue;

      final versions = tokens(video.title).intersection(_versionWords);
      if (!const SetEquality<String>().equals(versions, wantedVersions)) {
        continue;
      }

      final offered = tokens('${video.title} ${video.author}');
      final coverage =
          wantedWords.where(offered.contains).length / wantedWords.length;
      if (coverage < _minCoverage) continue;

      final gap = (video.duration - track.duration).abs();
      final useAudio = video.isOfficial && gap <= audioTolerance;
      if (!useAudio && gap > syncTolerance) continue;

      // The words decide first; then an official video over a fan's, then
      // the closer length.
      final score =
          coverage + (useAudio ? 0.5 : 0) - gap.inMilliseconds / 100000;
      if (score > bestScore) {
        bestScore = score;
        best = MusicVideoPick(video: video, useAudio: useAudio);
      }
    }
    return best;
  }

  /// The words of [text], lower-cased, without Vietnamese marks or
  /// punctuation, and without the words that only describe the upload.
  static Set<String> tokens(String text) {
    final plain = _stripMarks(text.toLowerCase());
    return plain
        .split(RegExp(r'[^a-z0-9]+'))
        .where((word) => word.isNotEmpty && !_noiseWords.contains(word))
        .toSet();
  }

  static const _marked =
      'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
  static const _plain =
      'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';

  static String _stripMarks(String text) {
    final buffer = StringBuffer();
    for (final rune in text.runes) {
      // A title typed with separate combining marks keeps only its letters.
      if (rune >= 0x300 && rune <= 0x36F) continue;
      final char = String.fromCharCode(rune);
      final index = _marked.indexOf(char);
      buffer.write(index < 0 ? char : _plain[index]);
    }
    return buffer.toString();
  }
}
