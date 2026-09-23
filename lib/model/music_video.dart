/// One video from a YouTube Music search.
class YoutubeVideo {
  const YoutubeVideo({
    required this.id,
    required this.title,
    required this.author,
    required this.duration,
    required this.isOfficial,
  });

  final String id;
  final String title;

  /// The channel, which for an official video is the artist.
  final String author;
  final Duration duration;

  /// Put out by the artist's label as the song's music video
  /// (`MUSIC_VIDEO_TYPE_OMV`), rather than uploaded by anybody else.
  final bool isOfficial;
}

/// The picture found for a track, ready for the player.
class MusicVideo {
  const MusicVideo({
    required this.videoId,
    required this.streamUrl,
    required this.duration,
    required this.carriesAudio,
  });

  final String videoId;
  final String streamUrl;
  final Duration duration;

  /// The song's official video: its own sound is played instead of the
  /// track's, which also keeps the picture in step with it by construction.
  /// Otherwise the video is shown muted over the track's sound.
  final bool carriesAudio;
}
