import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:do_x/constants/dimens.dart';
import 'package:do_x/extensions/widget_extensions.dart';
import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/model/tv_channel.dart';
import 'package:do_x/router/app_router.gr.dart';
import 'package:do_x/screen/tv/tv_channel_card.dart';
import 'package:do_x/view_model/tv/tv_view_model.dart';
import 'package:do_x/widgets/app_bar/app_bar_base.dart';
import 'package:do_x/widgets/app_scaffold.dart';
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
  final _scrollController = ScrollController();
  final Map<String, FocusNode> _channelFocusNodes = {};

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
          Expanded(child: _buildResults(viewModel, l10n)),
        ],
      ),
    );
  }

  Widget _buildField(TvViewModel viewModel, AppLocalizations l10n) {
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      onChanged: viewModel.search,
      textInputAction: TextInputAction.search,
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

    return GridView.builder(
      controller: _scrollController,
      padding: EdgeInsets.fromLTRB(
        Dimens.pagePadding,
        8,
        Dimens.pagePadding,
        MediaQuery.paddingOf(context).bottom + 24,
      ),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 150,
        childAspectRatio: 0.85,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: viewModel.channels.length,
      itemBuilder: (context, index) {
        final channel = viewModel.channels[index];
        return TvChannelCard(
          key: ValueKey(channel.url),
          channel: channel,
          focusNode: _focusNodeFor(channel.url),
          onTap: () => _openChannel(channel, viewModel.channels),
        );
      },
    ).contentConstrainedBox();
  }

  Future<void> _openChannel(TvChannel channel, List<TvChannel> playlist) async {
    // The results travel with the channel, exactly as the whole list does from
    // the channel page: up and down in the player move through what the viewer
    // was looking at.
    final finalChannel = await context.pushRoute<TvChannel?>(
      TvPlayerRoute(channel: channel, playlist: playlist),
    );
    if (!mounted) return;
    final target = finalChannel ?? channel;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _channelFocusNodes[target.url]?.requestFocus();
    });
  }
}
