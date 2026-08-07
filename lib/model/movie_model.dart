class Movie {
  final String id;
  final String title;
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
  final String url;
  final String poster;
  final String description;
  final String? views;
  final String? likes;
  final bool hasVietsub;
  final String? streamUrl;
  final String? thumbnailTrackUrl;
  final List<String> tags;
  final List<Movie> relatedMovies;

  const MovieDetail({
    required this.id,
    required this.title,
    required this.url,
    required this.poster,
    required this.description,
    this.views,
    this.likes,
    this.hasVietsub = false,
    this.streamUrl,
    this.thumbnailTrackUrl,
    this.tags = const [],
    this.relatedMovies = const [],
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
