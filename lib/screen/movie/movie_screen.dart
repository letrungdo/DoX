import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:do_x/constants/dimens.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/model/movie_model.dart';
import 'package:do_x/router/app_router.gr.dart';
import 'package:do_x/screen/core/screen_state.dart';
import 'package:do_x/screen/core/tab_reselect.mixin.dart';
import 'package:do_x/screen/movie/movie_detail_controller.dart';
import 'package:do_x/screen/movie/movie_detail_screen.dart';
import 'package:do_x/screen/movie/movie_filter_sheet.dart';
import 'package:do_x/screen/movie/movie_player_layout.dart';
import 'package:do_x/screen/movie/movie_poster_card.dart';
import 'package:do_x/screen/movie/movie_search_screen.dart';
import 'package:do_x/screen/movie/movie_server_dialog.dart';
import 'package:do_x/services/movie_library_service.dart';
import 'package:do_x/services/movie_service.dart';
import 'package:do_x/store/immersive_mode.dart';
import 'package:do_x/utils/device_type.dart';
import 'package:do_x/widgets/loading.dart';
import 'package:do_x/view_model/movie/movie_detail_view_model.dart';
import 'package:do_x/view_model/movie/movie_view_model.dart';
import 'package:do_x/widgets/app_bar/app_bar_base.dart';
import 'package:do_x/widgets/app_bar/app_bar_sync_icon.dart';
import 'package:do_x/widgets/app_scaffold.dart';
import 'package:do_x/widgets/dialog/app_modal.dart';
import 'package:do_x/widgets/neu/neu_button.dart';
import 'package:do_x/widgets/neu/neu_chip.dart';
import 'package:do_x/widgets/neu/neu_press.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

@RoutePage()
class MovieScreen extends StatefulScreen implements AutoRouteWrapper {
  const MovieScreen({super.key});

  @override
  State<MovieScreen> createState() => _MovieScreenState();

  @override
  Widget wrappedRoute(BuildContext context) {
    return ChangeNotifierProvider(create: (_) => MovieViewModel(), child: this);
  }
}

/// How long the card→player zoom and the minimise/expand snap take.
const _overlayAnimationDuration = Duration(milliseconds: 300);

/// How long the search field takes to slide in and out.
const _searchAnimationDuration = Duration(milliseconds: 260);

/// How old the list may get before coming back to the app refetches it. A
/// quick look at another app keeps the page — and how far down it was
/// scrolled — exactly as it was left.
const _resumeReloadAge = Duration(minutes: 5);

/// Centre of the search field's prefix icon in body coordinates: the field's
/// 16px side padding and 8px top padding, plus the prefix slot inside it. Used
/// as the landing point of the icon flying down from the app bar.
const _searchPrefixCenter = Offset(40, 32);

/// Fixed heights of the two filter rows, needed so the pinned header knows its
/// extent up front.
const _filterRowHeight = 48.0;
const _categoryRowHeight = 46.0;

class _MovieScreenState extends ScreenState<MovieScreen, MovieViewModel>
    with TickerProviderStateMixin, TabReselect {
  final _searchController = TextEditingController();
  late final TextEditingController _serverUrlController;
  final _scrollController = ScrollController();
  Timer? _debounceTimer;

  /// The search field sits above the list and is only laid out while toggled on.
  bool _isSearchOpen = false;
  final _searchFocusNode = FocusNode();
  final _searchButtonKey = GlobalKey();
  final _bodyKey = GlobalKey();

  /// 0 = search closed, 1 = field fully open. Drives the field's height, the
  /// fade, and the icon that flies from the app bar down into the field.
  late final AnimationController _searchAnimation;

  /// Where the app bar's search button sits in body coordinates, captured when
  /// the animation starts so the flying icon knows where to take off from.
  Offset? _searchIconOrigin;

  bool _showScrollToTop = false;

  /// 1 = detail page fills the screen, 0 = collapsed to the mini player bar.
  late final AnimationController _overlayController;

  /// The movie the overlay is showing; `null` when no player is open.
  Movie? _playingMovie;

  /// Rect of the tapped card, used as the origin of the opening zoom. Cleared
  /// once the overlay has finished expanding.
  Rect? _entryRect;
  bool _isDetailFullScreen = false;
  bool _isClosingOverlay = false;

  /// True from the moment a drag starts on the mini bar until it ends, so the
  /// recognizer is not torn down the instant the bar stops being mini.
  bool _isDraggingMiniBar = false;

  /// Below this much of the way open, the player is the bar at the bottom of
  /// the page rather than a sheet over it.
  static const _miniThreshold = 0.02;
  final _detailController = MovieDetailController();

  /// The detail page in the overlay, and the film it was built for. Built once
  /// per film, so neither a frame of the overlay's animation nor a rebuild of
  /// this page for the grid behind it rebuilds the player.
  Widget? _detailScreen;
  Movie? _detailScreenMovie;

  /// How far the overlay travels between the mini bar and full screen, kept
  /// current for the drag handlers of the cached [_detailScreen].
  double _overlayTravel = 0;

  /// The app bar title's measured width and the label and style it was
  /// measured for — laid out once per label instead of on every build.
  double? _movieLabelWidth;
  (String, TextStyle)? _movieLabelWidthKey;

  bool _isSelectionMode = false;
  final Set<String> _selectedMovieIds = {};

  /// One focus node per built grid tile, keyed by its index, so the remote can
  /// be put back on a particular card. Television only — nothing else reads it.
  final Map<int, FocusNode> _tileFocusNodes = {};

  /// The film the overlay was opened out of, remembered so the remote can go
  /// back to its poster once the overlay closes.
  String? _lastOpenedMovieId;

  /// Categories shown as the always-visible chip row (everything that is not a
  /// genre or a country, which get their own picker buttons instead).
  List<MovieCategory> get _mainCategories => vm.mainCategories;

  List<MovieCategory> get _genreCategories => vm.genreCategories;

  List<MovieCategory> get _countryCategories => vm.countryCategories;

  /// Only the primary (Ophim) server exposes genre / country listings.
  bool get _showFilterButtons =>
      movieService.isPrimaryServer &&
      (_genreCategories.isNotEmpty || _countryCategories.isNotEmpty);

  /// Portrait pins the filter / category rows under the app bar — there is
  /// height to spare and they stay reachable while scrolling. Landscape is short
  /// enough that a pinned header would eat the list, so there they scroll away.
  bool _isFilterHeaderPinned(BuildContext context) {
    return _filterHeaderHeight > 0 &&
        MediaQuery.orientationOf(context) == Orientation.portrait;
  }

  /// Height of the filter / category header, 0 when it is not shown. The pull
  /// to refresh indicator uses it to drop below the pinned rows.
  double get _filterHeaderHeight {
    if (vm.searchQuery.isNotEmpty) return 0;
    return (_showFilterButtons ? _filterRowHeight : 0) +
        (_mainCategories.isNotEmpty ? _categoryRowHeight : 0);
  }

  @override
  void initState() {
    super.initState();
    _serverUrlController = TextEditingController(
      text: movieService.baseUrl ?? '',
    );
    _overlayController = AnimationController(
      vsync: this,
      duration: _overlayAnimationDuration,
    );
    _searchAnimation = AnimationController(
      vsync: this,
      duration: _searchAnimationDuration,
    );
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    immersiveMode.value = false;
    _overlayController.dispose();
    _searchAnimation.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _serverUrlController.dispose();
    _scrollController.dispose();
    for (final node in _tileFocusNodes.values) {
      node.dispose();
    }
    _tileFocusNodes.clear();
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  void onResume() {
    super.onResume();
    // A film on screen is what the viewer came back to; reloading the grid
    // behind it would only throw away how far down it was scrolled.
    if (_playingMovie != null) return;
    // The saved server may have redirected somewhere else since the app was
    // last used; the check runs behind the refresh and reloads if it moved.
    unawaited(vm.refreshServerAddress());
    if (vm.isOlderThan(_resumeReloadAge)) {
      vm.loadMovies(refresh: true, silent: true);
    }
  }

  void _onScroll() {
    final position = _scrollController.position;
    final shouldShowScrollToTop = position.pixels > 240;
    if (shouldShowScrollToTop != _showScrollToTop) {
      setState(() => _showScrollToTop = shouldShowScrollToTop);
    }

    if (position.pixels >= position.maxScrollExtent - 300 &&
        !vm.isLoadingMore &&
        !vm.isLoading &&
        vm.hasMore) {
      vm.loadMoreMovies();
    }
  }

  @override
  String get tabRouteName => MovieRoute.name;

  @override
  ScrollController get tabScrollController => _scrollController;

  @override
  Future<void> onTabRefresh() => vm.loadMovies(refresh: true, silent: true);

  Future<void> _scrollToTop() async {
    if (!_scrollController.hasClients) return;
    await _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      vm.setSearchQuery(query);
      if (_scrollController.hasClients) _scrollController.jumpTo(0);
    });
  }

  void _selectCollection(MovieCollection collection) {
    if (_isSelectionMode) _exitSelectionMode();
    vm.setCollection(collection);
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
  }

  void _selectCategory(MovieCategory? category) {
    if (_isSelectionMode) _exitSelectionMode();
    vm.setCategory(category);
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
  }

  /// Opens the country or genre sheet; the other filter is left untouched so
  /// both can be active at once.
  Future<void> _showFilterSheet({
    required String title,
    required List<MovieCategory> options,
    required bool isCountry,
  }) async {
    // Popping a route hands focus back to whatever held it before the route
    // was pushed, so closing this sheet would put the caret back in the search
    // field and bring the keyboard up over a list the user never asked to
    // search. Dropping focus first leaves nothing to restore.
    _searchFocusNode.unfocus();

    final current = isCountry ? vm.selectedCountry : vm.selectedGenre;
    // A wrapped mosaic of chips is the wrong shape for a D-pad: directional
    // traversal sorts candidates into bands, so up and down through rows of
    // unequal width skip columns unpredictably. One row per option travels
    // straight down, and reads from the sofa as well.
    final result = deviceType.isTv
        ? await _showTvFilterSheet(
            title: title,
            options: options,
            current: current,
          )
        : await MovieFilterSheet.show(
            context,
            title: title,
            options: options,
            selectedId: current?.id,
          );
    if (result == null || !mounted) return;
    if (result.category?.id == current?.id) return;

    vm.setFilter(category: result.category, isCountry: isCountry);
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
  }

  /// The television shape of the country / genre picker: the shared option
  /// sheet, one focusable row per entry.
  Future<MovieFilterResult?> _showTvFilterSheet({
    required String title,
    required List<MovieCategory> options,
    required MovieCategory? current,
  }) async {
    final l10n = AppLocalizations.of(context);
    final rows = [
      _FilterOption(null, l10n.all),
      for (final option in options) _FilterOption(option, option.name),
    ];
    final picked = await showAppOptionSheet<_FilterOption>(
      context,
      title: title,
      options: rows,
      selected: _FilterOption(current, current?.name ?? l10n.all),
      labelBuilder: (option) => option.label,
    );
    return picked == null ? null : (category: picked.category);
  }

  Future<void> _showCollectionMenu() async {
    // Same reason as the filter sheet: a sheet is a route too, and closing it
    // would restore the caret to the search field.
    _searchFocusNode.unfocus();

    final l10n = AppLocalizations.of(context);
    final selected = await showAppOptionSheet<MovieCollection>(
      context,
      options: const [MovieCollection.watched, MovieCollection.favorites],
      // Browsing is not one of the rows, so nothing is marked while it is on.
      selected: vm.collection == MovieCollection.browse ? null : vm.collection,
      labelBuilder: (collection) => switch (collection) {
        MovieCollection.watched => l10n.watchedMovies,
        MovieCollection.favorites => l10n.favoriteMovies,
        MovieCollection.browse => l10n.all,
      },
    );
    if (selected == null || !mounted) return;
    _selectCollection(selected);
  }

  /// Positions the app bar's search button in the body's coordinate space, so
  /// the flying icon can start exactly where the button is.
  void _captureSearchIconOrigin() {
    final button =
        _searchButtonKey.currentContext?.findRenderObject() as RenderBox?;
    final body = _bodyKey.currentContext?.findRenderObject() as RenderBox?;
    if (button == null || body == null) return;
    _searchIconOrigin = body.globalToLocal(
      button.localToGlobal(button.size.center(Offset.zero)),
    );
  }

  /// Searches on a television: a page of its own.
  ///
  /// A full-screen keyboard leaves no room for a field wedged onto this page,
  /// so the box, the results and the way out go on a page the keyboard can
  /// have to itself. The same view model travels with it, so the query is
  /// answered by the server already configured here — and it is cleared again
  /// on the way back, which puts the whole library on screen without the
  /// viewer having to empty a box that is no longer there.
  Future<void> _openSearchPage() async {
    if (_isSelectionMode) _exitSelectionMode();
    final picked = await context.pushRoute<MovieSearchPick?>(
      MovieSearchRoute(movieVm: vm),
    );
    if (!mounted) return;
    final hadQuery = vm.searchQuery.isNotEmpty;
    if (hadQuery) {
      // Clearing the query is itself the refetch of the full list.
      await vm.setSearchQuery('');
      if (_scrollController.hasClients) _scrollController.jumpTo(0);
    }
    // The player is an overlay on this page, not on the search page, so a
    // film picked there is opened here — out of the poster it was picked from.
    if (picked != null && mounted) {
      await _openMovie(picked.movie, picked.cardRect);
    } else if (hadQuery && mounted) {
      // The grid was refetched and ridden back to the top under a focus that
      // no longer maps to anything, so the remote is handed the first tile.
      _restoreGridFocus(null);
    }
  }

  void _toggleSearch() {
    if (_isSelectionMode) _exitSelectionMode();
    _captureSearchIconOrigin();
    if (_isSearchOpen) {
      _debounceTimer?.cancel();
      _searchController.clear();
      final hadQuery = vm.searchQuery.isNotEmpty;
      setState(() {
        _isSearchOpen = false;
      });
      _searchAnimation.reverse();
      // The node, not the scope — see the browser's background tap handler.
      _searchFocusNode.unfocus();
      // Nothing was searched, so the list on screen is already the right one.
      // Otherwise clearing the query is itself the refetch of the full list.
      if (hadQuery) {
        unawaited(vm.setSearchQuery(''));
        if (_scrollController.hasClients) _scrollController.jumpTo(0);
      }
      return;
    }
    setState(() => _isSearchOpen = true);
    _searchAnimation.forward();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _searchFocusNode.requestFocus(),
    );
  }

  void _toggleSelection(String movieId) {
    setState(() {
      if (_selectedMovieIds.contains(movieId)) {
        _selectedMovieIds.remove(movieId);
        if (_selectedMovieIds.isEmpty) _isSelectionMode = false;
      } else {
        _selectedMovieIds.add(movieId);
      }
    });
  }

  /// Turns selection mode on with nothing selected yet.
  ///
  /// The only other way in is a long press, which a remote cannot produce —
  /// `NeuPress` answers the D-pad's OK with `ActivateIntent`, and that fires
  /// `onTap` alone. Without this the bulk delete is dead on a television.
  void _startSelectionMode() {
    setState(() {
      _isSelectionMode = true;
      _selectedMovieIds.clear();
    });
  }

  void _enterSelectionMode(String movieId) {
    setState(() {
      _isSelectionMode = true;
      _selectedMovieIds.add(movieId);
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedMovieIds.clear();
    });
  }

  Future<void> _deleteSelected() async {
    if (_selectedMovieIds.isEmpty) return;

    final l10n = AppLocalizations.of(context);
    final count = _selectedMovieIds.length;
    final confirm = await showAppConfirmDialog(
      context,
      title: l10n.removeFromHistory,
      message: l10n.confirmRemoveSelectedFromHistory(count),
      confirmText: l10n.delete,
      isDestructive: true,
    );

    if (confirm) {
      final ids = _selectedMovieIds.toList();
      _exitSelectionMode();
      await movieLibraryService.removeMultipleFromHistory(ids);
      if (mounted) {
        await vm.loadMovies(refresh: true);
      }
    }
  }

  /// The focus node of the grid tile at [index], created on first use.
  FocusNode _tileFocusNode(int index) =>
      _tileFocusNodes.putIfAbsent(index, FocusNode.new);

  bool _isTileFocusPruneScheduled = false;

  /// Disposes the focus nodes of tiles past the end of a list that got
  /// shorter. After the frame, once the grid has let go of them: a node is
  /// still attached to its old tile while the grid is rebuilding.
  void _pruneTileFocusNodes(int tileCount) {
    if (_isTileFocusPruneScheduled ||
        _tileFocusNodes.keys.every((index) => index < tileCount)) {
      return;
    }
    _isTileFocusPruneScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isTileFocusPruneScheduled = false;
      if (!mounted) return;
      final count = vm.movies.length;
      _tileFocusNodes.removeWhere((index, node) {
        if (index < count || node.context != null) return false;
        node.dispose();
        return true;
      });
    });
  }

  /// Puts the remote back on the grid after something took focus away.
  ///
  /// The node that held it lived inside the overlay — or on the search page —
  /// and went with it, so `TvShell` falls back to the first thing it can
  /// traverse, the app bar, and `ensureVisible` drags a grid twelve rows down
  /// back to the top. Focusing the poster the viewer came from keeps the place
  /// they had. [movieId] of `null`, or a film no longer in the list, lands on
  /// the first tile, which is where a refreshed list has been scrolled anyway.
  void _restoreGridFocus(String? movieId, {bool immediate = false}) {
    if (!deviceType.isTv) return;

    void doFocus() {
      if (!mounted) return;
      final found = movieId == null
          ? -1
          : vm.movies.indexWhere((movie) => movie.id == movieId);
      final node = _tileFocusNodes[found < 0 ? 0 : found];
      if (node == null || !node.canRequestFocus) return;
      node.requestFocus();
      final nodeContext = node.context;
      if (nodeContext == null || !nodeContext.mounted) return;
      unawaited(
        Scrollable.ensureVisible(
          nodeContext,
          alignment: Dimens.tvFocusScrollAlignment,
          duration: Dimens.tvFocusScrollDuration,
        ),
      );
    }

    if (immediate) {
      doFocus();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => doFocus());
    }
  }

  Future<void> _handleMovieLongPress(Movie movie) async {
    if (vm.collection != MovieCollection.watched) return;
    _enterSelectionMode(movie.id);
  }

  Future<void> _refreshLibraryStates() async {
    await vm.refreshLibraryStates();
  }

  /// Opens [movie] in the overlay, zooming out of the card at [cardRect]
  /// instead of pushing a route, so playback survives minimising.
  Future<void> _openMovie(Movie movie, Rect cardRect) async {
    // The detail is an overlay on this page, not a pushed route, so nothing
    // tears the search field's focus down on the way in and the keyboard would
    // stay up over the player. The background GestureDetector cannot do it
    // either — the card swallows the tap before it gets there.
    _searchFocusNode.unfocus();
    // The poster still holds the remote's focus, and it is about to be shut out
    // of the focus tree by the ExcludeFocus above. Dropping focus here leaves
    // the scope empty, which is the one condition under which the player's own
    // `autofocus` is honoured — otherwise the overlay opens with the D-pad
    // pointing at nothing.
    FocusManager.instance.primaryFocus?.unfocus();
    _lastOpenedMovieId = movie.id;
    setState(() {
      _playingMovie = movie;
      _entryRect = cardRect;
      _isDetailFullScreen = false;
    });
    await _overlayController.animateTo(
      1,
      duration: _overlayAnimationDuration,
      curve: Curves.easeOutCubic,
    );
    if (!mounted) return;
    setState(() => _entryRect = null);
  }

  /// Whether the player may be shrunk to the bar at the bottom of the page.
  ///
  /// It is a touch affordance through and through: it is reached by dragging
  /// the player down, and left again by tapping the bar. A remote can do
  /// neither, and what it leaves behind is a strip playing a film the D-pad
  /// has no way to get back into. On a television back closes the player
  /// instead.
  bool get _canMinimize => !deviceType.isTv;

  void _minimizeOverlay() {
    _overlayController.animateTo(
      0,
      duration: _overlayAnimationDuration,
      curve: Curves.easeOutCubic,
    );
  }

  void _expandOverlay() {
    _overlayController.animateTo(
      1,
      duration: _overlayAnimationDuration,
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _closeOverlay() async {
    if (_playingMovie == null) return;
    immersiveMode.value = false;
    final lastMovieId = _lastOpenedMovieId;

    if (deviceType.isTv) {
      // On TV, use a two-step closure to prevent focus flickering to the App Bar title.
      // Step 1: Enable focus on the browser grid while keeping the detail overlay mounted.
      setState(() {
        _isClosingOverlay = true;
        _isDetailFullScreen = false;
      });
      _overlayController.value = 0;

      // Wait for the next frame where ExcludeFocus is disabled, then safely move focus to the movie item.
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        _restoreGridFocus(lastMovieId, immediate: true);

        // Step 2: Now that focus is safely on the movie item, unmount the detail overlay.
        setState(() {
          _playingMovie = null;
          _entryRect = null;
          _isClosingOverlay = false;
          _detailScreen = null;
          _detailScreenMovie = null;
        });

        if (vm.collection == MovieCollection.browse) {
          await _refreshLibraryStates();
        } else {
          await vm.loadMovies(refresh: true, silent: true);
        }
        if (!mounted) return;
        _restoreGridFocus(lastMovieId);
      });
    } else {
      setState(() {
        _playingMovie = null;
        _entryRect = null;
        _isDetailFullScreen = false;
        _detailScreen = null;
        _detailScreenMovie = null;
      });
      _overlayController.value = 0;

      if (vm.collection == MovieCollection.browse) {
        await _refreshLibraryStates();
      } else {
        await vm.loadMovies(refresh: true, silent: true);
      }
    }
  }

  void _onOverlayDragUpdate(DragUpdateDetails details, double travel) {
    if (travel <= 0) return;
    _overlayController.value =
        (_overlayController.value - (details.primaryDelta ?? 0) / travel).clamp(
          0.0,
          1.0,
        );
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
    if (vm.isFetching) return false;
    // `https://` is optional in the field; the service fills it in.
    final url = movieService.normalizeServerUrl(rawUrl);
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !uri.hasAuthority ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      context.showToast(l10n.invalidMovieServerUrl, isError: true);
      return false;
    }

    final success = await vm.updateMovieServer(url);
    if (!mounted) return false;
    if (success) {
      _serverUrlController.text = movieService.baseUrl ?? url;
      _searchController.clear();
      _isSearchOpen = false;
      context.showToast(l10n.movieServerUrlUpdated);
    } else {
      context.showToast(l10n.updateMovieServerFailed, isError: true);
    }
    return success;
  }

  Future<void> _showServerUrlDialog() async {
    await showAppModal<void>(
      context,
      builder: (dialogContext) => MovieServerDialog(
        onServerChanged: () {
          if (mounted) vm.initData();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return PopScope(
      canPop: _playingMovie == null,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || _playingMovie == null) return;
        // The detail screen has the first say: it climbs its own ladder — the
        // episode grid, then the control overlay, then full screen — and the
        // overlay only gives way once that ladder has run out. The film is
        // still playing, and the page it came from is the next thing behind
        // it, not the one after that.
        if (_detailController.handleBack()) return;
        if (_canMinimize && _overlayController.value > 0) {
          _minimizeOverlay();
        } else {
          unawaited(_closeOverlay());
        }
      },
      child: LayoutBuilder(
        builder: (context, constraints) => Stack(
          fit: StackFit.expand,
          children: [
            // The detail is an overlay in this Stack, not a pushed route,
            // so nothing takes the browser out of the focus tree the way a
            // route would: covered by the player, every poster behind it
            // still answers the D-pad, and the remote wanders off into a
            // grid it cannot see. Only the ExcludeFocus rebuilds as the
            // overlay travels — the browser is handed through untouched.
            AnimatedBuilder(
              animation: _overlayController,
              child: GestureDetector(
                onTap: _searchFocusNode.unfocus,
                // Only the browser follows the view model. The player sits
                // outside it, so a page of posters arriving never rebuilds
                // the film that is playing over them.
                child: Consumer<MovieViewModel>(
                  builder: (context, vm, _) {
                    _pruneTileFocusNodes(vm.movies.length);
                    return _buildBrowser(
                      context,
                      vm: vm,
                      emptyMessage: switch (vm.collection) {
                        MovieCollection.watched => l10n.noWatchedMovies,
                        MovieCollection.favorites => l10n.noFavoriteMovies,
                        MovieCollection.browse => l10n.noMoviesFound,
                      },
                      movieLabel: movieService.getLabel(),
                      baseUrl: movieService.baseUrl,
                      l10n: l10n,
                      constraints: constraints,
                    );
                  },
                ),
              ),
              builder: (context, child) => ExcludeFocus(
                // Minimised, the player is a bar at the bottom and the
                // browser is back in charge, so it takes the remote again.
                excluding:
                    !_isClosingOverlay &&
                    _playingMovie != null &&
                    _overlayController.value > _miniThreshold,
                child: child!,
              ),
            ),
            if (_playingMovie != null)
              _buildPlayerOverlay(context, _playingMovie!, constraints.biggest),
          ],
        ),
      ),
    );
  }

  Widget _buildBrowser(
    BuildContext context, {
    required MovieViewModel vm,
    required String emptyMessage,
    required String movieLabel,
    required String? baseUrl,
    required AppLocalizations l10n,
    required BoxConstraints constraints,
  }) {
    if (_isSelectionMode) {
      return AppScaffold(
        appBar: DoAppBar(
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: _exitSelectionMode,
          ),
          title: l10n.selectedCountTitle(_selectedMovieIds.length),
          actions: [
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: l10n.delete,
              onPressed: _deleteSelected,
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: _buildBrowserBody(
          context,
          vm: vm,
          emptyMessage: emptyMessage,
          baseUrl: baseUrl,
          l10n: l10n,
        ),
      );
    }

    return AppScaffold(
      appBar: DoAppBar(
        title: movieLabel,
        // The title doubles as the server picker, replacing the old link action.
        onTitleTap: _showServerUrlDialog,
        titleSuffix: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.expand_more_rounded,
              size: 20,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            AppBarSyncIcon<MovieViewModel>(selector: (vm) => vm.isFetching),
          ],
        ),
        actions: [
          NeuIconButton(
            key: _searchButtonKey,
            size: Dimens.appBarActionSize,
            iconSize: 18,
            depth: Dimens.appBarActionDepth,
            tooltip: l10n.searchMoviesPlaceholder,
            color: _isSearchOpen ? Theme.of(context).colorScheme.primary : null,
            icon: _isSearchOpen ? Icons.close_rounded : Icons.search_rounded,
            onPressed: deviceType.isTv ? _openSearchPage : _toggleSearch,
          ),
          const SizedBox(width: 8),
          // The select button comes and goes with the watch history, and the
          // app bar lays its actions out by position: one slot more or less in
          // front of the collection buttons would rebuild them from scratch,
          // dispose the focus node the remote is on, and drop it back on the
          // search button. So they all share one action, keyed within it.
          Builder(
            builder: (context) {
              final isWatched = vm.collection == MovieCollection.watched;
              final appBarTheme = Theme.of(context).appBarTheme;
              final titleStyle =
                  appBarTheme.titleTextStyle ??
                  Theme.of(context).textTheme.titleLarge ??
                  const TextStyle(fontSize: 20);
              // Estimated title block: Label + Suffix (expand icon, sync icon) + gaps.
              final titleBlockWidth =
                  _labelWidth(movieLabel, titleStyle) + 48 + 16;
              // Actions: Search (40) + History (40) + Favorite (40) + End
              // padding (10), plus the select button while the watch history
              // is the collection on screen.
              final actionsWidth =
                  (3 * Dimens.appBarActionSize) +
                  (2 * 8) +
                  10 +
                  (isWatched ? Dimens.appBarActionSize + 8 : 0);
              // If the sum plus safe margins fits the bar width.
              final showAll =
                  constraints.maxWidth > (titleBlockWidth + actionsWidth + 32);

              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isWatched) ...[
                    NeuIconButton(
                      key: const ValueKey('movie-select'),
                      size: Dimens.appBarActionSize,
                      iconSize: 18,
                      depth: Dimens.appBarActionDepth,
                      tooltip: l10n.selectMovies,
                      icon: Icons.checklist_rounded,
                      onPressed: _startSelectionMode,
                    ),
                    const SizedBox(key: ValueKey('movie-select-gap'), width: 8),
                  ],
                  if (showAll) ...[
                    NeuIconButton(
                      key: const ValueKey('movie-watched'),
                      size: Dimens.appBarActionSize,
                      iconSize: 18,
                      depth: Dimens.appBarActionDepth,
                      tooltip: l10n.watchedMovies,
                      color: isWatched
                          ? Theme.of(context).colorScheme.primary
                          : null,
                      icon: Icons.history_rounded,
                      onPressed: () =>
                          _selectCollection(MovieCollection.watched),
                    ),
                    const SizedBox(width: 8),
                    NeuIconButton(
                      key: const ValueKey('movie-favorites'),
                      size: Dimens.appBarActionSize,
                      iconSize: 18,
                      depth: Dimens.appBarActionDepth,
                      tooltip: l10n.favoriteMovies,
                      color: vm.collection == MovieCollection.favorites
                          ? Theme.of(context).colorScheme.primary
                          : null,
                      icon: Icons.favorite_rounded,
                      onPressed: () =>
                          _selectCollection(MovieCollection.favorites),
                    ),
                  ] else
                    NeuIconButton(
                      key: const ValueKey('movie-collections'),
                      size: Dimens.appBarActionSize,
                      iconSize: 18,
                      depth: Dimens.appBarActionDepth,
                      color: vm.collection != MovieCollection.browse
                          ? Theme.of(context).colorScheme.primary
                          : null,
                      icon: Icons.more_vert_rounded,
                      onPressed: _showCollectionMenu,
                    ),
                ],
              );
            },
          ),
        ],
      ),
      // Hidden while the player overlay is up so it never fights the mini bar.
      floatingActionButton:
          (baseUrl == null || baseUrl.isEmpty || _playingMovie != null)
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (!vm.isLoading && vm.movies.isNotEmpty)
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
                        borderRadius: BorderRadius.circular(
                          Dimens.radiusControlSmall,
                        ),
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
                          vm.movies.length,
                          vm.totalMovies > 0
                              ? vm.totalMovies.toString()
                              : '...',
                        ),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                // Not shown as a tab: re-tapping the movie tab already rides
                // the grid back to the top, so the button would be a second
                // control for something the bottom bar does.
                if (_showScrollToTop && !isBottomTab)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: NeuIconButton(
                      tooltip: l10n.scrollToTop,
                      icon: Icons.vertical_align_top_rounded,
                      onPressed: _scrollToTop,
                    ),
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
              // instead of jumping when the field appears. A television has no
              // field here at all — it searches on a page of its own.
              if (!deviceType.isTv) _buildSearchField(vm, l10n),
              Expanded(
                child: _buildBrowserBody(
                  context,
                  vm: vm,
                  emptyMessage: emptyMessage,
                  baseUrl: baseUrl,
                  l10n: l10n,
                ),
              ),
            ],
          ),
          if (!deviceType.isTv) _buildFlyingSearchIcon(),
        ],
      ),
    );
  }

  Widget _buildBrowserBody(
    BuildContext context, {
    required MovieViewModel vm,
    required String emptyMessage,
    required String? baseUrl,
    required AppLocalizations l10n,
  }) {
    return (baseUrl == null || baseUrl.isEmpty)
        ? _buildServerConfig()
        : RefreshIndicator(
            onRefresh: () => vm.loadMovies(refresh: true, silent: true),
            // Drops in under the pinned rows instead of on top of them.
            edgeOffset: _isFilterHeaderPinned(context)
                ? _filterHeaderHeight
                : 0,
            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // No spacer above the header: anything before it would scroll
                // away first and make the pinned rows jump up by that much.
                ..._buildFilterHeaderSlivers(context, vm, l10n),
                // Only once discovery has finished — otherwise it reads as a
                // misconfiguration on the very first open.
                if (!vm.isLoading &&
                    vm.searchQuery.isEmpty &&
                    vm.categories.isEmpty &&
                    vm.collection == MovieCollection.browse)
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
                if (vm.isLoading && vm.movies.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: Loading()),
                  )
                else if (vm.movies.isEmpty)
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
                      MediaQuery.paddingOf(context).bottom +
                          50 +
                          // Room for the mini player to rest over the grid —
                          // none needed where the player never shrinks.
                          (_canMinimize && _playingMovie != null
                              ? miniPlayerHeight + 16
                              : 0),
                    ),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 220,
                            childAspectRatio: 1.0,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          if (index >= vm.movies.length) {
                            return const Card(child: Center(child: Loading()));
                          }
                          final movie = vm.movies[index];
                          final libraryState = vm.libraryStates[movie.id];
                          final isSelected = _selectedMovieIds.contains(
                            movie.id,
                          );

                          return MoviePosterCard(
                            movie: movie,
                            isWatched: libraryState?.watchedAt != null,
                            isFavorite: libraryState?.isFavorite ?? false,
                            libraryState: libraryState,
                            isSelected: isSelected,
                            focusNode: deviceType.isTv
                                ? _tileFocusNode(index)
                                : null,
                            onTap: (cardRect) {
                              if (_isSelectionMode) {
                                _toggleSelection(movie.id);
                              } else {
                                _openMovie(movie, cardRect);
                              }
                            },
                            onLongPress: () => _handleMovieLongPress(movie),
                          );
                        },
                        childCount:
                            vm.movies.length + (vm.isLoadingMore ? 2 : 0),
                      ),
                    ),
                  ),
              ],
            ),
          );
  }

  /// The search field. A [SizeTransition] driven by [_searchAnimation] is what
  /// makes the list glide down instead of snapping — and unlike `AnimatedSize`,
  /// it animates on the very first open too.
  Widget _buildSearchField(MovieViewModel vm, AppLocalizations l10n) {
    final curved = CurvedAnimation(
      parent: _searchAnimation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    // The prefix only lands once the flying icon has arrived, so the two read
    // as one icon travelling rather than two icons overlapping.
    final prefixOpacity = CurvedAnimation(
      parent: _searchAnimation,
      curve: const Interval(0.75, 1),
    );

    // Closed, the transitions leave the field at zero height and zero opacity
    // but still in the tree — invisible to the eye and perfectly focusable to a
    // D-pad, which lands in it and brings up the television's on-screen
    // keyboard over a field nobody asked for. `_toggleSearch` flips this flag
    // before it asks for focus, so opening still works.
    return ExcludeFocus(
      excluding: !_isSearchOpen,
      child: SizeTransition(
        sizeFactor: curved,
        alignment: Alignment.topCenter,
        child: FadeTransition(
          opacity: curved,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: _buildSearchBox(
              vm,
              l10n,
              prefix: FadeTransition(
                opacity: prefixOpacity,
                child: const Icon(Icons.search_rounded),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The box itself, kept apart from the field that slides it into the page.
  Widget _buildSearchBox(
    MovieViewModel vm,
    AppLocalizations l10n, {
    Widget prefix = const Icon(Icons.search_rounded),
  }) {
    final scheme = Theme.of(context).colorScheme;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(Dimens.radiusControl),
      borderSide: BorderSide(color: scheme.outlineVariant, width: 1),
    );
    return TextField(
      controller: _searchController,
      focusNode: _searchFocusNode,
      onChanged: _onSearchChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: l10n.searchMoviesPlaceholder,
        prefixIcon: prefix,
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
        border: border,
        enabledBorder: border,
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
        final center = Offset(
          origin.dx + (_searchPrefixCenter.dx - origin.dx) * dx,
          origin.dy + (_searchPrefixCenter.dy - origin.dy) * dy,
        );
        // Fades out as it arrives, right as the field's own prefix fades in.
        final opacity = (1 - const Interval(0.75, 1).transform(t)).clamp(
          0.0,
          1.0,
        );

        return Positioned(
          left: center.dx - 12,
          top: center.dy - 12,
          child: IgnorePointer(
            child: Opacity(
              opacity: opacity,
              child: Icon(
                Icons.search_rounded,
                size: 18 + 6 * t,
                color: Theme.of(context).colorScheme.primary,
              ),
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
  List<Widget> _buildFilterHeaderSlivers(
    BuildContext context,
    MovieViewModel vm,
    AppLocalizations l10n,
  ) {
    final height = _filterHeaderHeight;
    if (height == 0) return const [];

    final showFilters = _showFilterButtons;
    final showCategories = vm.mainCategories.isNotEmpty;
    final header = Column(
      mainAxisSize: MainAxisSize.min,
      // Stretch, otherwise each row shrinks to its content and gets centred.
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showFilters)
          SizedBox(height: _filterRowHeight, child: _buildFilterRow(vm, l10n)),
        if (showCategories)
          SizedBox(
            height: _categoryRowHeight,
            child: _buildCategoryRow(vm, l10n),
          ),
      ],
    );

    if (!_isFilterHeaderPinned(context)) {
      return [SliverToBoxAdapter(child: header)];
    }
    return [
      SliverPersistentHeader(
        pinned: true,
        delegate: _PinnedHeaderDelegate(
          height: height.toDouble(),
          color: Theme.of(context).scaffoldBackgroundColor,
          child: header,
        ),
      ),
    ];
  }

  Widget _buildFilterRow(MovieViewModel vm, AppLocalizations l10n) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      // Vertical padding leaves the neu shadow room inside the pinned header,
      // which clips to its own extent.
      padding: const EdgeInsets.fromLTRB(16, 5, 16, 5),
      clipBehavior: Clip.none,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (vm.countryCategories.isNotEmpty)
            _buildFilterButton(
              vm: vm,
              icon: Icons.public_rounded,
              fallbackLabel: l10n.countryLabel,
              options: vm.countryCategories,
              isCountry: true,
            ),
          if (vm.countryCategories.isNotEmpty && vm.genreCategories.isNotEmpty)
            const SizedBox(width: 10),
          if (vm.genreCategories.isNotEmpty)
            _buildFilterButton(
              vm: vm,
              icon: Icons.local_movies_rounded,
              fallbackLabel: l10n.genreLabel,
              options: vm.genreCategories,
              isCountry: false,
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryRow(MovieViewModel vm, AppLocalizations l10n) {
    final cats = vm.mainCategories;
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      clipBehavior: Clip.none,
      scrollDirection: Axis.horizontal,
      itemCount: cats.length,
      separatorBuilder: (_, _) => const SizedBox(width: 8),
      itemBuilder: (context, index) {
        final cat = cats[index];
        final isSelected =
            vm.collection == MovieCollection.browse &&
            cat.id == vm.selectedCategory?.id;

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
          onTap: () => _selectCategory(cat),
        );
      },
    );
  }

  /// A neu pill that opens the country / genre sheet and, once something is
  /// picked, shows the active value in place of its own label.
  Widget _buildFilterButton({
    required MovieViewModel vm,
    required IconData icon,
    required String fallbackLabel,
    required List<MovieCategory> options,
    required bool isCountry,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final selected = isCountry ? vm.selectedCountry : vm.selectedGenre;
    final isSelected = selected != null;
    final foreground = isSelected ? Colors.white : scheme.onSurfaceVariant;

    return NeuPress(
      onTap: () => _showFilterSheet(
        title: fallbackLabel,
        options: options,
        isCountry: isCountry,
      ),
      builder: (context, pressed) => AnimatedContainer(
        duration: NeuPress.duration,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: context.neu.raised(
          radius: 12,
          // Held down, the lift goes to nothing, as on every other neu surface.
          depth: pressed ? 0 : 0.6,
          color: isSelected ? scheme.primary : null,
          inset: isSelected,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: foreground),
            const SizedBox(width: 6),
            Text(
              selected?.name ?? fallbackLabel,
              maxLines: 1,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: foreground,
              ),
            ),
            Icon(Icons.expand_more_rounded, size: 18, color: foreground),
          ],
        ),
      ),
    );
  }

  /// The width [label] takes on one line in [style], measured once per label.
  double _labelWidth(String label, TextStyle style) {
    final key = (label, style);
    final cached = _movieLabelWidth;
    if (cached != null && _movieLabelWidthKey == key) return cached;
    final painter = TextPainter(
      text: TextSpan(text: label, style: style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();
    final width = painter.width;
    painter.dispose();
    _movieLabelWidthKey = key;
    return _movieLabelWidth = width;
  }

  /// The detail page for [movie], built the first time it is asked for and
  /// handed back unchanged after that. Its callbacks read the overlay's
  /// current state when they run, so the same instance stays correct.
  Widget _detailScreenFor(Movie movie) {
    final cached = _detailScreen;
    if (cached != null && identical(_detailScreenMovie, movie)) return cached;
    _detailScreenMovie = movie;
    return _detailScreen = ChangeNotifierProvider(
      create: (_) => MovieDetailViewModel(),
      child: MovieDetailScreen(
        movieUrl: movie.url,
        movieId: movie.id,
        initialMovie: movie,
        embedded: true,
        minimizeAnimation: _overlayController,
        controller: _detailController,
        onFullScreenChanged: (isFullScreen) {
          if (!mounted) return;
          // Full-screen video has to cover the bottom tab bar too when this
          // page is one of the tabs.
          immersiveMode.value = isFullScreen;
          setState(() => _isDetailFullScreen = isFullScreen);
        },
        onRelatedMovieTap: (related) => setState(() => _playingMovie = related),
        onClose: () => unawaited(_closeOverlay()),
        // Null takes the minimise button out of the header and the drag off
        // the player, so a television is not shown a way in to something it
        // cannot come back from.
        onMinimize: _canMinimize ? _minimizeOverlay : null,
        onPlayerDragUpdate: _canMinimize
            ? (details) => _onOverlayDragUpdate(details, _overlayTravel)
            : null,
        onPlayerDragEnd: _canMinimize ? _onOverlayDragEnd : null,
      ),
    );
  }

  /// The YouTube-style player: a rect that lerps between the tapped card (or
  /// the mini bar) and the whole screen, hosting the detail page inside.
  Widget _buildPlayerOverlay(BuildContext context, Movie movie, Size size) {
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
    _overlayTravel = travel;

    // Built out here, so the frames of the animation only move and fade them.
    final detail = _detailScreenFor(movie);
    final entryRect = _entryRect;
    final entryPoster = entryRect == null
        ? null
        : Positioned.fill(
            child: IgnorePointer(
              // The tapped poster, fading out over the page it grew from.
              // Decoded at the card's size, which is the copy the grid has
              // already cached.
              child: FadeTransition(
                opacity: ReverseAnimation(_overlayController),
                child: CachedNetworkImage(
                  imageUrl: movie.poster,
                  fit: BoxFit.cover,
                  memCacheWidth: posterDecodeWidth(context, entryRect.width),
                ),
              ),
            ),
          );

    return AnimatedBuilder(
      animation: _overlayController,
      builder: (context, _) {
        final t = _overlayController.value;
        final origin = _entryRect ?? miniRect;
        final rect = _isDetailFullScreen
            ? fullRect
            : Rect.lerp(origin, fullRect, t)!;
        final isMini = t < _miniThreshold;

        return Positioned.fromRect(
          rect: rect,
          child: Material(
            elevation: t < 1 ? 12 : 0,
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(14 * (1 - t)),
            clipBehavior: Clip.antiAlias,
            // The mini bar is a control, so a remote has to be able to land on
            // it. Focus lives outside the detector rather than replacing it:
            // the drag recognizers below are what a finger uses to fling the
            // player back up, and they have no keyboard equivalent to fold in.
            child: FocusableActionDetector(
              enabled: isMini,
              actions: {
                ActivateIntent: CallbackAction<ActivateIntent>(
                  onInvoke: (_) {
                    if (isMini) _expandOverlay();
                    return null;
                  },
                ),
              },
              child: GestureDetector(
                // Opaque so the browser list underneath never receives taps that
                // land on a gap of the overlay.
                behavior: HitTestBehavior.opaque,
                // Only the collapsed bar reacts to a tap; expanded, its own
                // widgets handle everything.
                onTap: isMini ? _expandOverlay : null,
                // Keeps working past the mini threshold once the drag has begun,
                // otherwise the recognizer would vanish mid-gesture.
                onVerticalDragStart: isMini || _isDraggingMiniBar
                    ? (_) => _isDraggingMiniBar = true
                    : null,
                onVerticalDragUpdate:
                    _canMinimize && (isMini || _isDraggingMiniBar)
                    ? (details) => _onOverlayDragUpdate(details, travel)
                    : null,
                onVerticalDragEnd:
                    _canMinimize && (isMini || _isDraggingMiniBar)
                    ? (details) {
                        _isDraggingMiniBar = false;
                        _onOverlayDragEnd(details);
                      }
                    : null,
                onVerticalDragCancel:
                    _canMinimize && (isMini || _isDraggingMiniBar)
                    ? () => _isDraggingMiniBar = false
                    : null,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    detail,
                    if (entryPoster != null && t < 1) entryPoster,
                  ],
                ),
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
                enabled: !vm.isFetching,
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
            NeuButton(
              onPressed: vm.isFetching
                  ? null
                  : () => _updateMovieServer(_serverUrlController.text),
              accent: Theme.of(context).colorScheme.primary,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (vm.isFetching)
                    const SizedBox.square(
                      dimension: 18,
                      child: Loading(size: 18, strokeWidth: 2),
                    )
                  else
                    const Icon(Icons.sync_rounded),
                  const SizedBox(width: 8),
                  Text(vm.isFetching ? l10n.syncing : l10n.saveAndSync),
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
  const _PinnedHeaderDelegate({
    required this.height,
    required this.color,
    required this.child,
  });

  final double height;
  final Color color;
  final Widget child;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox(
      height: height,
      child: ColoredBox(color: color, child: child),
    );
  }

  @override
  bool shouldRebuild(_PinnedHeaderDelegate oldDelegate) {
    return oldDelegate.height != height ||
        oldDelegate.color != color ||
        oldDelegate.child != child;
  }
}

/// One row of the television filter sheet: a category, or "All" when
/// [category] is null. Equality is by id, which is what lets the sheet mark
/// the row that is already active.
class _FilterOption {
  const _FilterOption(this.category, this.label);

  final MovieCategory? category;
  final String label;

  @override
  bool operator ==(Object other) =>
      other is _FilterOption && other.category?.id == category?.id;

  @override
  int get hashCode => category?.id.hashCode ?? 0;
}
