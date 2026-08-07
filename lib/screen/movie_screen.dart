import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/model/movie_model.dart';
import 'package:do_x/router/app_router.gr.dart';
import 'package:do_x/services/movie_library_service.dart';
import 'package:do_x/services/movie_service.dart';
import 'package:do_x/utils/logger.dart';
import 'package:do_x/widgets/app_bar/app_bar_base.dart';
import 'package:do_x/widgets/neu/neu_card.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum _MovieCollection { browse, watched, favorites }

@RoutePage()
class MovieScreen extends StatefulWidget {
  const MovieScreen({super.key});

  @override
  State<MovieScreen> createState() => _MovieScreenState();
}

class _MovieScreenState extends State<MovieScreen> {
  final _searchController = TextEditingController();
  late final TextEditingController _serverUrlController;
  final _scrollController = ScrollController();
  Timer? _debounceTimer;

  final _cancelToken = CancelToken();

  List<MovieCategory> _categories = [];
  MovieCategory? _selectedCategory;
  final _movieIds = <String>{};
  final _libraryStates = <String, MovieLibraryState>{};
  List<Movie> _movies = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  int _currentPage = 1;
  int _totalMovies = 0;
  bool _hasMore = true;
  bool _isSyncingServer = false;
  bool _showScrollToTop = false;
  int _loadGeneration = 0;
  String _searchQuery = '';
  _MovieCollection _collection = _MovieCollection.browse;

  bool get _supportsDeviceRotation =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void initState() {
    super.initState();
    _serverUrlController = TextEditingController(
      text: movieService.baseUrl ?? '',
    );
    if (_supportsDeviceRotation) {
      unawaited(
        SystemChrome.setPreferredOrientations(DeviceOrientation.values),
      );
    }
    _initData();
    _scrollController.addListener(_onScroll);
  }

  Future<void> _initData() async {
    setState(() => _isLoading = true);
    await movieService.discoverConfig();
    _categories = movieService.getCategories();
    if (_categories.isNotEmpty) {
      _selectedCategory = _categories.first;
    }
    await _loadMovies(refresh: true);
  }

  @override
  void dispose() {
    if (_supportsDeviceRotation) {
      unawaited(
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ]),
      );
    }
    _searchController.dispose();
    _serverUrlController.dispose();
    _scrollController.dispose();
    _debounceTimer?.cancel();
    _cancelToken.cancel();
    super.dispose();
  }

  void _onScroll() {
    final position = _scrollController.position;
    final shouldShowScrollToTop = position.pixels > 240;
    if (shouldShowScrollToTop != _showScrollToTop) {
      setState(() => _showScrollToTop = shouldShowScrollToTop);
    }

    if (position.pixels >= position.maxScrollExtent - 300 &&
        !_isLoadingMore &&
        !_isLoading &&
        _hasMore) {
      _loadMoreMovies();
    }
  }

  Future<void> _scrollToTop() async {
    if (!_scrollController.hasClients) return;
    await _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _loadMovies({bool refresh = false}) async {
    final generation = ++_loadGeneration;
    final isLibraryCollection = _collection != _MovieCollection.browse;
    var receivedLibraryBatch = false;

    if (refresh) {
      setState(() {
        _isLoading = true;
        _isLoadingMore = false;
        _currentPage = 1;
        _hasMore = true;
      });
    }

    void publishLibraryBatch(List<MovieLibraryItem> items) {
      if (!mounted || generation != _loadGeneration || items.isEmpty) return;
      setState(() {
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
      });
    }

    MovieResponse response;
    try {
      if (_collection == _MovieCollection.watched) {
        final fetched = await movieLibraryService.getWatched(
          searchQuery: _searchQuery,
          onBatch: publishLibraryBatch,
        );
        response = MovieResponse(movies: fetched, total: fetched.length);
      } else if (_collection == _MovieCollection.favorites) {
        final fetched = await movieLibraryService.getFavorites(
          searchQuery: _searchQuery,
          onBatch: publishLibraryBatch,
        );
        response = MovieResponse(movies: fetched, total: fetched.length);
      } else if (_searchQuery.isNotEmpty) {
        response = await movieService.searchMovies(
          _searchQuery,
          page: _currentPage,
          cancelToken: _cancelToken,
        );
      } else if (_selectedCategory != null) {
        response = await movieService.getMoviesByCategory(
          _selectedCategory!.path,
          page: _currentPage,
          cancelToken: _cancelToken,
        );
      } else {
        response = const MovieResponse(movies: [], total: 0);
      }
    } catch (error, stackTrace) {
      logger.e(
        'MovieScreen: load movies failed',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
        _hasMore = false;
        if (refresh) {
          _movies = [];
          _movieIds.clear();
          _libraryStates.clear();
        }
      });
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.loadMoviesFailed)),
      );
      return;
    }

    if (!mounted || generation != _loadGeneration) return;
    if (isLibraryCollection) {
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
        _hasMore = false;
        _totalMovies = response.total;
        if (!receivedLibraryBatch) {
          _movies = response.movies;
          _movieIds.clear();
          _movieIds.addAll(response.movies.map((m) => m.id));
          _libraryStates.clear();
        }
      });
      return;
    }

    final fetched = response.movies;
    final states = await _loadLibraryStates(fetched.map((movie) => movie.id));
    if (!mounted || generation != _loadGeneration) return;
    setState(() {
      _isLoading = false;
      _totalMovies = response.total;
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
      _hasMore = _collection == _MovieCollection.browse && fetched.isNotEmpty;
    });
  }

  Future<void> _loadMoreMovies() async {
    if (_collection != _MovieCollection.browse || _isLoadingMore || !_hasMore) {
      return;
    }
    final generation = _loadGeneration;
    setState(() => _isLoadingMore = true);

    _currentPage++;
    MovieResponse response;
    if (_searchQuery.isNotEmpty) {
      response = await movieService.searchMovies(
        _searchQuery,
        page: _currentPage,
        cancelToken: _cancelToken,
      );
    } else if (_selectedCategory != null) {
      response = await movieService.getMoviesByCategory(
        _selectedCategory!.path,
        page: _currentPage,
        cancelToken: _cancelToken,
      );
    } else {
      response = const MovieResponse(movies: [], total: 0);
    }

    final fetched = response.movies;
    final states = await _loadLibraryStates(fetched.map((movie) => movie.id));
    if (!mounted || generation != _loadGeneration) return;
    setState(() {
      _isLoadingMore = false;
      _totalMovies = response.total;
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
    });
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      setState(() {
        _searchQuery = query.trim();
      });
      _loadMovies(refresh: true);
    });
  }

  void _selectCollection(_MovieCollection collection) {
    setState(() {
      _collection = _collection == collection
          ? _MovieCollection.browse
          : collection;
    });
    _loadMovies(refresh: true);
  }

  Future<Map<String, MovieLibraryState>> _loadLibraryStates(
    Iterable<String> movieIds,
  ) async {
    try {
      return await movieLibraryService.getStates(movieIds);
    } catch (error, stackTrace) {
      logger.e(
        'MovieScreen: load library states failed',
        error: error,
        stackTrace: stackTrace,
      );
      return {};
    }
  }

  Future<void> _refreshLibraryStates() async {
    try {
      final states = await movieLibraryService.getStates(
        _movies.map((movie) => movie.id),
      );
      if (!mounted) return;
      setState(() {
        _libraryStates
          ..clear()
          ..addAll(states);
      });
    } catch (error, stackTrace) {
      logger.e(
        'MovieScreen: refresh library states failed',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<bool> _updateMovieServer(String rawUrl) async {
    final l10n = AppLocalizations.of(context);
    if (_isSyncingServer) return false;
    final url = rawUrl.trim();
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !uri.hasAuthority ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.invalidMovieServerUrl)),
      );
      return false;
    }

    setState(() => _isSyncingServer = true);
    try {
      await movieService.updateBaseUrl(url);
      if (!mounted) return false;
      _serverUrlController.text = movieService.baseUrl ?? url;
      _categories = movieService.getCategories();
      _selectedCategory = _categories.firstOrNull;
      _collection = _MovieCollection.browse;
      _searchController.clear();
      _searchQuery = '';
      await _loadMovies(refresh: true);
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.movieServerUrlUpdated)),
      );
      return true;
    } catch (error, stackTrace) {
      logger.e(
        'MovieScreen: update server failed',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.updateMovieServerFailed)),
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _isSyncingServer = false);
    }
  }

  Future<void> _showServerUrlDialog() async {
    final l10n = AppLocalizations.of(context);
    _serverUrlController.text = movieService.baseUrl ?? '';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.movieServerUrl),
        content: TextField(
          controller: _serverUrlController,
          autofocus: true,
          keyboardType: TextInputType.url,
          decoration: InputDecoration(
            hintText: l10n.serverUrlHint,
            helperText: l10n.serverUrlHelperText,
          ),
          onSubmitted: (_) async {
            final updated = await _updateMovieServer(_serverUrlController.text);
            if (updated && dialogContext.mounted) {
              Navigator.pop(dialogContext);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () async {
              final updated = await _updateMovieServer(
                _serverUrlController.text,
              );
              if (updated && dialogContext.mounted) {
                Navigator.pop(dialogContext);
              }
            },
            child: Text(l10n.saveAndSync),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final movieLabel = movieService.getLabel();
    final baseUrl = movieService.baseUrl;
    final emptyMessage = switch (_collection) {
      _MovieCollection.watched => l10n.noWatchedMovies,
      _MovieCollection.favorites => l10n.noFavoriteMovies,
      _MovieCollection.browse => l10n.noMoviesFound,
    };

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: DoAppBar(
          title: movieLabel,
          actions: [
            IconButton(
              tooltip: l10n.changeMovieServerUrl,
              icon: const Icon(Icons.link_rounded),
              onPressed: _showServerUrlDialog,
            ),
            IconButton(
              tooltip: l10n.watchedMovies,
              color: _collection == _MovieCollection.watched
                  ? Theme.of(context).colorScheme.primary
                  : null,
              icon: const Icon(Icons.history_rounded),
              onPressed: () => _selectCollection(_MovieCollection.watched),
            ),
            IconButton(
              tooltip: l10n.favoriteMovies,
              color: _collection == _MovieCollection.favorites
                  ? Theme.of(context).colorScheme.primary
                  : null,
              icon: const Icon(Icons.favorite_rounded),
              onPressed: () => _selectCollection(_MovieCollection.favorites),
            ),
          ],
        ),
        floatingActionButton: (baseUrl == null || baseUrl.isEmpty)
            ? null
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (!_isLoading && _movies.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                              .withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          l10n.movieCountStatus(
                            _movies.length,
                            _totalMovies > 0 ? _totalMovies.toString() : '...',
                          ),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                  if (_showScrollToTop)
                    FloatingActionButton.small(
                      tooltip: l10n.scrollToTop,
                      elevation: 2,
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.72),
                      foregroundColor: Theme.of(context).colorScheme.onSurface,
                      onPressed: _scrollToTop,
                      child: const Icon(Icons.vertical_align_top_rounded),
                    ),
                ],
              ),
        body: SafeArea(
          top: false,
          bottom: false,
          child: (baseUrl == null || baseUrl.isEmpty)
              ? _buildServerConfig()
              : RefreshIndicator(
                  onRefresh: () => _loadMovies(refresh: true),
                  child: CustomScrollView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                          child: TextField(
                            controller: _searchController,
                            onChanged: _onSearchChanged,
                            decoration: InputDecoration(
                              hintText: l10n.searchMoviesPlaceholder,
                              prefixIcon: const Icon(Icons.search_rounded),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear_rounded),
                                      onPressed: () {
                                        _searchController.clear();
                                        _onSearchChanged('');
                                      },
                                    )
                                  : null,
                              isDense: true,
                              filled: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (_searchQuery.isEmpty && _categories.isNotEmpty)
                        SliverToBoxAdapter(
                          child: SizedBox(
                            height: 42,
                            child: ListView.separated(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              scrollDirection: Axis.horizontal,
                              itemCount: _categories.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(width: 8),
                              itemBuilder: (context, index) {
                                final cat = _categories[index];
                                final isSelected =
                                    _collection == _MovieCollection.browse &&
                                    cat.id == _selectedCategory?.id;
                                return ChoiceChip(
                                  label: Text(cat.name),
                                  selected: isSelected,
                                  showCheckmark: false,
                                  onSelected: (selected) {
                                    if (selected &&
                                        (_collection !=
                                                _MovieCollection.browse ||
                                            cat.id != _selectedCategory?.id)) {
                                      setState(() {
                                        _collection = _MovieCollection.browse;
                                        _selectedCategory = cat;
                                      });
                                      _loadMovies(refresh: true);
                                    }
                                  },
                                  selectedColor: Theme.of(
                                    context,
                                  ).colorScheme.primary,
                                  labelStyle: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : (isDark
                                              ? Colors.white70
                                              : Colors.black87),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      if (_searchQuery.isEmpty &&
                          _categories.isEmpty &&
                          _collection == _MovieCollection.browse)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Center(
                              child: Text(
                                l10n.noCategoriesConfigured,
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ),
                      const SliverToBoxAdapter(child: SizedBox(height: 8)),
                      if (_isLoading)
                        const SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (_movies.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.movie_outlined,
                                  size: 64,
                                  color: Colors.grey,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  emptyMessage,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(
                            16,
                            8,
                            16,
                            MediaQuery.paddingOf(context).bottom + 50,
                          ),
                          sliver: SliverGrid(
                            gridDelegate:
                                const SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: 220,
                                  childAspectRatio: 0.85,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                if (index >= _movies.length) {
                                  return const Card(
                                    child: Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  );
                                }
                                final movie = _movies[index];
                                final libraryState = _libraryStates[movie.id];
                                return _MovieCard(
                                  movie: movie,
                                  isWatched: libraryState?.watchedAt != null,
                                  isFavorite: libraryState?.isFavorite ?? false,
                                  onTap: () async {
                                    await context.pushRoute(
                                      MovieDetailRoute(
                                        movieUrl: movie.url,
                                        movieId: movie.id,
                                        initialMovie: movie,
                                      ),
                                    );
                                    if (!mounted) return;
                                    if (_collection ==
                                        _MovieCollection.browse) {
                                      await _refreshLibraryStates();
                                    } else {
                                      await _loadMovies(refresh: true);
                                    }
                                  },
                                );
                              },
                              childCount:
                                  _movies.length + (_isLoadingMore ? 2 : 0),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildServerConfig() {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.link_rounded, size: 64, color: Colors.pinkAccent),
            const SizedBox(height: 16),
            Text(
              l10n.enterMovieServerUrl,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: TextField(
                controller: _serverUrlController,
                enabled: !_isSyncingServer,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  hintText: l10n.serverUrlHint,
                  prefixIcon: const Icon(Icons.dns_rounded),
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (_) =>
                    _updateMovieServer(_serverUrlController.text),
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _isSyncingServer
                  ? null
                  : () => _updateMovieServer(_serverUrlController.text),
              icon: _isSyncingServer
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync_rounded),
              label: Text(
                _isSyncingServer ? l10n.syncing : l10n.saveAndSync,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MovieCard extends StatelessWidget {
  final Movie movie;
  final VoidCallback onTap;
  final bool isWatched;
  final bool isFavorite;

  const _MovieCard({
    required this.movie,
    required this.onTap,
    this.isWatched = false,
    this.isFavorite = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final displayBadge = movie.hasVietsub ? l10n.vietsub : movie.badge;
    return NeuCard(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl: movie.poster,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: Colors.grey.shade900,
                    child: const Center(
                      child: Icon(Icons.movie, color: Colors.white24),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey.shade800,
                    child: const Icon(
                      Icons.broken_image_rounded,
                      color: Colors.white38,
                    ),
                  ),
                ),
                if (displayBadge != null && displayBadge.isNotEmpty)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.pinkAccent.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        displayBadge,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                if (isWatched || isFavorite)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.68),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isWatched)
                            const Icon(
                              Icons.check_circle_rounded,
                              color: Colors.lightGreenAccent,
                              size: 17,
                            ),
                          if (isWatched && isFavorite) const SizedBox(width: 4),
                          if (isFavorite)
                            const Icon(
                              Icons.favorite_rounded,
                              color: Colors.pinkAccent,
                              size: 17,
                            ),
                        ],
                      ),
                    ),
                  ),
                if ((movie.views?.isNotEmpty ?? false) ||
                    (movie.likes?.isNotEmpty ?? false))
                  Positioned(
                    bottom: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (movie.views?.isNotEmpty ?? false) ...[
                            const Icon(
                              Icons.visibility_rounded,
                              size: 11,
                              color: Colors.white70,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              movie.views!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            ),
                          ],
                          if ((movie.views?.isNotEmpty ?? false) &&
                              (movie.likes?.isNotEmpty ?? false))
                            const SizedBox(width: 7),
                          if (movie.likes?.isNotEmpty ?? false) ...[
                            const Icon(
                              Icons.favorite_rounded,
                              size: 11,
                              color: Colors.pinkAccent,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              movie.likes!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              movie.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
