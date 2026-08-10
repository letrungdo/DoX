import 'package:do_x/model/movie_model.dart';
import 'package:do_x/services/movie_service.dart';
import 'package:do_x/services/supabase_service.dart';
import 'package:do_x/utils/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef MovieLibraryState = ({
  bool isFavorite,
  DateTime? watchedAt,
  String? lastEpisodeName,
  String? lastServerName,
  int? lastPositionSeconds,
});
typedef MovieLibraryItem = ({Movie movie, MovieLibraryState state});
typedef MovieLibraryBatchCallback = void Function(List<MovieLibraryItem> items);

class MovieLibraryService {
  const MovieLibraryService();

  MovieLibraryScope get _scope => movieService.isPrimaryServer
      ? MovieLibraryScope.primary
      : MovieLibraryScope.external;

  String _toDbId(String movieId) => _scope.toDbId(movieId);

  String _fromDbId(String dbId) => MovieLibraryScope.stripPrefix(dbId);

  Future<MovieLibraryState> getState(String movieId) async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      return (
        isFavorite: false,
        watchedAt: null,
        lastEpisodeName: null,
        lastServerName: null,
        lastPositionSeconds: null,
      );
    }

    final row = await supabase
        .from('movie_library')
        .select(
          'is_favorite, watched_at, last_episode_name, last_server_name, last_position_seconds',
        )
        .eq('user_id', user.id)
        .eq('movie_id', _toDbId(movieId))
        .maybeSingle();

    return (
      isFavorite: row?['is_favorite'] as bool? ?? false,
      watchedAt: DateTime.tryParse(row?['watched_at'] as String? ?? ''),
      lastEpisodeName: row?['last_episode_name'] as String?,
      lastServerName: row?['last_server_name'] as String?,
      lastPositionSeconds: row?['last_position_seconds'] as int?,
    );
  }

  Future<Map<String, MovieLibraryState>> getStates(
    Iterable<String> movieIds,
  ) async {
    final user = supabase.auth.currentUser;
    final ids = movieIds
        .where((id) => id.isNotEmpty)
        .map(_toDbId)
        .toSet()
        .toList();
    if (user == null || ids.isEmpty) return {};

    final rows = await supabase
        .from('movie_library')
        .select(
          'movie_id, is_favorite, watched_at, last_episode_name, last_server_name, last_position_seconds',
        )
        .eq('user_id', user.id)
        .inFilter('movie_id', ids);

    return {
      for (final row in rows)
        if ((row['movie_id'] as String? ?? '').isNotEmpty)
          _fromDbId(row['movie_id'] as String): (
            isFavorite: row['is_favorite'] as bool? ?? false,
            watchedAt: DateTime.tryParse(row['watched_at'] as String? ?? ''),
            lastEpisodeName: row['last_episode_name'] as String?,
            lastServerName: row['last_server_name'] as String?,
            lastPositionSeconds: row['last_position_seconds'] as int?,
          ),
    };
  }

  Future<MovieResponse> getWatched({
    String searchQuery = '',
    int page = 1,
    int pageSize = 20,
    MovieLibraryBatchCallback? onBatch,
  }) {
    return _getMovies(
      watchedOnly: true,
      searchQuery: searchQuery,
      page: page,
      pageSize: pageSize,
      onBatch: onBatch,
    );
  }

  Future<MovieResponse> getFavorites({
    String searchQuery = '',
    int page = 1,
    int pageSize = 20,
    MovieLibraryBatchCallback? onBatch,
  }) {
    return _getMovies(
      favoritesOnly: true,
      searchQuery: searchQuery,
      page: page,
      pageSize: pageSize,
      onBatch: onBatch,
    );
  }

  Future<void> markWatched(
    Movie movie, {
    String? episodeName,
    String? serverName,
    int? positionSeconds,
  }) {
    return _upsertMovie(
      movie,
      extraValues: {
        'watched_at': DateTime.now().toUtc().toIso8601String(),
        'last_episode_name': ?episodeName,
        'last_server_name': ?serverName,
        'last_position_seconds': ?positionSeconds,
      },
    );
  }

  Future<void> setFavorite(Movie movie, bool isFavorite) {
    return _upsertMovie(movie, extraValues: {'is_favorite': isFavorite});
  }

  Future<void> removeFromHistory(String movieId) async {
    return removeMultipleFromHistory([movieId]);
  }

  Future<void> removeMultipleFromHistory(List<String> movieIds) async {
    final user = supabase.auth.currentUser;
    if (user == null || movieIds.isEmpty) return;

    final states = await getStates(movieIds);

    final toUpdate = <String>[];
    final toDelete = <String>[];

    for (final movieId in movieIds) {
      final dbId = _toDbId(movieId);
      if (states[movieId]?.isFavorite == true) {
        toUpdate.add(dbId);
      } else {
        toDelete.add(dbId);
      }
    }

    if (toUpdate.isNotEmpty) {
      await supabase
          .from('movie_library')
          .update({
            'watched_at': null,
            'last_episode_name': null,
            'last_server_name': null,
            'last_position_seconds': null,
          })
          .eq('user_id', user.id)
          .inFilter('movie_id', toUpdate);
    }

    if (toDelete.isNotEmpty) {
      await supabase
          .from('movie_library')
          .delete()
          .eq('user_id', user.id)
          .inFilter('movie_id', toDelete);
    }
  }

  Future<MovieResponse> _getMovies({
    bool watchedOnly = false,
    bool favoritesOnly = false,
    String searchQuery = '',
    int page = 1,
    int pageSize = 20,
    MovieLibraryBatchCallback? onBatch,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) return const MovieResponse(movies: [], total: 0);

    var query = supabase
        .from('movie_library')
        .select(
          'movie_id, movie_path, watched_at, is_favorite, updated_at, last_episode_name, last_server_name, last_position_seconds',
        );

    query = query.eq('user_id', user.id).like('movie_id', '${_scope.prefix}%');

    if (watchedOnly) {
      query = query.not('watched_at', 'is', null);
    }
    if (favoritesOnly) {
      query = query.eq('is_favorite', true);
    }

    final from = (page - 1) * pageSize;
    final to = from + pageSize - 1;

    final response = await query
        .order(watchedOnly ? 'watched_at' : 'updated_at', ascending: false)
        .range(from, to);

    // In Supabase Dart 2.x, to get the total count without fetching everything,
    // we can either perform a separate count query or use a custom converter/header.
    // However, the easiest way for personal collections is often to fetch the
    // count separately if the library is small, or use the response object if
    // we can access the underlying PostgrestResponse.

    // Let's get the count separately to be safe and clean.
    final countQuery = supabase
        .from('movie_library')
        .select('movie_id')
        .eq('user_id', user.id)
        .like('movie_id', '${_scope.prefix}%');

    final countResponse =
        await (watchedOnly
                ? countQuery.not('watched_at', 'is', null)
                : favoritesOnly
                ? countQuery.eq('is_favorite', true)
                : countQuery)
            .count(CountOption.exact);

    final List<dynamic> rows = response as List<dynamic>;
    final totalCount = countResponse.count;

    final normalizedQuery = searchQuery.trim().toLowerCase();
    final items = <MovieLibraryItem>[];
    const hydrationBatchSize = 3;

    for (var offset = 0; offset < rows.length; offset += hydrationBatchSize) {
      final end = (offset + hydrationBatchSize).clamp(0, rows.length);
      final batch = rows.sublist(offset, end);
      final hydrated = await Future.wait(
        batch.map((row) => _hydrateMovie(row as Map<String, dynamic>)),
      );
      final visibleItems = hydrated
          .whereType<MovieLibraryItem>()
          .where(
            (item) =>
                normalizedQuery.isEmpty ||
                item.movie.title.toLowerCase().contains(normalizedQuery),
          )
          .toList();
      items.addAll(visibleItems);
      if (visibleItems.isNotEmpty) onBatch?.call(visibleItems);
    }

    return MovieResponse(
      movies: items.map((item) => item.movie).toList(),
      total: totalCount,
    );
  }

  Future<MovieLibraryItem?> _hydrateMovie(Map<String, dynamic> row) async {
    final dbId = row['movie_id'] as String? ?? '';
    final moviePath = row['movie_path'] as String? ?? '';
    if (dbId.isEmpty || moviePath.isEmpty) return null;

    final movieId = _fromDbId(dbId);
    final state = (
      isFavorite: row['is_favorite'] as bool? ?? false,
      watchedAt: DateTime.tryParse(row['watched_at'] as String? ?? ''),
      lastEpisodeName: row['last_episode_name'] as String?,
      lastServerName: row['last_server_name'] as String?,
      lastPositionSeconds: row['last_position_seconds'] as int?,
    );

    final movieUrl = movieService.resolveServerPath(moviePath);
    final detail = await movieService.getMovieDetail(
      movieUrl,
      movieId,
      includeStream: false,
    );
    if (detail == null) {
      return (
        movie: Movie(
          id: movieId,
          title: 'Phim #$movieId',
          url: movieUrl,
          poster: '',
        ),
        state: state,
      );
    }
    return (
      movie: Movie(
        id: movieId,
        title: detail.title,
        originalTitle: detail.originalTitle,
        url: movieUrl,
        poster: detail.poster,
        views: detail.views,
        likes: detail.likes,
        hasVietsub: detail.hasVietsub,
        description: detail.description,
      ),
      state: state,
    );
  }

  Future<void> _upsertMovie(
    Movie movie, {
    required Map<String, dynamic> extraValues,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null || movie.id.isEmpty || movie.url.isEmpty) {
      logger.d('MovieLibraryService: Skip upsert (user=$user, id=${movie.id})');
      return;
    }

    try {
      final data = {
        'user_id': user.id,
        'movie_id': _toDbId(movie.id),
        'movie_path': movieService.toServerPath(movie.url),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        ...extraValues,
      };
      logger.d('MovieLibraryService: Upserting $data');
      await supabase
          .from('movie_library')
          .upsert(data, onConflict: 'user_id,movie_id');
    } catch (e, s) {
      logger.e('MovieLibraryService: Upsert failed', error: e, stackTrace: s);
    }
  }
}

const movieLibraryService = MovieLibraryService();
