import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/extensions/widget_extensions.dart';
import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/model/movie_model.dart';
import 'package:do_x/repository/client/api_dialog.dart';
import 'package:do_x/repository/client/error_handler.dart';
import 'package:do_x/screen/movie/movie_detail_screen.dart';
import 'package:do_x/screen/movie/movie_filter_sheet.dart';
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

/// How long the search field takes to slide in and out.
const _searchAnimationDuration = Duration(milliseconds: 260);

/// Centre of the search field's prefix icon in body coordinates: the field's
/// 16px side padding and 8px top padding, plus the prefix slot inside it. Used
/// as the landing point of the icon flying down from the app bar.
const _searchPrefixCenter = Offset(40, 32);

/// Fixed heights of the two filter rows, needed so the pinned header knows its
/// extent up front.
const _filterRowHeight = 48.0;
const _categoryRowHeight = 46.0;

class _MovieScreenState extends State<MovieScreen> with TickerProviderStateMixin {
  final _searchController = TextEditingController();
  late final TextEditingController _serverUrlController;
  final _scrollController = ScrollController();
  Timer? _debounceTimer;

  final _cancelToken = CancelToken();

  List<MovieCategory> _categories = [];
  MovieCategory? _selectedCategory;

  /// Extra Ophim filters, applied on top of [_selectedCategory] and each other.
  MovieCategory? _selectedGenre;
  MovieCategory? _selectedCountry;

  /// The search field sits above the list and is only laid out while toggled on.
  bool _isSearchOpen = false;
  final _searchFocusNode = FocusNode();
  final _collectionMenuKey = GlobalKey();
  final _searchButtonKey = GlobalKey();
  final _bodyKey = GlobalKey();

  /// 0 = search closed, 1 = field fully open. Drives the field's height, the
  /// fade, and the icon that flies from the app bar down into the field.
  late final AnimationController _searchAnimation;

  /// Where the app bar's search button sits in body coordinates, captured when
  /// the animation starts so the flying icon knows where to take off from.
  Offset? _searchIconOrigin;

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

  static const _genrePrefix = 'genre_';
  static const _countryPrefix = 'country_';

  /// Categories shown as the always-visible chip row (everything that is not a
  /// genre or a country, which get their own picker buttons instead).
  List<MovieCategory> get _mainCategories =>
      _categories.where((cat) => !cat.id.startsWith(_genrePrefix) && !cat.id.startsWith(_countryPrefix)).toList();

  List<MovieCategory> get _genreCategories => _categories.where((cat) => cat.id.startsWith(_genrePrefix)).toList();

  List<MovieCategory> get _countryCategories => _categories.where((cat) => cat.id.startsWith(_countryPrefix)).toList();

  /// `genre_hanh-dong` → `hanh-dong`, the slug the API filters expect.
  String? _filterSlug(MovieCategory? category, String prefix) {
    if (category == null) return null;
    return category.id.startsWith(prefix) ? category.id.substring(prefix.length) : category.id;
  }

  /// Only the primary (Ophim) server exposes genre / country listings.
  bool get _showFilterButtons => movieService.isPrimaryServer && (_genreCategories.isNotEmpty || _countryCategories.isNotEmpty);

  /// Portrait pins the filter / category rows under the app bar — there is
  /// height to spare and they stay reachable while scrolling. Landscape is short
  /// enough that a pinned header would eat the list, so there they scroll away.
  bool _isFilterHeaderPinned(BuildContext context) {
    return _filterHeaderHeight > 0 && MediaQuery.orientationOf(context) == Orientation.portrait;
  }

  /// Height of the filter / category header, 0 when it is not shown. The pull
  /// to refresh indicator uses it to drop below the pinned rows.
  double get _filterHeaderHeight {
    if (_searchQuery.isNotEmpty) return 0;
    return (_showFilterButtons ? _filterRowHeight : 0) + (_mainCategories.isNotEmpty ? _categoryRowHeight : 0);
  }

  bool get _supportsDeviceRotation =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void initState() {
    super.initState();
    _serverUrlController = TextEditingController(text: movieService.baseUrl ?? '');
    _overlayController = AnimationController(vsync: this, duration: _overlayAnimationDuration);
    _searchAnimation = AnimationController(vsync: this, duration: _searchAnimationDuration);
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
      _selectedCategory = _mainCategories.firstOrNull ?? _categories.firstOrNull;
      _selectedGenre = null;
      _selectedCountry = null;
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
    _searchAnimation.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
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

  /// [silent] keeps the centre spinner away for a pull to refresh, where the
  /// refresh indicator is already saying the same thing.
  Future<void> _loadMovies({bool refresh = false, bool silent = false}) async {
    final generation = ++_loadGeneration;
    final isLibraryCollection = _collection != _MovieCollection.browse;
    var receivedLibraryBatch = false;

    if (refresh) {
      setState(() {
        _isLoading = !silent;
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

    final result = await Result.guardFuture<MovieResponse>(() async {
      if (_collection == _MovieCollection.watched) {
        final fetched = await movieLibraryService.getWatched(searchQuery: _searchQuery, onBatch: publishLibraryBatch);
        return MovieResponse(movies: fetched, total: fetched.length);
      }
      if (_collection == _MovieCollection.favorites) {
        final fetched = await movieLibraryService.getFavorites(searchQuery: _searchQuery, onBatch: publishLibraryBatch);
        return MovieResponse(movies: fetched, total: fetched.length);
      }
      if (_searchQuery.isNotEmpty) {
        return movieService.searchMovies(_searchQuery, page: _currentPage, cancelToken: _cancelToken);
      }
      if (_selectedCategory != null) {
        return movieService.getMoviesByCategory(
          _selectedCategory!.path,
          page: _currentPage,
          genreSlug: _filterSlug(_selectedGenre, _genrePrefix),
          countrySlug: _filterSlug(_selectedCountry, _countryPrefix),
          cancelToken: _cancelToken,
        );
      }
      return const MovieResponse(movies: [], total: 0);
    });

    if (!mounted || generation != _loadGeneration) return;

    final error = result.error;
    if (error != null) {
      if (result.isCancelByUser) return;
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
      // Tells the user it is the connection, not an empty catalogue.
      unawaited(ApiDialog.showAppError(context, error, onRetry: () => _loadMovies(refresh: true)));
      return;
    }

    final response = result.data ?? const MovieResponse(movies: [], total: 0);
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
    final result = await Result.guardFuture<MovieResponse>(() async {
      if (_searchQuery.isNotEmpty) {
        return movieService.searchMovies(_searchQuery, page: _currentPage, cancelToken: _cancelToken);
      }
      if (_selectedCategory != null) {
        return movieService.getMoviesByCategory(
          _selectedCategory!.path,
          page: _currentPage,
          genreSlug: _filterSlug(_selectedGenre, _genrePrefix),
          countrySlug: _filterSlug(_selectedCountry, _countryPrefix),
          cancelToken: _cancelToken,
        );
      }
      return const MovieResponse(movies: [], total: 0);
    });

    if (!mounted || generation != _loadGeneration) return;
    // A failed page just stops the infinite scroll; the list already on screen
    // stays usable, so there is nothing worth interrupting the user for.
    if (result.isError) {
      setState(() {
        _isLoadingMore = false;
        _hasMore = false;
      });
      return;
    }

    final response = result.data ?? const MovieResponse(movies: [], total: 0);
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

  void _selectCategory(MovieCategory? category) {
    final target = category ?? _mainCategories.firstOrNull;
    if (_collection == _MovieCollection.browse && target?.id == _selectedCategory?.id) return;
    setState(() {
      _collection = _MovieCollection.browse;
      _selectedCategory = target;
    });
    _loadMovies(refresh: true);
  }

  /// Opens the country or genre sheet; the other filter is left untouched so
  /// both can be active at once.
  Future<void> _showFilterSheet({required String title, required List<MovieCategory> options, required bool isCountry}) async {
    final current = isCountry ? _selectedCountry : _selectedGenre;
    final result = await MovieFilterSheet.show(context, title: title, options: options, selectedId: current?.id);
    if (result == null || !mounted) return;
    if (result.category?.id == current?.id) return;

    setState(() {
      _collection = _MovieCollection.browse;
      if (isCountry) {
        _selectedCountry = result.category;
      } else {
        _selectedGenre = result.category;
      }
    });
    _loadMovies(refresh: true);
  }

  Future<void> _showCollectionMenu() async {
    final l10n = AppLocalizations.of(context);
    final button = _collectionMenuKey.currentContext?.findRenderObject() as RenderBox?;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (button == null || overlay == null) return;

    final topLeft = button.localToGlobal(Offset.zero, ancestor: overlay);
    final position = RelativeRect.fromRect(
      Rect.fromPoints(topLeft, topLeft + button.size.bottomRight(Offset.zero)),
      Offset.zero & overlay.size,
    );

    final scheme = Theme.of(context).colorScheme;
    PopupMenuItem<_MovieCollection> item(_MovieCollection collection, IconData icon, String label) {
      final isActive = _collection == collection;
      return PopupMenuItem(
        value: collection,
        child: Row(
          children: [
            Icon(icon, size: 20, color: isActive ? scheme.primary : null),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label, style: TextStyle(color: isActive ? scheme.primary : null)),
            ),
            if (isActive) Icon(Icons.check_rounded, size: 18, color: scheme.primary),
          ],
        ),
      );
    }

    final selected = await showMenu<_MovieCollection>(
      context: context,
      position: position,
      items: [
        item(_MovieCollection.watched, Icons.history_rounded, l10n.watchedMovies),
        item(_MovieCollection.favorites, Icons.favorite_rounded, l10n.favoriteMovies),
      ],
    );
    if (selected == null || !mounted) return;
    _selectCollection(selected);
  }

  /// Positions the app bar's search button in the body's coordinate space, so
  /// the flying icon can start exactly where the button is.
  void _captureSearchIconOrigin() {
    final button = _searchButtonKey.currentContext?.findRenderObject() as RenderBox?;
    final body = _bodyKey.currentContext?.findRenderObject() as RenderBox?;
    if (button == null || body == null) return;
    _searchIconOrigin = body.globalToLocal(button.localToGlobal(button.size.center(Offset.zero)));
  }

  void _toggleSearch() {
    _captureSearchIconOrigin();
    if (_isSearchOpen) {
      _debounceTimer?.cancel();
      _searchController.clear();
      final hadQuery = _searchQuery.isNotEmpty;
      setState(() {
        _isSearchOpen = false;
        _searchQuery = '';
      });
      _searchAnimation.reverse();
      FocusScope.of(context).unfocus();
      // Nothing was searched, so the list on screen is already the right one.
      if (hadQuery) _loadMovies(refresh: true);
      return;
    }
    setState(() => _isSearchOpen = true);
    _searchAnimation.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) => _searchFocusNode.requestFocus());
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
      ).dialogConstrainedBox(),
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
      _selectedCategory = _mainCategories.firstOrNull ?? _categories.firstOrNull;
      _collection = _MovieCollection.browse;
      _selectedGenre = null;
      _selectedCountry = null;
      _searchController.clear();
      _searchQuery = '';
      _isSearchOpen = false;
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
            key: _searchButtonKey,
            size: appBarActionSize,
            iconSize: 18,
            depth: appBarActionDepth,
            tooltip: l10n.searchMoviesPlaceholder,
            color: _isSearchOpen ? Theme.of(context).colorScheme.primary : null,
            icon: _isSearchOpen ? Icons.close_rounded : Icons.search_rounded,
            onPressed: _toggleSearch,
          ),
          const SizedBox(width: 8),
          NeuIconButton(
            key: _collectionMenuKey,
            size: appBarActionSize,
            iconSize: 18,
            depth: appBarActionDepth,
            color: _collection != _MovieCollection.browse ? Theme.of(context).colorScheme.primary : null,
            icon: Icons.more_vert_rounded,
            onPressed: _showCollectionMenu,
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
      body: Stack(
        key: _bodyKey,
        // The icon takes off from inside the app bar, above the body's bounds.
        clipBehavior: Clip.none,
        children: [
          Column(
            children: [
              // Grows and shrinks in place, so the list below slides down
              // instead of jumping when the field appears.
              _buildSearchField(l10n),
              Expanded(
                child: _buildBrowserBody(context, emptyMessage: emptyMessage, baseUrl: baseUrl, l10n: l10n),
              ),
            ],
          ),
          _buildFlyingSearchIcon(),
        ],
      ),
    );
  }

  Widget _buildBrowserBody(BuildContext context, {required String emptyMessage, required String? baseUrl, required AppLocalizations l10n}) {
    return SafeArea(
      top: false,
      bottom: false,
      child: (baseUrl == null || baseUrl.isEmpty)
          ? _buildServerConfig()
          : RefreshIndicator(
              onRefresh: () => _loadMovies(refresh: true, silent: true),
              // Drops in under the pinned rows instead of on top of them.
              edgeOffset: _isFilterHeaderPinned(context) ? _filterHeaderHeight : 0,
              child: CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // No spacer above the header: anything before it would scroll
                  // away first and make the pinned rows jump up by that much.
                  ..._buildFilterHeaderSlivers(context, l10n),
                  // Only once discovery has finished — otherwise it reads as a
                  // misconfiguration on the very first open.
                  if (!_isLoading && _searchQuery.isEmpty && _categories.isEmpty && _collection == _MovieCollection.browse)
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
    );
  }

  /// The search field. A [SizeTransition] driven by [_searchAnimation] is what
  /// makes the list glide down instead of snapping — and unlike `AnimatedSize`,
  /// it animates on the very first open too.
  Widget _buildSearchField(AppLocalizations l10n) {
    final scheme = Theme.of(context).colorScheme;
    final curved = CurvedAnimation(parent: _searchAnimation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
    // The prefix only lands once the flying icon has arrived, so the two read
    // as one icon travelling rather than two icons overlapping.
    final prefixOpacity = CurvedAnimation(parent: _searchAnimation, curve: const Interval(0.75, 1));

    return SizeTransition(
      sizeFactor: curved,
      alignment: Alignment.topCenter,
      child: FadeTransition(
        opacity: curved,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            onChanged: _onSearchChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: l10n.searchMoviesPlaceholder,
              prefixIcon: FadeTransition(opacity: prefixOpacity, child: const Icon(Icons.search_rounded)),
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
              fillColor: scheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: scheme.outlineVariant, width: 1),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: scheme.outlineVariant, width: 1),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The search icon in flight between the app bar button and the field's
  /// prefix slot. Drawn over the body so it can cross the gap between the two.
  Widget _buildFlyingSearchIcon() {
    return AnimatedBuilder(
      animation: _searchAnimation,
      builder: (context, _) {
        final t = _searchAnimation.value;
        final origin = _searchIconOrigin;
        if (origin == null || t == 0 || t == 1) return const SizedBox.shrink();

        // Falling faster than it slides across gives the path a slight arc.
        final dx = Curves.easeInOut.transform(t);
        final dy = Curves.easeOutCubic.transform(t);
        final center = Offset(origin.dx + (_searchPrefixCenter.dx - origin.dx) * dx, origin.dy + (_searchPrefixCenter.dy - origin.dy) * dy);
        // Fades out as it arrives, right as the field's own prefix fades in.
        final opacity = (1 - const Interval(0.75, 1).transform(t)).clamp(0.0, 1.0);

        return Positioned(
          left: center.dx - 12,
          top: center.dy - 12,
          child: IgnorePointer(
            child: Opacity(
              opacity: opacity,
              child: Icon(Icons.search_rounded, size: 18 + 6 * t, color: Theme.of(context).colorScheme.primary),
            ),
          ),
        );
      },
    );
  }

  /// The filter buttons and the category chips.
  ///
  /// Portrait pins them under the app bar — there is height to spare, and they
  /// stay reachable while scrolling. Landscape is short enough that a pinned
  /// header would eat the list, so there they scroll away with the cards.
  List<Widget> _buildFilterHeaderSlivers(BuildContext context, AppLocalizations l10n) {
    final height = _filterHeaderHeight;
    if (height == 0) return const [];

    final showFilters = _showFilterButtons;
    final showCategories = _mainCategories.isNotEmpty;
    final header = Column(
      mainAxisSize: MainAxisSize.min,
      // Stretch, otherwise each row shrinks to its content and gets centred.
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showFilters) SizedBox(height: _filterRowHeight, child: _buildFilterRow(l10n)),
        if (showCategories) SizedBox(height: _categoryRowHeight, child: _buildCategoryRow(l10n)),
      ],
    );

    if (!_isFilterHeaderPinned(context)) {
      return [SliverToBoxAdapter(child: header)];
    }
    return [
      SliverPersistentHeader(
        pinned: true,
        delegate: _PinnedHeaderDelegate(height: height.toDouble(), color: Theme.of(context).scaffoldBackgroundColor, child: header),
      ),
    ];
  }

  Widget _buildFilterRow(AppLocalizations l10n) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      // Vertical padding leaves the neu shadow room inside the pinned header,
      // which clips to its own extent.
      padding: const EdgeInsets.fromLTRB(16, 5, 16, 5),
      clipBehavior: Clip.none,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_countryCategories.isNotEmpty)
            _buildFilterButton(icon: Icons.public_rounded, fallbackLabel: l10n.countryLabel, options: _countryCategories, isCountry: true),
          if (_countryCategories.isNotEmpty && _genreCategories.isNotEmpty) const SizedBox(width: 10),
          if (_genreCategories.isNotEmpty)
            _buildFilterButton(
              icon: Icons.local_movies_rounded,
              fallbackLabel: l10n.genreLabel,
              options: _genreCategories,
              isCountry: false,
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryRow(AppLocalizations l10n) {
    final cats = _mainCategories;
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      clipBehavior: Clip.none,
      scrollDirection: Axis.horizontal,
      itemCount: cats.length,
      separatorBuilder: (_, _) => const SizedBox(width: 8),
      itemBuilder: (context, index) {
        final cat = cats[index];
        final isSelected = _collection == _MovieCollection.browse && cat.id == _selectedCategory?.id;

        final label = switch (cat.id) {
          'new' => l10n.categoryNew,
          'phim-le' => l10n.categorySingle,
          'phim-bo' => l10n.categorySeries,
          'hoat-hinh' => l10n.categoryAnime,
          'tv-shows' => l10n.categoryTVShow,
          _ => cat.name,
        };

        return NeuChip(label: label, isSelected: isSelected, onTap: () => _selectCategory(cat));
      },
    );
  }

  /// A neu pill that opens the country / genre sheet and, once something is
  /// picked, shows the active value in place of its own label.
  Widget _buildFilterButton({
    required IconData icon,
    required String fallbackLabel,
    required List<MovieCategory> options,
    required bool isCountry,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final selected = isCountry ? _selectedCountry : _selectedGenre;
    final isSelected = selected != null;
    final foreground = isSelected ? Colors.white : scheme.onSurfaceVariant;

    return GestureDetector(
      onTap: () => _showFilterSheet(title: fallbackLabel, options: options, isCountry: isCountry),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: context.neu.raised(radius: 12, depth: 0.6, color: isSelected ? scheme.primary : null, inset: isSelected),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: foreground),
            const SizedBox(width: 6),
            Text(
              selected?.name ?? fallbackLabel,
              maxLines: 1,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: foreground),
            ),
            Icon(Icons.expand_more_rounded, size: 18, color: foreground),
          ],
        ),
      ),
    );
  }

  /// The YouTube-style player: a rect that lerps between the tapped card (or
  /// the mini bar) and the whole screen, hosting the detail page inside.
  Widget _buildPlayerOverlay(BuildContext context, Movie movie) {
    final size = MediaQuery.sizeOf(context);
    final viewPadding = MediaQuery.paddingOf(context);
    final fullRect = Offset.zero & size;
    // Landscape keeps the notch on a side, so the bar is inset there as well as
    // above the home indicator.
    final miniRect = Rect.fromLTWH(
      viewPadding.left + 8,
      size.height - viewPadding.bottom - 8 - miniPlayerHeight,
      size.width - viewPadding.horizontal - 16,
      miniPlayerHeight,
    );
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

/// Pins the filter / category rows under the app bar at a fixed height, on an
/// opaque background so the grid scrolls underneath rather than through them.
class _PinnedHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _PinnedHeaderDelegate({required this.height, required this.color, required this.child});

  final double height;
  final Color color;
  final Widget child;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox(
      height: height,
      child: ColoredBox(color: color, child: child),
    );
  }

  @override
  bool shouldRebuild(_PinnedHeaderDelegate oldDelegate) {
    return oldDelegate.height != height || oldDelegate.color != color || oldDelegate.child != child;
  }
}
