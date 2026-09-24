class MusicTrack {
  final String id;
  final String title;
  final String artist;
  final String artworkUrl;
  final String streamUrl;
  final Duration duration;
  final int likesCount;
  final int repostsCount;

  const MusicTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.artworkUrl,
    required this.streamUrl,
    required this.duration,
    this.likesCount = 0,
    this.repostsCount = 0,
  });

  /// The artwork at the smallest of the service's sizes that is at least
  /// [pixels] wide, for a square drawn [pixels] physical pixels across.
  ///
  /// The service hands out its 100px size (`-large.`) and serves the same
  /// picture at other sizes under other suffixes. A row asks for a small
  /// one and the full-screen player for the 500px one, so a list of fifty
  /// rows no longer downloads and decodes fifty posters. Any other link —
  /// one with no size in it — is returned as it is.
  String artworkUrlFor(double pixels) {
    if (!artworkUrl.contains(_artworkSizeSuffix)) return artworkUrl;
    final size = _artworkSizes.firstWhere(
      (size) => size.pixels >= pixels,
      orElse: () => _artworkSizes.last,
    );
    return artworkUrl.replaceFirst(_artworkSizeSuffix, size.suffix);
  }

  /// The size in the links the service sends.
  static const _artworkSizeSuffix = '-large.';

  /// The sizes the service serves a picture at, smallest first.
  static const _artworkSizes = [
    (pixels: 100, suffix: '-large.'),
    (pixels: 300, suffix: '-t300x300.'),
    (pixels: 500, suffix: '-t500x500.'),
  ];

  /// The largest artwork, for the lock screen and the full-screen player.
  String get largeArtworkUrl => artworkUrlFor(double.infinity);

  factory MusicTrack.fromJson(Map<String, dynamic> json) {
    return MusicTrack(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? 'Unknown Track',
      artist: json['user']?['username'] ?? json['artist'] ?? 'Unknown Artist',
      artworkUrl: json['artwork_url'] ?? json['avatar_url'] ?? '',
      streamUrl: json['stream_url'] ?? '',
      duration: Duration(milliseconds: json['duration'] ?? 0),
      likesCount: json['likes_count'] ?? json['favoritings_count'] ?? 0,
      repostsCount: json['reposts_count'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'artwork_url': artworkUrl,
      'stream_url': streamUrl,
      'duration': duration.inMilliseconds,
      'likes_count': likesCount,
      'reposts_count': repostsCount,
    };
  }
}
