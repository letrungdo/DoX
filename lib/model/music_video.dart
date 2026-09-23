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

/// The video found for a track, with the streams the player can open.
class MusicVideo {
  const MusicVideo({
    required this.videoId,
    required this.duration,
    required this.useAudio,
    this.loops = false,
    this.hdVideoUrl,
    this.hdAudioUrl,
    this.muxedUrl,
  });

  final String videoId;
  final Duration duration;

  /// The song's own official video, the same recording as the track: its
  /// sound is played instead of the track's, which also keeps the picture in
  /// step with it. Otherwise the video is shown muted over the track.
  final bool useAudio;

  /// A stand-in for a song that has no video of its own: looped, muted, as a
  /// backdrop, and not kept in step with the music.
  final bool loops;

  /// Picture only, up to 1080p. Absent when YouTube would not hand one over
  /// that plays to the end.
  final String? hdVideoUrl;

  /// Sound only, at the video's best quality, to go under [hdVideoUrl].
  final String? hdAudioUrl;

  /// Picture and sound in one, at 360p: the stream that always plays.
  final String? muxedUrl;

  /// This video with its HD streams added.
  MusicVideo withHd({String? videoUrl, String? audioUrl}) => MusicVideo(
    videoId: videoId,
    duration: duration,
    useAudio: useAudio,
    loops: loops,
    hdVideoUrl: videoUrl,
    hdAudioUrl: audioUrl,
    muxedUrl: muxedUrl,
  );

  /// There is a picture to show.
  bool get isPlayable => pictureUrls.isNotEmpty;

  /// The streams to try for the picture, best first.
  List<String> get pictureUrls => [?hdVideoUrl, ?muxedUrl];

  /// There is an official sound to play, and a stream to play it from.
  bool get carriesAudio => useAudio && (hdAudioUrl != null || muxedUrl != null);
}
