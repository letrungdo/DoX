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
