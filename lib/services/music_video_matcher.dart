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
/// A picture is laid over the track, so almost any video of the song will do
/// — a remix is as happy under the original's music video as under its own.
/// Two things still turn a video down:
///
/// - Most of the track title's words have to be in the video's title or
///   channel, or it is a video of some other song.
/// - It must not be shorter than the track, or the picture runs out before
///   the music does.
///
/// Swapping the track's *sound* for the video's is another matter: that is
/// only done for the artist's official video of the very same recording —
/// the same version words (a remix stays the remix the user chose) and about
/// the same length, allowing for a few seconds of logo but not for the
/// ten-minute short film some music videos are. For a remix or a cover the
/// name is shared by every remixer's take, so only the same length will do.
abstract final class MusicVideoMatcher {
  /// How much shorter than the track a video may be: the last seconds of a
  /// song are often a fade nobody is watching.
  static const lengthSlack = Duration(seconds: 2);

  /// How far apart an official video and the track may run in length for
  /// the video's sound to be played instead.
  static const officialTolerance = Duration(seconds: 30);

  /// The same, for a remix or a cover.
  static const versionTolerance = Duration(seconds: 4);

  /// The share of the track title's words the video has to carry.
  static const _minCoverage = 0.6;

  /// Words that name a version of a song rather than the song. Either both
  /// titles have the same ones or they are two different recordings — which
  /// only matters for the sound.
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
    // Without a length there is nothing to hold a video's length up against.
    if (track.duration <= Duration.zero) return null;

    final wanted = tokens(track.title);
    final wantedVersions = wanted.intersection(_versionWords);
    final wantedWords = wanted.difference(_versionWords);
    if (wantedWords.isEmpty) return null;
    final audioTolerance = wantedVersions.isEmpty
        ? officialTolerance
        : versionTolerance;

    MusicVideoPick? best;
    var bestScore = double.negativeInfinity;
    for (final video in videos) {
      if (video.id.isEmpty || video.duration <= Duration.zero) continue;

      final offered = tokens('${video.title} ${video.author}');
      final coverage =
          wantedWords.where(offered.contains).length / wantedWords.length;
      if (coverage < _minCoverage) continue;

      final sameVersion = const SetEquality<String>().equals(
        tokens(video.title).intersection(_versionWords),
        wantedVersions,
      );
      final gap = video.duration - track.duration;
      final useAudio =
          video.isOfficial && sameVersion && gap.abs() <= audioTolerance;
      if (!useAudio && gap < -lengthSlack) continue;

      // The official sound first; then the same version, an official
      // picture, the words, and the closer length.
      final score =
          (useAudio ? 2 : 0) +
          (sameVersion ? 0.5 : 0) +
          (video.isOfficial ? 0.3 : 0) +
          coverage -
          gap.abs().inSeconds / 10000;
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
