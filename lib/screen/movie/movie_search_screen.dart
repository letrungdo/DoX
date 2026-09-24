import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:do_x/constants/dimens.dart';
import 'package:do_x/extensions/widget_extensions.dart';
import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/model/movie_model.dart';
import 'package:do_x/screen/movie/movie_poster_card.dart';
import 'package:do_x/view_model/movie/movie_view_model.dart';
import 'package:do_x/widgets/app_bar/app_bar_base.dart';
import 'package:do_x/widgets/app_scaffold.dart';
import 'package:do_x/widgets/input/tv_search_keyboard.dart';
import 'package:do_x/widgets/loading.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// What a picked search result carries back to the movie page: the film, and
/// the card it was picked from, so the player still zooms out of that poster.
typedef MovieSearchPick = ({Movie movie, Rect cardRect});

/// Searching the movie library, as a page of its own.
///
/// A page rather than a field on the browser: a television types with a
/// full-screen keyboard, which covers a field wedged into a page as soon as it
/// is used. Here the box is the top of the page, the results fill the rest,
/// and the way out is the app bar's back button.
///
/// [movieVm] is handed in rather than created here: searching is the browser's
/// own view model asking its server, and a second instance would fetch the
/// whole library again just to throw it away.
@RoutePage()
class MovieSearchScreen extends StatefulWidget implements AutoRouteWrapper {
  const MovieSearchScreen({super.key, required this.movieVm});

  final MovieViewModel movieVm;

  @override
  State<MovieSearchScreen> createState() => _MovieSearchScreenState();

  @override
  Widget wrappedRoute(BuildContext context) =>
      ChangeNotifierProvider.value(value: movieVm, child: this);
}

class _MovieSearchScreenState extends State<MovieSearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode(debugLabel: 'movie-search');
  final _resultsFocusNode = TvSearchKeyboard.resultsNode(
    debugLabel: 'movie-search-results',
  );
  final _scrollController = ScrollController();
  Timer? _debounce;

  /// How long the box waits before asking the server, so typing a title is one
  /// request rather than one per letter.
  static const _debounceDelay = Duration(milliseconds: 500);

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // The keyboard is what this page is for, so the remote starts in the box.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focusNode.dispose();
    _resultsFocusNode.dispose();
    _controller.dispose();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  /// The next page of results, once the grid is near its end — the browser's
  /// own behaviour, because this is the browser's list.
  void _onScroll() {
    final position = _scrollController.position;
    if (position.pixels < position.maxScrollExtent - 400) return;
    final vm = widget.movieVm;
    if (vm.isLoadingMore || vm.isLoading) return;
    unawaited(vm.loadMoreMovies());
  }

  void _onQueryChanged(String query) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(_debounceDelay, () => _search(query));
  }

  Future<void> _search(String query) {
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    return widget.movieVm.setSearchQuery(query);
  }

  /// The keyboard's Search key: the typing is over, so the query goes to the
  /// server now rather than when the debounce runs out, and the remote goes
  /// to its results once they are back.
  void _onSubmitted() {
    _debounce?.cancel();
    TvSearchKeyboard.submit(
      field: _focusNode,
      results: _resultsFocusNode,
      pending: _search(_controller.text),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final viewModel = context.watch<MovieViewModel>();

    return AppScaffold(
      appBar: DoAppBar(title: l10n.searchMoviesPlaceholder),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Dimens.pagePadding,
              8,
              Dimens.pagePadding,
              4,
            ),
            child: _buildField(l10n),
          ),
          Expanded(
            child: Focus(
              focusNode: _resultsFocusNode,
              child: _buildResults(viewModel, l10n),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField(AppLocalizations l10n) {
    final scheme = Theme.of(context).colorScheme;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(Dimens.radiusControl),
      borderSide: BorderSide(color: scheme.outlineVariant, width: 1),
    );
    return TvSearchKeyboard(
      field: _focusNode,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        onChanged: _onQueryChanged,
        textInputAction: TextInputAction.search,
        onEditingComplete: _onSubmitted,
        decoration: InputDecoration(
          hintText: l10n.searchMoviesPlaceholder,
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: _controller.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear_rounded),
                  onPressed: () {
                    _controller.clear();
                    _onQueryChanged('');
                  },
                ),
          isDense: true,
          filled: true,
          fillColor: scheme.surface,
          border: border,
          enabledBorder: border,
        ),
      ),
    );
  }

  Widget _buildResults(MovieViewModel viewModel, AppLocalizations l10n) {
    if (viewModel.isLoading && viewModel.movies.isEmpty) {
      return const Center(child: Loading());
    }
    if (viewModel.movies.isEmpty) {
      return Padding(
        padding: Dimens.screenPadding,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 12,
          children: [
            Icon(
              Icons.movie_outlined,
              size: 48,
              color: Theme.of(context).disabledColor,
            ),
            Text(l10n.noMoviesFound, textAlign: TextAlign.center),
          ],
        ),
      );
    }

    final loadingMore = viewModel.isLoadingMore ? 2 : 0;
    return GridView.builder(
      controller: _scrollController,
      padding: EdgeInsets.fromLTRB(
        Dimens.pagePadding,
        8,
        Dimens.pagePadding,
        MediaQuery.paddingOf(context).bottom + 24,
      ),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        childAspectRatio: 1.0,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: viewModel.movies.length + loadingMore,
      itemBuilder: (context, index) {
        if (index >= viewModel.movies.length) {
          return const Card(child: Center(child: Loading()));
        }
        final movie = viewModel.movies[index];
        final libraryState = viewModel.libraryStates[movie.id];
        return MoviePosterCard(
          movie: movie,
          isWatched: libraryState?.watchedAt != null,
          isFavorite: libraryState?.isFavorite ?? false,
          libraryState: libraryState,
          // The film is opened by the page behind, where the player lives as
          // an overlay over the grid — so the pick is handed back rather than
          // played here.
          onTap: (cardRect) =>
              Navigator.of(context).pop((movie: movie, cardRect: cardRect)),
        );
      },
    ).contentConstrainedBox();
  }
}
