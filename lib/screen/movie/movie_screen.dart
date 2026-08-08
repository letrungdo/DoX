import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/model/movie_model.dart';
import 'package:do_x/screen/movie/movie_detail_screen.dart';
import 'package:do_x/screen/movie/movie_player_layout.dart';
import 'package:do_x/screen/movie/movie_poster_card.dart';
import 'package:do_x/screen/movie/movie_server_dialog.dart';
import 'package:do_x/services/movie_library_service.dart';
import 'package:do_x/services/movie_service.dart';
import 'package:do_x/utils/logger.dart';
import 'package:do_x/widgets/app_bar/app_bar_base.dart';
import 'package:do_x/widgets/neu/neu_button.dart';
import 'package:do_x/widgets/neu/neu_chip.dart';
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

/// How long the card→player zoom and the minimise/expand snap take.
const _overlayAnimationDuration = Duration(milliseconds: 300);

class _MovieScreenState extends State<MovieScreen> with SingleTickerProviderStateMixin {
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

  /// 1 = detail page fills the screen, 0 = collapsed to the mini player bar.
  late final AnimationController _overlayController;

  /// The movie the overlay is showing; `null` when no player is open.
  Movie? _playingMovie;

  /// Rect of the tapped card, used as the origin of the opening zoom. Cleared
  /// once the overlay has finished expanding.
  Rect? _entryRect;
  bool _isDetailFullScreen = false;

  /// True from the moment a drag starts on the mini bar until it ends, so the
  /// recognizer is not torn down the instant the bar stops being mini.
  bool _isDraggingMiniBar = false;
  final _detailController = MovieDetailController();

  bool get _supportsDeviceRotation =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void initState() {
    super.initState();
    _serverUrlController = TextEditingController(text: movieService.baseUrl ?? '');
    _overlayController = AnimationController(vsync: this, duration: _overlayAnimationDuration);
    if (_supportsDeviceRotation) {
      unawaited(SystemChrome.setPreferredOrientations(DeviceOrientation.values));
    }
    _initData();
    _scrollController.addListener(_onScroll);
  }

  Future<void> _initData() async {
    try {
      setState(() => _isLoading = true);
      await movieService.discoverConfig();
      _categories = movieService.getCategories();
      if (_categories.isNotEmpty) {
        _selectedCategory = _categories.first;
      }
      await _loadMovies(refresh: true);
    } catch (e, st) {
      logger.e('MovieScreen _initData failed', error: e, stackTrace: st);
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    if (_supportsDeviceRotation) {
      unawaited(SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]));
    }
    _overlayController.dispose();
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

    if (position.pixels >= position.maxScrollExtent - 300 && !_isLoadingMore && !_isLoading && _hasMore) {
      _loadMoreMovies();
    }
  }

  Future<void> _scrollToTop() async {
    if (!_scrollController.hasClients) return;
    await _scrollController.animateTo(0, duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
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
        final fetched = await movieLibraryService.getWatched(searchQuery: _searchQuery, onBatch: publishLibraryBatch);
        response = MovieResponse(movies: fetched, total: fetched.length);
      } else if (_collection == _MovieCollection.favorites) {
        final fetched = await movieLibraryService.getFavorites(searchQuery: _searchQuery, onBatch: publishLibraryBatch);
        response = MovieResponse(movies: fetched, total: fetched.length);
      } else if (_searchQuery.isNotEmpty) {
        response = await movieService.searchMovies(_searchQuery, page: _currentPage, cancelToken: _cancelToken);
      } else if (_selectedCategory != null) {
        response = await movieService.getMoviesByCategory(_selectedCategory!.path, page: _currentPage, cancelToken: _cancelToken);
      } else {
        response = const MovieResponse(movies: [], total: 0);
      }
    } catch (error, stackTrace) {
      logger.e('MovieScreen: load movies failed', error: error, stackTrace: stackTrace);
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.loadMoviesFailed)));
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
      response = await movieService.searchMovies(_searchQuery, page: _currentPage, cancelToken: _cancelToken);
    } else if (_selectedCategory != null) {
      response = await movieService.getMoviesByCategory(_selectedCategory!.path, page: _currentPage, cancelToken: _cancelToken);
    } else {
      response = const MovieResponse(movies: [], total: 0);
    }

    final fetched = response.movies;
    final states = await _loadLibraryStates(fetched.map((movie) => movie.id));
    if (!mounted || generation != _loadGeneration) return;
    setState(() {
      _isLoadingMore = false;
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
      _collection = _collection == collection ? _MovieCollection.browse : collection;
    });
    _loadMovies(refresh: true);
  }

  Future<void> _handleMovieLongPress(Movie movie) async {
    if (_collection != _MovieCollection.watched) return;

    final l10n = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.removeFromHistory),
        content: Text(l10n.confirmRemoveFromHistory(movie.title)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.delete)),
        ],
      ),
    );

    if (confirm == true) {
      await movieLibraryService.removeFromHistory(movie.id);
      if (mounted) {
        await _loadMovies(refresh: true);
      }
    }
  }

  Future<Map<String, MovieLibraryState>> _loadLibraryStates(Iterable<String> movieIds) async {
    try {
      return await movieLibraryService.getStates(movieIds);
    } catch (error, stackTrace) {
      logger.e('MovieScreen: load library states failed', error: error, stackTrace: stackTrace);
      return {};
    }
  }

  Future<void> _refreshLibraryStates() async {
    try {
      final states = await movieLibraryService.getStates(_movies.map((movie) => movie.id));
      if (!mounted) return;
      setState(() {
        _libraryStates
          ..clear()
          ..addAll(states);
      });
    } catch (error, stackTrace) {
      logger.e('MovieScreen: refresh library states failed', error: error, stackTrace: stackTrace);
    }
  }

  /// Opens [movie] in the overlay, zooming out of the card at [cardRect]
  /// instead of pushing a route, so playback survives minimising.
  Future<void> _openMovie(Movie movie, Rect cardRect) async {
    setState(() {
      _playingMovie = movie;
      _entryRect = cardRect;
      _isDetailFullScreen = false;
    });
    await _overlayController.animateTo(1, duration: _overlayAnimationDuration, curve: Curves.easeOutCubic);
    if (!mounted) return;
    setState(() => _entryRect = null);
  }

  void _minimizeOverlay() {
    _overlayController.animateTo(0, duration: _overlayAnimationDuration, curve: Curves.easeOutCubic);
  }

  void _expandOverlay() {
    _overlayController.animateTo(1, duration: _overlayAnimationDuration, curve: Curves.easeOutCubic);
  }

  Future<void> _closeOverlay() async {
    if (_playingMovie == null) return;
    setState(() {
      _playingMovie = null;
      _entryRect = null;
      _isDetailFullScreen = false;
    });
    _overlayController.value = 0;
    // The library may have gained a watch/favourite entry while it was open.
    if (_collection == _MovieCollection.browse) {
      await _refreshLibraryStates();
    } else {
      await _loadMovies(refresh: true);
    }
  }

  void _onOverlayDragUpdate(DragUpdateDetails details, double travel) {
    if (travel <= 0) return;
    _overlayController.value = (_overlayController.value - (details.primaryDelta ?? 0) / travel).clamp(0.0, 1.0);
  }

  void _onOverlayDragEnd(DragEndDetails details) {
    final velocity = details.velocity.pixelsPerSecond.dy;
    if (velocity > 400) {
      _minimizeOverlay();
    } else if (velocity < -400) {
      _expandOverlay();
    } else if (_overlayController.value > 0.5) {
      _expandOverlay();
    } else {
      _minimizeOverlay();
    }
  }

  Future<bool> _updateMovieServer(String rawUrl) async {
    final l10n = AppLocalizations.of(context);
    if (_isSyncingServer) return false;
    // `https://` is optional in the field; the service fills it in.
    final url = movieService.normalizeServerUrl(rawUrl);
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasAuthority || (uri.scheme != 'http' && uri.scheme != 'https')) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.invalidMovieServerUrl)));
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.movieServerUrlUpdated)));
      return true;
    } catch (error, stackTrace) {
      logger.e('MovieScreen: update server failed', error: error, stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.updateMovieServerFailed)));
      }
      return false;
    } finally {
      if (mounted) setState(() => _isSyncingServer = false);
    }
  }

  Future<void> _showServerUrlDialog() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => MovieServerDialog(
        onServerChanged: () {
          if (mounted) _initData();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final movieLabel = movieService.getLabel();
    final baseUrl = movieService.baseUrl;
    final emptyMessage = switch (_collection) {
      _MovieCollection.watched => l10n.noWatchedMovies,
      _MovieCollection.favorites => l10n.noFavoriteMovies,
      _MovieCollection.browse => l10n.noMoviesFound,
    };

    return PopScope(
      canPop: _playingMovie == null,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || _playingMovie == null) return;
        if (_isDetailFullScreen) {
          _detailController.exitFullScreen();
          return;
        }
        if (_overlayController.value > 0) {
          _minimizeOverlay();
        } else {
          unawaited(_closeOverlay());
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: _buildBrowser(context, emptyMessage: emptyMessage, movieLabel: movieLabel, baseUrl: baseUrl, l10n: l10n),
          ),
          if (_playingMovie != null) _buildPlayerOverlay(context, _playingMovie!),
        ],
      ),
    );
  }

  Widget _buildBrowser(
    BuildContext context, {
    required String emptyMessage,
    required String movieLabel,
    required String? baseUrl,
    required AppLocalizations l10n,
  }) {
    return Scaffold(
      appBar: DoAppBar(
        title: movieLabel,
        // The title doubles as the server picker, replacing the old link action.
        onTitleTap: _showServerUrlDialog,
        titleSuffix: Icon(Icons.expand_more_rounded, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
        actions: [
          NeuIconButton(
            size: appBarActionSize,
            iconSize: 18,
            depth: appBarActionDepth,
            tooltip: l10n.watchedMovies,
            color: _collection == _MovieCollection.watched ? Theme.of(context).colorScheme.primary : null,
            icon: Icons.history_rounded,
            onPressed: () => _selectCollection(_MovieCollection.watched),
          ),
          const SizedBox(width: 8),
          NeuIconButton(
            size: appBarActionSize,
            iconSize: 18,
            depth: appBarActionDepth,
            tooltip: l10n.favoriteMovies,
            color: _collection == _MovieCollection.favorites ? Theme.of(context).colorScheme.primary : null,
            icon: Icons.favorite_rounded,
            onPressed: () => _selectCollection(_MovieCollection.favorites),
          ),
        ],
      ),
      // Hidden while the player overlay is up so it never fights the mini bar.
      floatingActionButton: (baseUrl == null || baseUrl.isEmpty || _playingMovie != null)
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (!_isLoading && _movies.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 2))],
                      ),
                      child: Text(
                        l10n.movieCountStatus(_movies.length, _totalMovies > 0 ? _totalMovies.toString() : '...'),
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
                      ),
                    ),
                  ),
                if (_showScrollToTop)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: NeuIconButton(tooltip: l10n.scrollToTop, icon: Icons.vertical_align_top_rounded, onPressed: _scrollToTop),
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
                            fillColor: Theme.of(context).colorScheme.surface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant, width: 1),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant, width: 1),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (_searchQuery.isEmpty && _categories.isNotEmpty)
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height: 46,
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            clipBehavior: Clip.none,
                            scrollDirection: Axis.horizontal,
                            itemCount: _categories.length,
                            separatorBuilder: (_, _) => const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              final cat = _categories[index];
                              final isSelected = _collection == _MovieCollection.browse && cat.id == _selectedCategory?.id;

                              final label = switch (cat.id) {
                                'new' => l10n.categoryNew,
                                'phim-le' => l10n.categorySingle,
                                'phim-bo' => l10n.categorySeries,
                                'hoat-hinh' => l10n.categoryAnime,
                                'tv-shows' => l10n.categoryTVShow,
                                _ => cat.name,
                              };

                              return NeuChip(
                                label: label,
                                isSelected: isSelected,
                                onTap: () {
                                  if (_collection != _MovieCollection.browse || cat.id != _selectedCategory?.id) {
                                    setState(() {
                                      _collection = _MovieCollection.browse;
                                      _selectedCategory = cat;
                                    });
                                    _loadMovies(refresh: true);
                                  }
                                },
                              );
                            },
                          ),
                        ),
                      ),
                    if (_searchQuery.isEmpty && _categories.isEmpty && _collection == _MovieCollection.browse)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Center(
                            child: Text(l10n.noCategoriesConfigured, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                          ),
                        ),
                      ),
                    const SliverToBoxAdapter(child: SizedBox(height: 8)),
                    if (_isLoading)
                      const SliverFillRemaining(hasScrollBody: false, child: Center(child: CircularProgressIndicator()))
                    else if (_movies.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.movie_outlined, size: 64, color: Colors.grey),
                              const SizedBox(height: 12),
                              Text(emptyMessage, style: const TextStyle(fontSize: 16, color: Colors.grey)),
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
                          MediaQuery.paddingOf(context).bottom + 50 + (_playingMovie != null ? miniPlayerHeight + 16 : 0),
                        ),
                        sliver: SliverGrid(
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 220,
                            childAspectRatio: 1.0,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          delegate: SliverChildBuilderDelegate((context, index) {
                            if (index >= _movies.length) {
                              return const Card(child: Center(child: CircularProgressIndicator()));
                            }
                            final movie = _movies[index];
                            final libraryState = _libraryStates[movie.id];
                            return MoviePosterCard(
                              movie: movie,
                              isWatched: libraryState?.watchedAt != null,
                              isFavorite: libraryState?.isFavorite ?? false,
                              onTap: (cardRect) => _openMovie(movie, cardRect),
                              onLongPress: () => _handleMovieLongPress(movie),
                            );
                          }, childCount: _movies.length + (_isLoadingMore ? 2 : 0)),
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }

  /// The YouTube-style player: a rect that lerps between the tapped card (or
  /// the mini bar) and the whole screen, hosting the detail page inside.
  Widget _buildPlayerOverlay(BuildContext context, Movie movie) {
    final size = MediaQuery.sizeOf(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final fullRect = Offset.zero & size;
    final miniRect = Rect.fromLTWH(8, size.height - bottomInset - 8 - miniPlayerHeight, size.width - 16, miniPlayerHeight);
    final travel = fullRect.height - miniRect.height;

    return AnimatedBuilder(
      animation: _overlayController,
      builder: (context, _) {
        final t = _overlayController.value;
        final origin = _entryRect ?? miniRect;
        final rect = _isDetailFullScreen ? fullRect : Rect.lerp(origin, fullRect, t)!;
        final isMini = t < 0.02;

        return Positioned.fromRect(
          rect: rect,
          child: Material(
            elevation: t < 1 ? 12 : 0,
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(14 * (1 - t)),
            clipBehavior: Clip.antiAlias,
            child: GestureDetector(
              // Opaque so the browser list underneath never receives taps that
              // land on a gap of the overlay.
              behavior: HitTestBehavior.opaque,
              // Only the collapsed bar reacts to a tap; expanded, its own
              // widgets handle everything.
              onTap: isMini ? _expandOverlay : null,
              // Keeps working past the mini threshold once the drag has begun,
              // otherwise the recognizer would vanish mid-gesture.
              onVerticalDragStart: isMini || _isDraggingMiniBar ? (_) => _isDraggingMiniBar = true : null,
              onVerticalDragUpdate: isMini || _isDraggingMiniBar ? (details) => _onOverlayDragUpdate(details, travel) : null,
              onVerticalDragEnd: isMini || _isDraggingMiniBar
                  ? (details) {
                      _isDraggingMiniBar = false;
                      _onOverlayDragEnd(details);
                    }
                  : null,
              onVerticalDragCancel: isMini || _isDraggingMiniBar ? () => _isDraggingMiniBar = false : null,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MovieDetailScreen(
                    movieUrl: movie.url,
                    movieId: movie.id,
                    initialMovie: movie,
                    embedded: true,
                    minimizeProgress: t,
                    controller: _detailController,
                    onFullScreenChanged: (isFullScreen) {
                      if (mounted) setState(() => _isDetailFullScreen = isFullScreen);
                    },
                    onRelatedMovieTap: (related) => setState(() => _playingMovie = related),
                    onClose: () => unawaited(_closeOverlay()),
                    onMinimize: _minimizeOverlay,
                    onPlayerDragUpdate: (details) => _onOverlayDragUpdate(details, travel),
                    onPlayerDragEnd: _onOverlayDragEnd,
                  ),
                  // The tapped poster, fading out over the page it grew from.
                  if (_entryRect != null && t < 1)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Opacity(
                          opacity: 1 - t,
                          child: CachedNetworkImage(imageUrl: movie.poster, fit: BoxFit.cover),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
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
                onSubmitted: (_) => _updateMovieServer(_serverUrlController.text),
              ),
            ),
            const SizedBox(height: 14),
            NeuButton(
              onPressed: _isSyncingServer ? null : () => _updateMovieServer(_serverUrlController.text),
              accent: Theme.of(context).colorScheme.primary,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isSyncingServer)
                    const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  else
                    const Icon(Icons.sync_rounded),
                  const SizedBox(width: 8),
                  Text(_isSyncingServer ? l10n.syncing : l10n.saveAndSync),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
