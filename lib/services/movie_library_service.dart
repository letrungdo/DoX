import 'package:do_x/model/movie_model.dart';
import 'package:do_x/services/movie_service.dart';
import 'package:do_x/services/supabase_service.dart';

typedef MovieLibraryState = ({bool isFavorite, DateTime? watchedAt});
typedef MovieLibraryItem = ({Movie movie, MovieLibraryState state});
typedef MovieLibraryBatchCallback = void Function(List<MovieLibraryItem> items);

class MovieLibraryService {
  const MovieLibraryService();

  MovieLibraryScope get _scope => movieService.isPrimaryServer ? MovieLibraryScope.primary : MovieLibraryScope.external;

  String _toDbId(String movieId) => _scope.toDbId(movieId);

  String _fromDbId(String dbId) => MovieLibraryScope.stripPrefix(dbId);

  Future<MovieLibraryState> getState(String movieId) async {
    final user = supabase.auth.currentUser;
    if (user == null) return (isFavorite: false, watchedAt: null);

    final row = await supabase
        .from('movie_library')
        .select('is_favorite, watched_at')
        .eq('user_id', user.id)
        .eq('movie_id', _toDbId(movieId))
        .maybeSingle();

    return (isFavorite: row?['is_favorite'] as bool? ?? false, watchedAt: DateTime.tryParse(row?['watched_at'] as String? ?? ''));
  }

  Future<Map<String, MovieLibraryState>> getStates(Iterable<String> movieIds) async {
    final user = supabase.auth.currentUser;
    final ids = movieIds.where((id) => id.isNotEmpty).map(_toDbId).toSet().toList();
    if (user == null || ids.isEmpty) return {};

    final rows = await supabase
        .from('movie_library')
        .select('movie_id, is_favorite, watched_at')
        .eq('user_id', user.id)
        .inFilter('movie_id', ids);

    return {
      for (final row in rows)
        if ((row['movie_id'] as String? ?? '').isNotEmpty)
          _fromDbId(row['movie_id'] as String): (
            isFavorite: row['is_favorite'] as bool? ?? false,
            watchedAt: DateTime.tryParse(row['watched_at'] as String? ?? ''),
          ),
    };
  }

  Future<List<Movie>> getWatched({String searchQuery = '', MovieLibraryBatchCallback? onBatch}) {
    return _getMovies(watchedOnly: true, searchQuery: searchQuery, onBatch: onBatch);
  }

  Future<List<Movie>> getFavorites({String searchQuery = '', MovieLibraryBatchCallback? onBatch}) {
    return _getMovies(favoritesOnly: true, searchQuery: searchQuery, onBatch: onBatch);
  }

  Future<void> markWatched(Movie movie) {
    return _upsertMovie(movie, extraValues: {'watched_at': DateTime.now().toUtc().toIso8601String()});
  }

  Future<void> setFavorite(Movie movie, bool isFavorite) {
    return _upsertMovie(movie, extraValues: {'is_favorite': isFavorite});
  }

  Future<void> removeFromHistory(String movieId) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final dbId = _toDbId(movieId);
    final state = await getState(movieId);
    if (state.isFavorite) {
      await supabase.from('movie_library').update({'watched_at': null}).eq('user_id', user.id).eq('movie_id', dbId);
    } else {
      await supabase.from('movie_library').delete().eq('user_id', user.id).eq('movie_id', dbId);
    }
  }

  Future<List<Movie>> _getMovies({
    bool watchedOnly = false,
    bool favoritesOnly = false,
    String searchQuery = '',
    MovieLibraryBatchCallback? onBatch,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) return [];

    var query = supabase
        .from('movie_library')
        .select('movie_id, movie_path, watched_at, is_favorite, updated_at')
        .eq('user_id', user.id)
        .like('movie_id', '${_scope.prefix}%');

    if (watchedOnly) {
      query = query.not('watched_at', 'is', null);
    }
    if (favoritesOnly) {
      query = query.eq('is_favorite', true);
    }

    final rows = await query.order(watchedOnly ? 'watched_at' : 'updated_at', ascending: false);
    final normalizedQuery = searchQuery.trim().toLowerCase();
    final items = <MovieLibraryItem>[];
    const hydrationBatchSize = 3;

    for (var offset = 0; offset < rows.length; offset += hydrationBatchSize) {
      final end = (offset + hydrationBatchSize).clamp(0, rows.length);
      final batch = rows.sublist(offset, end);
      final hydrated = await Future.wait(batch.map(_hydrateMovie));
      final visibleItems = hydrated
          .whereType<MovieLibraryItem>()
          .where((item) => normalizedQuery.isEmpty || item.movie.title.toLowerCase().contains(normalizedQuery))
          .toList();
      items.addAll(visibleItems);
      if (visibleItems.isNotEmpty) onBatch?.call(visibleItems);
    }

    return items.map((item) => item.movie).toList();
  }

  Future<MovieLibraryItem?> _hydrateMovie(Map<String, dynamic> row) async {
    final dbId = row['movie_id'] as String? ?? '';
    final moviePath = row['movie_path'] as String? ?? '';
    if (dbId.isEmpty || moviePath.isEmpty) return null;

    final movieId = _fromDbId(dbId);
    final state = (isFavorite: row['is_favorite'] as bool? ?? false, watchedAt: DateTime.tryParse(row['watched_at'] as String? ?? ''));

    final movieUrl = movieService.resolveServerPath(moviePath);
    final detail = await movieService.getMovieDetail(movieUrl, movieId, includeStream: false);
    if (detail == null) {
      return (movie: Movie(id: movieId, title: 'Phim #$movieId', url: movieUrl, poster: ''), state: state);
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

  Future<void> _upsertMovie(Movie movie, {required Map<String, dynamic> extraValues}) async {
    final user = supabase.auth.currentUser;
    if (user == null || movie.id.isEmpty || movie.url.isEmpty) return;

    await supabase.from('movie_library').upsert({
      'user_id': user.id,
      'movie_id': _toDbId(movie.id),
      'movie_path': movieService.toServerPath(movie.url),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      ...extraValues,
    }, onConflict: 'user_id,movie_id');
  }
}

const movieLibraryService = MovieLibraryService();
