import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:do_x/constants/dimens.dart';
import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/model/tv_channel.dart';
import 'package:do_x/router/app_router.gr.dart';
import 'package:do_x/screen/tv/tv_channel_card.dart';
import 'package:do_x/view_model/tv/tv_view_model.dart';
import 'package:do_x/widgets/app_bar/app_bar_base.dart';
import 'package:do_x/widgets/app_scaffold.dart';
import 'package:do_x/widgets/input/tv_search_keyboard.dart';
import 'package:do_x/widgets/loading.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Searching the channel list, as a page of its own.
///
/// A page rather than a box on the channel page: a television types with a
/// full-screen keyboard, so a field wedged into a page is half covered the
/// moment it is used — and the keyboard, the box and the results are then
/// fighting over one screen. Here the box is the top of the page, the results
/// fill the rest, and the way out is the app bar's back button.
///
/// [tvVm] is handed in rather than created here: the channels, the country and
/// the search are the channel page's view model, and filtering has to act on
/// that same instance so the page behind is the one the viewer left.
@RoutePage()
class TvSearchScreen extends StatefulWidget implements AutoRouteWrapper {
  const TvSearchScreen({super.key, required this.tvVm});

  final TvViewModel tvVm;

  @override
  State<TvSearchScreen> createState() => _TvSearchScreenState();

  @override
  Widget wrappedRoute(BuildContext context) =>
      ChangeNotifierProvider.value(value: tvVm, child: this);
}

class _TvSearchScreenState extends State<TvSearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode(debugLabel: 'tv-search');
  final _resultsFocusNode = TvSearchKeyboard.resultsNode(
    debugLabel: 'tv-search-results',
  );
  final _scrollController = ScrollController();
  final Map<String, FocusNode> _channelFocusNodes = {};

  /// The shape the results grid was last laid out at: how many cards to a
  /// row and how tall a card is. Worked out during layout, where the width
  /// is known, and kept here for [_revealChannel].
  int _gridColumns = 1;
  double _gridTileHeight = 1;

  /// The gap above the first row of results.
  static const _gridTopPadding = 8.0;

  @override
  void initState() {
    super.initState();
    // The keyboard is what this page is for, so the remote is put in the box
    // as the page arrives rather than after a press nobody would know to make.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    // The query belongs to this page, so it leaves with it: the channel page
    // is the whole country's list again, without the viewer having to clear a
    // box that is no longer on screen.
    final vm = widget.tvVm;
    scheduleMicrotask(() => vm.search(''));
    for (final node in _channelFocusNodes.values) {
      node.dispose();
    }
    _focusNode.dispose();
    _resultsFocusNode.dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  FocusNode _focusNodeFor(String url) {
    return _channelFocusNodes.putIfAbsent(
      url,
      () => FocusNode(debugLabel: 'tv-search-channel-$url'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final viewModel = context.watch<TvViewModel>();

    return AppScaffold(
      appBar: DoAppBar(title: l10n.tvSearchHint),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Dimens.pagePadding,
              8,
              Dimens.pagePadding,
              4,
            ),
            child: _buildField(viewModel, l10n),
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

  Widget _buildField(TvViewModel viewModel, AppLocalizations l10n) {
    return TvSearchKeyboard(
      field: _focusNode,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        onChanged: viewModel.search,
        textInputAction: TextInputAction.search,
        onEditingComplete: () {
          // The query as it stands, not as it was a debounce ago.
          viewModel.search(_controller.text, immediately: true);
          TvSearchKeyboard.submit(
            field: _focusNode,
            results: _resultsFocusNode,
          );
        },
        decoration: InputDecoration(
          hintText: l10n.tvSearchHint,
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: _controller.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear_rounded),
                  onPressed: () {
                    _controller.clear();
                    viewModel.search('');
                    setState(() {});
                  },
                ),
        ),
      ),
    );
  }

  Widget _buildResults(TvViewModel viewModel, AppLocalizations l10n) {
    if (viewModel.isLoading) return const Center(child: Loading());
    if (viewModel.channels.isEmpty) {
      return Padding(
        padding: Dimens.screenPadding,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 12,
          children: [
            Icon(
              Icons.live_tv_rounded,
              size: 48,
              color: Theme.of(context).disabledColor,
            ),
            Text(l10n.tvNoResults, textAlign: TextAlign.center),
          ],
        ),
      );
    }

    // The same tiles as the channel page, at the same size and full width:
    // these are the same cards the viewer was just looking at, and a search
    // that reshapes them into a narrower strip reads as a different list.
    return LayoutBuilder(
      builder: (context, constraints) {
        // The arithmetic `SliverGridDelegateWithMaxCrossAxisExtent` does,
        // spelled out because coming back from the player needs the answer
        // too: which row a channel is on, and how far down that is.
        final width = constraints.maxWidth - Dimens.pagePadding * 2;
        final columns =
            (width /
                    (Dimens.tvChannelTileMaxWidth +
                        Dimens.tvChannelTileSpacing))
                .ceil()
                .clamp(1, viewModel.channels.length);
        final tileWidth =
            (width - Dimens.tvChannelTileSpacing * (columns - 1)) / columns;
        _gridColumns = columns;
        _gridTileHeight = tileWidth / Dimens.tvChannelTileAspect;

        return GridView.builder(
          controller: _scrollController,
          padding: EdgeInsets.fromLTRB(
            Dimens.pagePadding,
            _gridTopPadding,
            Dimens.pagePadding,
            MediaQuery.paddingOf(context).bottom + 24,
          ),
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: Dimens.tvChannelTileMaxWidth,
            childAspectRatio: Dimens.tvChannelTileAspect,
            crossAxisSpacing: Dimens.tvChannelTileSpacing,
            mainAxisSpacing: Dimens.tvChannelTileSpacing,
          ),
          itemCount: viewModel.channels.length,
          itemBuilder: (context, index) {
            final channel = viewModel.channels[index];
            return TvChannelCard(
              key: ValueKey(channel.url),
              channel: channel,
              focusNode: _focusNodeFor(channel.url),
              onTap: () => _openChannel(channel, viewModel.allChannels),
            );
          },
        );
      },
    );
  }

  Future<void> _openChannel(TvChannel channel, List<TvChannel> playlist) async {
    // The whole country travels with the channel, not the results. A search
    // usually comes down to one match, and a player handed a list of one has
    // no channel list to open and no channel to move to — the viewer presses
    // OK on the remote and nothing happens. The query was how they found the
    // channel; it is not what the remote should be shut inside afterwards.
    final finalChannel = await context.pushRoute<TvChannel?>(
      TvPlayerRoute(channel: channel, playlist: playlist),
    );
    if (!mounted) return;
    _restoreFocusTo(finalChannel ?? channel);
  }

  /// Brings the results back to the channel the viewer came out of the player
  /// on, and puts the remote on it.
  ///
  /// Not [FocusNode.requestFocus] on its own. After channel-surfing the tile
  /// may be rows outside the range the grid has built, so its node has no
  /// parent and the request is a silent no-op — the shell then rescues the
  /// homeless focus onto the app bar, and the results are left at the top.
  /// So the row is scrolled to first, which is what builds the tile, and only
  /// the frame after that is the remote handed to it.
  void _restoreFocusTo(TvChannel target) {
    // The results list, not the playlist the player was handed: that is the
    // whole country, and this grid only shows what the query matched.
    final index = widget.tvVm.channels.indexWhere((c) => c.url == target.url);
    if (index >= 0) _revealChannel(index);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final node = _channelFocusNodes[target.url];
      if (node == null) return;
      node.requestFocus();
      final nodeContext = node.context;
      if (nodeContext == null) return;
      // The jump above was worked out from the last layout; this settles the
      // tile exactly where a focused tile belongs.
      unawaited(
        Scrollable.ensureVisible(
          nodeContext,
          alignment: Dimens.tvFocusScrollAlignment,
        ),
      );
    });
  }

  /// Scrolls the row [index] sits on into the middle of the viewport.
  void _revealChannel(int index) {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final rowStride = _gridTileHeight + Dimens.tvChannelTileSpacing;
    final target =
        _gridTopPadding +
        (index ~/ _gridColumns) * rowStride -
        (position.viewportDimension - _gridTileHeight) *
            Dimens.tvFocusScrollAlignment;
    _scrollController.jumpTo(
      target.clamp(position.minScrollExtent, position.maxScrollExtent),
    );
  }
}
