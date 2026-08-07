class Movie {
  final String id;
  final String title;
  final String? originalTitle;
  final String? quality;
  final String? language;
  final String url;
  final String poster;
  final String? badge;
  final String? views;
  final String? likes;
  final bool hasVietsub;
  final String? description;

  const Movie({
    required this.id,
    required this.title,
    this.originalTitle,
    this.quality,
    this.language,
    required this.url,
    required this.poster,
    this.badge,
    this.views,
    this.likes,
    this.hasVietsub = false,
    this.description,
  });

  factory Movie.fromJson(Map<String, dynamic> json) {
    return Movie(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      originalTitle: json['originalTitle'] as String?,
      quality: json['quality'] as String?,
      language: json['language'] as String?,
      url: json['url'] as String? ?? '',
      poster: json['poster'] as String? ?? '',
      badge: json['badge'] as String?,
      views: json['views'] as String?,
      likes: json['likes'] as String?,
      hasVietsub: json['hasVietsub'] as bool? ?? false,
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'originalTitle': originalTitle,
      'quality': quality,
      'language': language,
      'url': url,
      'poster': poster,
      'badge': badge,
      'views': views,
      'likes': likes,
      'hasVietsub': hasVietsub,
      'description': description,
    };
  }
}

class MovieResponse {
  final List<Movie> movies;
  final int total;

  const MovieResponse({
    required this.movies,
    required this.total,
  });
}

class MovieDetail {
  final String id;
  final String title;
  final String? originalTitle;
  final String? quality;
  final String? language;
  final String? time;
  final String url;
  final String poster;
  final String description;
  final String? views;
  final String? likes;
  final bool hasVietsub;
  final String? streamUrl;
  final String? thumbnailTrackUrl;
  final List<String> tags;
  final List<String> actors;
  final List<String> directors;
  final List<String> countries;
  final List<Movie> relatedMovies;
  final List<MovieEpisodeServer> servers;

  const MovieDetail({
    required this.id,
    required this.title,
    this.originalTitle,
    this.quality,
    this.language,
    this.time,
    required this.url,
    required this.poster,
    required this.description,
    this.views,
    this.likes,
    this.hasVietsub = false,
    this.streamUrl,
    this.thumbnailTrackUrl,
    this.tags = const [],
    this.actors = const [],
    this.directors = const [],
    this.countries = const [],
    this.relatedMovies = const [],
    this.servers = const [],
  });
}

class MovieEpisodeServer {
  final String name;
  final List<MovieEpisode> episodes;

  const MovieEpisodeServer({
    required this.name,
    required this.episodes,
  });
}

class MovieEpisode {
  final String name;
  final String slug;
  final String? m3u8Url;
  final String? embedUrl;

  const MovieEpisode({
    required this.name,
    required this.slug,
    this.m3u8Url,
    this.embedUrl,
  });
}

class MovieStreamVariant {
  const MovieStreamVariant({
    required this.label,
    required this.url,
    required this.width,
    required this.height,
    required this.bandwidth,
  });

  final String label;
  final String url;
  final int width;
  final int height;
  final int bandwidth;
}

class MovieCategory {
  final String id;
  final String name;
  final String path;

  const MovieCategory({
    required this.id,
    required this.name,
    required this.path,
  });

  factory MovieCategory.fromJson(Map<String, dynamic> json) {
    return MovieCategory(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      path: json['path'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'path': path};
  }
}
