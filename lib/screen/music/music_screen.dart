import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:do_x/constants/dimens.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/model/music_track.dart';
import 'package:do_x/router/app_router.gr.dart';
import 'package:do_x/screen/core/screen_state.dart';
import 'package:do_x/screen/music/music_track_card.dart';
import 'package:do_x/utils/device_type.dart';
import 'package:do_x/view_model/music/music_view_model.dart';
import 'package:do_x/widgets/app_bar/app_bar_base.dart';
import 'package:do_x/widgets/app_bar/app_bar_sync_icon.dart';
import 'package:do_x/widgets/app_scaffold.dart';
import 'package:do_x/widgets/focusable_tap.dart';
import 'package:do_x/widgets/loading.dart';
import 'package:do_x/widgets/neu/neu_button.dart';
import 'package:do_x/widgets/neu/neu_card.dart';
import 'package:do_x/widgets/neu/neu_surface.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Top level so the sync badge can be `const`: a closure written inline is a
/// new object every build, and the badge would rebuild with it.
bool _isLoading(MusicViewModel vm) => vm.isLoading;

@RoutePage()
class MusicScreen extends StatefulScreen implements AutoRouteWrapper {
  const MusicScreen({super.key});

  @override
  State<MusicScreen> createState() => _MusicScreenState();

  @override
  Widget wrappedRoute(BuildContext context) {
    return ChangeNotifierProvider(create: (_) => MusicViewModel(), child: this);
  }
}

class _MusicScreenState extends ScreenState<MusicScreen, MusicViewModel> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode(debugLabel: 'tv-music-search');
  final Map<String, FocusNode> _trackFocusNodes = {};

  /// The heart on each row. Its own node, because on a television the remote
  /// is put on it by hand — see [MusicTrackCard].
  final Map<String, FocusNode> _likeFocusNodes = {};

  final FocusNode _playPauseFocusNode = FocusNode(debugLabel: 'tv-music-play');
  final FocusNode _nextFocusNode = FocusNode(debugLabel: 'tv-music-next');
  final FocusNode _prevFocusNode = FocusNode(debugLabel: 'tv-music-prev');
  final FocusNode _shuffleFocusNode = FocusNode(debugLabel: 'tv-music-shuffle');
  final FocusNode _repeatFocusNode = FocusNode(debugLabel: 'tv-music-repeat');
  final FocusNode _likeActionFocusNode = FocusNode(
    debugLabel: 'tv-music-like-action',
  );

  FocusNode _getNodeForTrack(String id) {
    return _trackFocusNodes.putIfAbsent(
      id,
      () => FocusNode(debugLabel: 'tv-track-$id'),
    );
  }

  FocusNode _getLikeNodeForTrack(String id) {
    return _likeFocusNodes.putIfAbsent(
      id,
      () => FocusNode(debugLabel: 'tv-track-like-$id'),
    );
  }

  @override
  void dispose() {
    for (final node in _trackFocusNodes.values) {
      node.dispose();
    }
    for (final node in _likeFocusNodes.values) {
      node.dispose();
    }
    _searchFocusNode.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    _playPauseFocusNode.dispose();
    _nextFocusNode.dispose();
    _prevFocusNode.dispose();
    _shuffleFocusNode.dispose();
    _repeatFocusNode.dispose();
    _likeActionFocusNode.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<MusicViewModel>();
    final isTv = deviceType.isTv;
    final l10n = context.l10n;

    final pageTitle = l10n.tvCategoryMusic;

    final mainContent = isTv
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTvSidebarNavigation(viewModel),
              Container(
                width: 1,
                color: context.theme.dividerColor.withValues(alpha: 0.1),
              ),
              Expanded(flex: 3, child: _buildMainBodyArea(viewModel, isTv)),
              Container(
                width: 1,
                color: context.theme.dividerColor.withValues(alpha: 0.1),
              ),
              Expanded(flex: 2, child: _buildRightPlayerDashboard(viewModel)),
            ],
          )
        : Column(
            children: [
              _buildMobileTabs(viewModel),
              Expanded(child: _buildMainBodyArea(viewModel, isTv)),
              _buildBottomMobilePlayer(viewModel),
            ],
          );

    return AppScaffold(
      // On a television the rail is the leftmost thing on the page, exactly as
      // it is on the home page — so it takes the screen's edge and the columns
      // apply their own insets. Inset here instead, the rail sat a safe area
      // *and* its own margin away from the edge while its other side had only
      // the margin, and it leaned to the right.
      bodyHorizontal: !isTv,
      appBar: DoAppBar(
        title: pageTitle,
        actions: [_buildAccountAction(viewModel)],
        titleSuffix: const AppBarSyncIcon<MusicViewModel>(selector: _isLoading),
      ),
      body: mainContent,
    );
  }

  /// The account the personal endpoints are called for. An icon rather than a
  /// tab: signing in is something you do once, and the page works without it
  /// for everything but the likes.
  Widget _buildAccountAction(MusicViewModel viewModel) {
    final l10n = context.l10n;
    final isSignedIn = viewModel.isSignedIn;
    return IconButton(
      tooltip: isSignedIn && viewModel.accountName.isNotEmpty
          ? l10n.musicSignedInAs(viewModel.accountName)
          : l10n.musicSignedOut,
      icon: Icon(
        isSignedIn ? Icons.account_circle_rounded : Icons.login_rounded,
        color: isSignedIn ? context.theme.colorScheme.primary : null,
      ),
      onPressed: _openMusicLogin,
    );
  }

  Future<bool> _openMusicLogin() async {
    final signedIn = await context.router.push<bool>(const MusicLoginRoute());
    return signedIn ?? false;
  }

  /// A heart that needs an account sends the user to the sign-in page instead
  /// of failing where they cannot see it, and finishes the like they asked for
  /// once they are back.
  Future<void> _onToggleLike(MusicTrack track) async {
    final l10n = context.l10n;
    final outcome = await vm.toggleLike(track);
    if (!mounted) return;
    switch (outcome) {
      case MusicLikeOutcome.done:
        break;
      case MusicLikeOutcome.signInRequired:
        context.showToast(l10n.musicSignInRequired);
        final signedIn = await _openMusicLogin();
        if (signedIn && mounted) await vm.toggleLike(track);
      case MusicLikeOutcome.failed:
        context.showToast(l10n.musicLikeFailed, isError: true);
    }
  }

  /// The tab rail, in the shape the home page's rail already has.
  ///
  /// Same rows, same numbers: a tinted plate behind the selected one rather
  /// than a raised button, the icon and label in the primary colour, and the
  /// rail only as wide as its longest label. A second rail with a style of its
  /// own reads as a different app one screen along.
  Widget _buildTvSidebarNavigation(MusicViewModel viewModel) {
    final l10n = context.l10n;
    return ColoredBox(
      color: context.neu.base,
      // Its own margin, top and bottom clearing the television's overscan
      // band; the sides are a plain margin, as on the home page's rail.
      child: SafeArea(
        left: false,
        right: false,
        child: Padding(
          // The same margin all round, so the rows sit as far from the screen's
          // edge as they do from the divider on their other side.
          padding: const EdgeInsets.all(Dimens.tvRailPadding),
          child: IntrinsicWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              // From the top, level with the first row of the list beside it.
              mainAxisAlignment: MainAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildRailItem(
                  viewModel,
                  MusicTab.home,
                  Icons.library_music_rounded,
                  l10n.musicTabDiscover,
                ),
                _buildRailItem(
                  viewModel,
                  MusicTab.search,
                  Icons.search_rounded,
                  l10n.musicTabSearch,
                ),
                _buildRailItem(
                  viewModel,
                  MusicTab.likes,
                  Icons.favorite_rounded,
                  l10n.musicTabLikes,
                ),
                _buildRailItem(
                  viewModel,
                  MusicTab.history,
                  Icons.history_rounded,
                  l10n.musicTabHistory,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRailItem(
    MusicViewModel viewModel,
    MusicTab tab,
    IconData icon,
    String label,
  ) {
    final scheme = context.theme.colorScheme;
    final isSelected = viewModel.currentTab == tab;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: FocusableTap(
        onTap: () => viewModel.switchTab(tab),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isSelected ? context.neuTint(scheme.primary) : null,
            borderRadius: BorderRadius.circular(Dimens.radiusControl),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              spacing: 12,
              children: [
                Icon(
                  icon,
                  size: 24,
                  color: isSelected ? scheme.primary : scheme.onSurfaceVariant,
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? scheme.primary : scheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileTabs(MusicViewModel viewModel) {
    final l10n = context.l10n;
    Widget tabItem(MusicTab tab, IconData icon, String label) {
      final isSelected = viewModel.currentTab == tab;
      return Expanded(
        child: InkWell(
          onTap: () => viewModel.switchTab(tab),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isSelected
                      ? context.theme.colorScheme.primary
                      : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isSelected
                      ? context.theme.colorScheme.primary
                      : context.theme.hintColor,
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: isSelected
                        ? context.theme.colorScheme.primary
                        : context.theme.hintColor,
                    fontWeight: isSelected ? FontWeight.bold : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: Row(
        children: [
          tabItem(
            MusicTab.home,
            Icons.library_music_rounded,
            l10n.musicTabDiscover,
          ),
          tabItem(MusicTab.search, Icons.search_rounded, l10n.musicTabSearch),
          tabItem(MusicTab.likes, Icons.favorite_rounded, l10n.musicTabLikes),
          tabItem(
            MusicTab.history,
            Icons.history_rounded,
            l10n.musicTabHistory,
          ),
        ],
      ),
    );
  }

  Widget _buildMainBodyArea(MusicViewModel viewModel, bool isTv) {
    if (viewModel.isLoading &&
        (viewModel.currentTab == MusicTab.home && viewModel.shelves.isEmpty)) {
      return const Center(child: Loading());
    }

    switch (viewModel.currentTab) {
      case MusicTab.home:
        return _buildDiscoverHome(viewModel, isTv);
      case MusicTab.search:
        return _buildSearchTab(viewModel);
      case MusicTab.likes:
        return _buildTrackListSection(
          viewModel.likedTracks,
          'Bài hát yêu thích',
          Icons.favorite_border_rounded,
        );
      case MusicTab.history:
        return _buildTrackListSection(
          viewModel.historyTracks,
          'Lịch sử đã nghe',
          Icons.history_rounded,
        );
    }
  }

  Widget _buildDiscoverHome(MusicViewModel viewModel, bool isTv) {
    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        // The rows, and their headings, are whatever the service sent for this
        // account — so the page is built from them rather than from a fixed
        // pair of sections.
        for (final shelf in viewModel.shelves) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                shelf.title,
                style: TextStyle(
                  fontSize: isTv ? 14 : 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          _buildSliverGrid(shelf.tracks),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  Widget _buildSearchTab(MusicViewModel viewModel) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            textInputAction: TextInputAction.search,
            onChanged: (value) {
              viewModel.searchTracks(value);
              setState(() {});
            },
            decoration: InputDecoration(
              hintText: context.l10n.musicSearchHint,
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () {
                        _searchController.clear();
                        viewModel.searchTracks('');
                        setState(() {});
                      },
                    ),
            ),
          ),
        ),
        Expanded(
          child: viewModel.isLoading
              ? const Center(child: Loading())
              : viewModel.searchResults.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    spacing: 8,
                    children: [
                      Icon(
                        Icons.search_off_rounded,
                        size: 48,
                        color: context.theme.disabledColor,
                      ),
                      const Text('Nhập từ khóa để tìm kiếm nhạc...'),
                    ],
                  ),
                )
              : CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.all(4),
                      sliver: _buildSliverGrid(viewModel.searchResults),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildTrackListSection(
    List<MusicTrack> tracks,
    String emptyTitle,
    IconData emptyIcon,
  ) {
    if (tracks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 8,
          children: [
            Icon(emptyIcon, size: 48, color: context.theme.disabledColor),
            Text('Danh sách trống ($emptyTitle)'),
          ],
        ),
      );
    }
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(8),
          sliver: _buildSliverGrid(tracks),
        ),
      ],
    );
  }

  /// The list of tracks.
  ///
  /// One row per line whatever the screen: a row is artwork, a title, an
  /// artist and a heart laid out across, and two of them side by side on a
  /// television left the title a dozen pixels wide — the artwork is a square
  /// as tall as the row, so a short column is a wide picture and no words.
  /// The height is fixed for the same reason, rather than being whatever an
  /// aspect ratio makes of the column's width.
  Widget _buildSliverGrid(List<MusicTrack> trackList) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 1,
          mainAxisExtent: Dimens.musicTrackTileHeight,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        delegate: SliverChildBuilderDelegate((context, index) {
          final track = trackList[index];
          final vModel = context.read<MusicViewModel>();
          return MusicTrackCard(
            key: ValueKey(track.id),
            track: track,
            isCurrent: vModel.currentTrack?.id == track.id,
            isLiked: vModel.isLiked(track.id),
            focusNode: _getNodeForTrack(track.id),
            likeFocusNode: _getLikeNodeForTrack(track.id),
            onTap: () => vModel.playTrack(track),
            onToggleLike: () => _onToggleLike(track),
          );
        }, childCount: trackList.length),
      ),
    );
  }

  /// Wraps a seek bar so the remote can get back off it.
  ///
  /// A [Slider] binds all four arrows to its own value, and its shortcuts sit
  /// closer to the focus than anything a page can put around it — so on a
  /// television the D-pad walked onto the seek bar and stayed there for good.
  /// In directional navigation mode the slider claims left and right only and
  /// leaves up and down to move the focus, which is exactly the split a remote
  /// wants. Declared here rather than app-wide: the mode also makes every
  /// `InkWell` focusable, which is why `TvShell` does not turn it on.
  Widget _seekable(Widget slider) {
    if (!deviceType.isTv) return slider;
    return MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(navigationMode: NavigationMode.directional),
      child: slider,
    );
  }

  Widget _buildRightPlayerDashboard(MusicViewModel viewModel) {
    return SafeArea(
      top: false,
      left: false,
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (viewModel.currentTrack == null) ...[
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  spacing: 12,
                  children: [
                    Icon(
                      Icons.radio_rounded,
                      size: 72,
                      color: context.theme.colorScheme.primary.withValues(
                        alpha: 0.4,
                      ),
                    ),
                    const Text(
                      'Chọn bài hát để thưởng thức âm nhạc chất lượng cao',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(Dimens.radiusPanel),
                        boxShadow: [
                          BoxShadow(
                            color: context.theme.shadowColor.withValues(
                              alpha: 0.2,
                            ),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(Dimens.radiusPanel),
                        child: viewModel.currentTrack!.artworkUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: viewModel.currentTrack!.artworkUrl,
                                fit: BoxFit.cover,
                                placeholder: (_, _) =>
                                    const Center(child: Loading()),
                                errorWidget: (_, _, _) => Icon(
                                  Icons.music_note_rounded,
                                  size: 64,
                                  color: context.theme.disabledColor,
                                ),
                              )
                            : Icon(
                                Icons.music_note_rounded,
                                size: 64,
                                color: context.theme.disabledColor,
                              ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                viewModel.currentTrack!.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                viewModel.currentTrack!.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: context.theme.hintColor, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              _buildPlayerControls(viewModel),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBottomMobilePlayer(MusicViewModel viewModel) {
    if (viewModel.currentTrack == null) return const SizedBox.shrink();
    final isTrackLiked = viewModel.isLiked(viewModel.currentTrack!.id);
    return NeuCard(
      margin: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(
                    Dimens.radiusControlSmall,
                  ),
                  child: SizedBox.square(
                    dimension: 44,
                    child: viewModel.currentTrack!.artworkUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: viewModel.currentTrack!.artworkUrl,
                            fit: BoxFit.cover,
                          )
                        : const Icon(Icons.music_note_rounded),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        viewModel.currentTrack!.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        viewModel.currentTrack!.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.theme.hintColor,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    isTrackLiked
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    size: 20,
                  ),
                  color: isTrackLiked
                      ? context.theme.colorScheme.error
                      : context.theme.hintColor,
                  onPressed: () => _onToggleLike(viewModel.currentTrack!),
                ),
                IconButton(
                  icon: Icon(
                    viewModel.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                  ),
                  onPressed: viewModel.togglePlay,
                ),
                IconButton(
                  icon: const Icon(Icons.skip_next_rounded),
                  onPressed: viewModel.nextTrack,
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 8),
              activeTrackColor: context.theme.colorScheme.primary,
              inactiveTrackColor: context.theme.disabledColor.withValues(
                alpha: 0.2,
              ),
              thumbColor: context.theme.colorScheme.primary,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: _seekable(
                Slider(
                  value: viewModel.position.inMilliseconds.toDouble().clamp(
                    0.0,
                    viewModel.duration.inMilliseconds.toDouble(),
                  ),
                  max: viewModel.duration.inMilliseconds.toDouble() == 0.0
                      ? 1.0
                      : viewModel.duration.inMilliseconds.toDouble(),
                  onChanged: (val) {
                    viewModel.seekTo(Duration(milliseconds: val.toInt()));
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerControls(MusicViewModel viewModel) {
    final isTrackLiked = viewModel.isLiked(viewModel.currentTrack!.id);
    return Column(
      children: [
        _seekable(
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            ),
            child: Slider(
              value: viewModel.position.inMilliseconds.toDouble().clamp(
                0.0,
                viewModel.duration.inMilliseconds.toDouble(),
              ),
              max: viewModel.duration.inMilliseconds.toDouble() == 0.0
                  ? 1.0
                  : viewModel.duration.inMilliseconds.toDouble(),
              onChanged: (val) {
                viewModel.seekTo(Duration(milliseconds: val.toInt()));
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(viewModel.position),
                style: TextStyle(fontSize: 12, color: context.theme.hintColor),
              ),
              Text(
                _formatDuration(viewModel.duration),
                style: TextStyle(fontSize: 12, color: context.theme.hintColor),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            NeuIconButton(
              icon: viewModel.isShuffleEnabled
                  ? Icons.shuffle_on_rounded
                  : Icons.shuffle_rounded,
              focusNode: _shuffleFocusNode,
              size: 36,
              onPressed: viewModel.toggleShuffle,
            ),
            NeuIconButton(
              icon: Icons.skip_previous_rounded,
              focusNode: _prevFocusNode,
              size: 36,
              onPressed: viewModel.previousTrack,
            ),
            NeuIconButton(
              icon: viewModel.isPlaying
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
              focusNode: _playPauseFocusNode,
              size: 44,
              onPressed: viewModel.togglePlay,
            ),
            NeuIconButton(
              icon: Icons.skip_next_rounded,
              focusNode: _nextFocusNode,
              size: 36,
              onPressed: viewModel.nextTrack,
            ),
            NeuIconButton(
              icon: isTrackLiked
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              focusNode: _likeActionFocusNode,
              size: 36,
              color: isTrackLiked ? context.theme.colorScheme.error : null,
              onPressed: () => _onToggleLike(viewModel.currentTrack!),
            ),
          ],
        ),
      ],
    );
  }
}
