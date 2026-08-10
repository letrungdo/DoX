import 'dart:async';

import 'package:do_x/model/movie_model.dart';
import 'package:do_x/repository/client/error_handler.dart';
import 'package:do_x/services/movie_library_service.dart';
import 'package:do_x/services/movie_service.dart';
import 'package:do_x/utils/logger.dart';
import 'package:do_x/view_model/core/core_view_model.dart';

enum MovieCollection { browse, watched, favorites }

class MovieViewModel extends CoreViewModel {
  List<MovieCategory> _categories = [];
  List<MovieCategory> get categories => _categories;

  MovieCategory? _selectedCategory;
  MovieCategory? get selectedCategory => _selectedCategory;

  MovieCategory? _selectedGenre;
  MovieCategory? get selectedGenre => _selectedGenre;

  MovieCategory? _selectedCountry;
  MovieCategory? get selectedCountry => _selectedCountry;

  List<Movie> _movies = [];
  List<Movie> get movies => _movies;

  final Set<String> _movieIds = {};
  final Map<String, MovieLibraryState> _libraryStates = {};
  Map<String, MovieLibraryState> get libraryStates => _libraryStates;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  bool _isFetching = false;
  bool get isFetching => _isFetching;

  bool _isLoadingMore = false;
  bool get isLoadingMore => _isLoadingMore;

  int _currentPage = 1;
  int _totalMovies = 0;
  int get totalMovies => _totalMovies;

  bool _hasMore = true;
  bool get hasMore => _hasMore;

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  MovieCollection _collection = MovieCollection.browse;
  MovieCollection get collection => _collection;

  int _loadGeneration = 0;

  static const genrePrefix = 'genre_';
  static const countryPrefix = 'country_';

  List<MovieCategory> get mainCategories => _categories
      .where(
        (cat) =>
            !cat.id.startsWith(genrePrefix) &&
            !cat.id.startsWith(countryPrefix),
      )
      .toList();

  List<MovieCategory> get genreCategories =>
      _categories.where((cat) => cat.id.startsWith(genrePrefix)).toList();

  List<MovieCategory> get countryCategories =>
      _categories.where((cat) => cat.id.startsWith(countryPrefix)).toList();

  @override
  void initData() {
    super.initData();
    _initData();
  }

  Future<void> _initData() async {
    try {
      _isLoading = true;
      notifyListenersSafe();
      await movieService.discoverConfig();
      _categories = movieService.getCategories();
      _selectedCategory = mainCategories.firstOrNull ?? _categories.firstOrNull;
      _selectedGenre = null;
      _selectedCountry = null;
      await loadMovies(refresh: true);
    } catch (e, st) {
      logger.e('MovieViewModel _initData failed', error: e, stackTrace: st);
      _isLoading = false;
      notifyListenersSafe();
    }
  }

  Future<void> loadMovies({bool refresh = false, bool silent = false}) async {
    final generation = ++_loadGeneration;
    final isLibraryCollection = _collection != MovieCollection.browse;
    var receivedLibraryBatch = false;

    _isFetching = true;
    if (refresh) {
      _isLoading = !silent;
      _isLoadingMore = false;
      _currentPage = 1;
      _hasMore = true;
    }
    notifyListenersSafe();

    void publishLibraryBatch(List<MovieLibraryItem> items) {
      if (generation != _loadGeneration || items.isEmpty) return;
      if (!receivedLibraryBatch) {
        _movies = [];
        _movieIds.clear();
        _libraryStates.clear();
        receivedLibraryBatch = true;
      }
      for (final item in items) {
        if (_movieIds.add(item.movie.id)) _movies.add(item.movie);
        _libraryStates[item.movie.id] = item.state;
      }
      _isLoading = false;
      _isLoadingMore = true;
      notifyListenersSafe();
    }

    final result = await Result.guardFuture<MovieResponse>(() async {
      if (_collection == MovieCollection.watched) {
        return await movieLibraryService.getWatched(
          searchQuery: _searchQuery,
          page: _currentPage,
          onBatch: publishLibraryBatch,
        );
      }
      if (_collection == MovieCollection.favorites) {
        return await movieLibraryService.getFavorites(
          searchQuery: _searchQuery,
          page: _currentPage,
          onBatch: publishLibraryBatch,
        );
      }
      if (_searchQuery.isNotEmpty) {
        return movieService.searchMovies(
          _searchQuery,
          page: _currentPage,
          cancelToken: cancelToken,
        );
      }
      if (_selectedCategory != null) {
        return movieService.getMoviesByCategory(
          _selectedCategory!.path,
          page: _currentPage,
          genreSlug: _filterSlug(_selectedGenre, genrePrefix),
          countrySlug: _filterSlug(_selectedCountry, countryPrefix),
          cancelToken: cancelToken,
        );
      }
      return const MovieResponse(movies: [], total: 0);
    });

    if (generation != _loadGeneration) return;

    final error = result.error;
    if (error != null) {
      _isFetching = false;
      _isLoading = false;
      _isLoadingMore = false;
      _hasMore = false;
      if (refresh) {
        _movies = [];
        _movieIds.clear();
        _libraryStates.clear();
      }
      notifyListenersSafe();
      if (!result.isCancelByUser && context.mounted) {
        showAppError(context, error, onRetry: () => loadMovies(refresh: true));
      }
      return;
    }

    final response = result.data ?? const MovieResponse(movies: [], total: 0);
    if (isLibraryCollection) {
      _isFetching = false;
      _isLoading = false;
      _isLoadingMore = false;
      _hasMore = response.movies.isNotEmpty;
      _totalMovies = response.total;
      if (refresh) {
        if (!receivedLibraryBatch) {
          _movies = response.movies;
          _movieIds.clear();
          _movieIds.addAll(response.movies.map((m) => m.id));
          _libraryStates.clear();
        }
      } else {
        final newMovies = response.movies
            .where((m) => _movieIds.add(m.id))
            .toList();
        _movies.addAll(newMovies);
      }
      notifyListenersSafe();
      return;
    }

    final fetched = response.movies;
    final states = await _loadLibraryStates(fetched.map((movie) => movie.id));
    if (generation != _loadGeneration) return;

    _isFetching = false;
    _isLoading = false;
    if (response.total > 0) {
      _totalMovies = response.total;
    } else if (refresh) {
      _totalMovies = fetched.length;
    }

    if (refresh) {
      _movies = fetched;
      _movieIds.clear();
      _movieIds.addAll(fetched.map((m) => m.id));
      _libraryStates
        ..clear()
        ..addAll(states);
    } else {
      final newMovies = fetched.where((m) => _movieIds.add(m.id)).toList();
      _movies.addAll(newMovies);
      _libraryStates.addAll(states);
    }
    _hasMore = _collection == MovieCollection.browse && fetched.isNotEmpty;
    notifyListenersSafe();
  }

  Future<void> loadMoreMovies() async {
    if (_isLoadingMore || !_hasMore) {
      return;
    }
    final generation = _loadGeneration;
    _isLoadingMore = true;
    _isFetching = true;
    notifyListenersSafe();

    _currentPage++;

    final isLibraryCollection = _collection != MovieCollection.browse;
    var receivedLibraryBatch = false;

    void publishLibraryBatch(List<MovieLibraryItem> items) {
      if (generation != _loadGeneration || items.isEmpty) return;
      for (final item in items) {
        if (_movieIds.add(item.movie.id)) _movies.add(item.movie);
        _libraryStates[item.movie.id] = item.state;
      }
      receivedLibraryBatch = true;
      notifyListenersSafe();
    }

    final result = await Result.guardFuture<MovieResponse>(() async {
      if (_collection == MovieCollection.watched) {
        return await movieLibraryService.getWatched(
          searchQuery: _searchQuery,
          page: _currentPage,
          onBatch: publishLibraryBatch,
        );
      }
      if (_collection == MovieCollection.favorites) {
        return await movieLibraryService.getFavorites(
          searchQuery: _searchQuery,
          page: _currentPage,
          onBatch: publishLibraryBatch,
        );
      }
      if (_searchQuery.isNotEmpty) {
        return movieService.searchMovies(
          _searchQuery,
          page: _currentPage,
          cancelToken: cancelToken,
        );
      }
      if (_selectedCategory != null) {
        return movieService.getMoviesByCategory(
          _selectedCategory!.path,
          page: _currentPage,
          genreSlug: _filterSlug(_selectedGenre, genrePrefix),
          countrySlug: _filterSlug(_selectedCountry, countryPrefix),
          cancelToken: cancelToken,
        );
      }
      return const MovieResponse(movies: [], total: 0);
    });

    if (generation != _loadGeneration) return;
    if (result.isError) {
      _isLoadingMore = false;
      _isFetching = false;
      _hasMore = false;
      notifyListenersSafe();
      return;
    }

    final response = result.data ?? const MovieResponse(movies: [], total: 0);

    if (isLibraryCollection) {
      _isLoadingMore = false;
      _isFetching = false;
      _hasMore = response.movies.isNotEmpty;
      if (!receivedLibraryBatch) {
        final newMovies = response.movies
            .where((m) => _movieIds.add(m.id))
            .toList();
        _movies.addAll(newMovies);
      }
      notifyListenersSafe();
      return;
    }

    final fetched = response.movies;
    final states = await _loadLibraryStates(fetched.map((movie) => movie.id));
    if (generation != _loadGeneration) return;

    _isLoadingMore = false;
    _isFetching = false;
    if (response.total > 0) {
      _totalMovies = response.total;
    }

    if (fetched.isEmpty) {
      _hasMore = false;
    } else {
      final newMovies = fetched.where((m) => _movieIds.add(m.id)).toList();
      _movies.addAll(newMovies);
      _libraryStates.addAll(states);
      if (newMovies.isEmpty) {
        _hasMore = false;
      }
    }
    notifyListenersSafe();
  }

  Future<Map<String, MovieLibraryState>> _loadLibraryStates(
    Iterable<String> movieIds,
  ) async {
    try {
      return await movieLibraryService.getStates(movieIds);
    } catch (error, stackTrace) {
      logger.e(
        'MovieViewModel: load library states failed',
        error: error,
        stackTrace: stackTrace,
      );
      return {};
    }
  }

  Future<void> refreshLibraryStates() async {
    try {
      final states = await movieLibraryService.getStates(
        _movies.map((movie) => movie.id),
      );
      _libraryStates
        ..clear()
        ..addAll(states);
      notifyListenersSafe();
    } catch (error, stackTrace) {
      logger.e(
        'MovieViewModel: refresh library states failed',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  void setSearchQuery(String query) {
    _searchQuery = query.trim();
    loadMovies(refresh: true);
  }

  void setCollection(MovieCollection collection) {
    _collection = _collection == collection
        ? MovieCollection.browse
        : collection;
    loadMovies(refresh: true);
  }

  void setCategory(MovieCategory? category) {
    final target = category ?? mainCategories.firstOrNull;
    if (_collection == MovieCollection.browse &&
        target?.id == _selectedCategory?.id) {
      return;
    }
    _collection = MovieCollection.browse;
    _selectedCategory = target;
    loadMovies(refresh: true);
  }

  void setFilter({MovieCategory? category, required bool isCountry}) {
    _collection = MovieCollection.browse;
    if (isCountry) {
      _selectedCountry = category;
    } else {
      _selectedGenre = category;
    }
    loadMovies(refresh: true);
  }

  Future<bool> updateMovieServer(String url) async {
    try {
      await movieService.updateBaseUrl(url);
      _categories = movieService.getCategories();
      _selectedCategory = mainCategories.firstOrNull ?? _categories.firstOrNull;
      _collection = MovieCollection.browse;
      _selectedGenre = null;
      _selectedCountry = null;
      _searchQuery = '';
      await loadMovies(refresh: true);
      return true;
    } catch (e) {
      return false;
    }
  }

  String? _filterSlug(MovieCategory? category, String prefix) {
    if (category == null) return null;
    return category.id.startsWith(prefix)
        ? category.id.substring(prefix.length)
        : category.id;
  }
}
