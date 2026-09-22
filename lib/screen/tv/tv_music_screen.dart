import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:do_x/constants/dimens.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/model/music_track.dart';
import 'package:do_x/router/app_router.gr.dart';
import 'package:do_x/screen/core/screen_state.dart';
import 'package:do_x/utils/device_type.dart';
import 'package:do_x/view_model/tv/tv_music_view_model.dart';
import 'package:do_x/widgets/app_bar/app_bar_base.dart';
import 'package:do_x/widgets/app_scaffold.dart';
import 'package:do_x/widgets/loading.dart';
import 'package:do_x/widgets/neu/neu_button.dart';
import 'package:do_x/widgets/neu/neu_card.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

@RoutePage()
class TvMusicScreen extends StatefulScreen implements AutoRouteWrapper {
  const TvMusicScreen({super.key});

  @override
  State<TvMusicScreen> createState() => _TvMusicScreenState();

  @override
  Widget wrappedRoute(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => TvMusicViewModel(),
      child: this,
    );
  }
}

class _TvMusicScreenState extends ScreenState<TvMusicScreen, TvMusicViewModel> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode(debugLabel: 'tv-music-search');
  final Map<String, FocusNode> _trackFocusNodes = {};

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

  @override
  void dispose() {
    for (final node in _trackFocusNodes.values) {
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

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<TvMusicViewModel>();
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
      appBar: DoAppBar(
        title: pageTitle,
        actions: [_buildAccountAction(viewModel)],
        titleSuffix: viewModel.isLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: context.theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(Dimens.radiusTiny),
                ),
                child: const Text(
                  'CLOUD LIVE',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
      ),
      body: mainContent,
    );
  }

  /// The account the personal endpoints are called for. An icon rather than a
  /// tab: signing in is something you do once, and the page works without it
  /// for everything but the likes.
  Widget _buildAccountAction(TvMusicViewModel viewModel) {
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

  Widget _buildTvSidebarNavigation(TvMusicViewModel viewModel) {
    Widget navItem(MusicTab tab, IconData icon, String label) {
      final isSelected = viewModel.currentTab == tab;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
        child: NeuButton(
          onPressed: () => viewModel.switchTab(tab),
          accent: isSelected
              ? context.theme.colorScheme.primaryContainer
              : null,
          expand: true,
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? context.theme.colorScheme.primary : null,
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      width: 160,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          navItem(MusicTab.home, Icons.library_music_rounded, 'Khám phá'),
          navItem(MusicTab.search, Icons.search_rounded, 'Tìm kiếm'),
          navItem(MusicTab.likes, Icons.favorite_rounded, 'Yêu thích'),
          navItem(MusicTab.history, Icons.history_rounded, 'Lịch sử'),
        ],
      ),
    );
  }

  Widget _buildMobileTabs(TvMusicViewModel viewModel) {
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
          tabItem(MusicTab.home, Icons.library_music_rounded, 'Khám phá'),
          tabItem(MusicTab.search, Icons.search_rounded, 'Tìm kiếm'),
          tabItem(MusicTab.likes, Icons.favorite_rounded, 'Yêu thích'),
          tabItem(MusicTab.history, Icons.history_rounded, 'Lịch sử'),
        ],
      ),
    );
  }

  Widget _buildMainBodyArea(TvMusicViewModel viewModel, bool isTv) {
    if (viewModel.isLoading &&
        (viewModel.currentTab == MusicTab.home &&
            viewModel.trendingTracks.isEmpty)) {
      return const Center(child: Loading());
    }

    switch (viewModel.currentTab) {
      case MusicTab.home:
        return _buildDiscoverHome(viewModel, isTv);
      case MusicTab.search:
        return _buildSearchTab(viewModel, isTv);
      case MusicTab.likes:
        return _buildTrackListSection(
          viewModel.likedTracks,
          isTv,
          'Bài hát yêu thích',
          Icons.favorite_border_rounded,
        );
      case MusicTab.history:
        return _buildTrackListSection(
          viewModel.historyTracks,
          isTv,
          'Lịch sử đã nghe',
          Icons.history_rounded,
        );
    }
  }

  Widget _buildDiscoverHome(TvMusicViewModel viewModel, bool isTv) {
    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'More of what you like',
              style: TextStyle(
                fontSize: isTv ? 14 : 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        _buildSliverGrid(viewModel.recommendedTracks, isTv),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Text(
              'Trending Music & Mixes',
              style: TextStyle(
                fontSize: isTv ? 14 : 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        _buildSliverGrid(viewModel.trendingTracks, isTv),
        SliverToBoxAdapter(child: const SizedBox(height: 24)),
      ],
    );
  }

  Widget _buildSearchTab(TvMusicViewModel viewModel, bool isTv) {
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
                      sliver: _buildSliverGrid(viewModel.searchResults, isTv),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildTrackListSection(
    List<MusicTrack> tracks,
    bool isTv,
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
          sliver: _buildSliverGrid(tracks, isTv),
        ),
      ],
    );
  }

  Widget _buildSliverGrid(List<MusicTrack> trackList, bool isTv) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: isTv ? 2 : 1,
          childAspectRatio: isTv ? 1.4 : 3.8,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        delegate: SliverChildBuilderDelegate((context, index) {
          final track = trackList[index];
          final vModel = context.read<TvMusicViewModel>();
          final isCurrent = vModel.currentTrack?.id == track.id;
          final isTrackLiked = vModel.isLiked(track.id);

          return Focus(
            canRequestFocus: false,
            skipTraversal: true,
            onFocusChange: (hasFocus) {
              if (hasFocus && isTv) {
                Scrollable.ensureVisible(
                  context,
                  alignment: Dimens.tvFocusScrollAlignment,
                  duration: Dimens.tvFocusScrollDuration,
                );
              }
            },
            child: NeuCard(
              focusNode: _getNodeForTrack(track.id),
              onTap: () => vModel.playTrack(track),
              color: isCurrent
                  ? context.theme.colorScheme.primaryContainer.withValues(
                      alpha: 0.7,
                    )
                  : null,
              child: Row(
                children: [
                  AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      margin: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(
                          Dimens.radiusControlSmall,
                        ),
                        image: track.artworkUrl.isNotEmpty
                            ? DecorationImage(
                                image: CachedNetworkImageProvider(
                                  track.artworkUrl,
                                ),
                                fit: BoxFit.cover,
                              )
                            : null,
                        color: track.artworkUrl.isEmpty
                            ? context.theme.disabledColor.withValues(alpha: 0.2)
                            : null,
                      ),
                      child: track.artworkUrl.isEmpty
                          ? const Icon(Icons.music_note_rounded)
                          : null,
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8.0,
                        vertical: 8.0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            track.title,
                            maxLines: isTv ? 2 : 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            track.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: context.theme.hintColor,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                Icons.favorite_rounded,
                                size: 12,
                                color: context.theme.colorScheme.error
                                    .withValues(alpha: 0.8),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _formatNumber(track.likesCount),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: context.theme.hintColor,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Icon(
                                Icons.repeat_rounded,
                                size: 12,
                                color: context.theme.colorScheme.primary
                                    .withValues(alpha: 0.8),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _formatNumber(track.repostsCount),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: context.theme.hintColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
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
                    onPressed: () => _onToggleLike(track),
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          );
        }, childCount: trackList.length),
      ),
    );
  }

  Widget _buildRightPlayerDashboard(TvMusicViewModel viewModel) {
    return Container(
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
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
    );
  }

  Widget _buildBottomMobilePlayer(TvMusicViewModel viewModel) {
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
        ],
      ),
    );
  }

  Widget _buildPlayerControls(TvMusicViewModel viewModel) {
    final isTrackLiked = viewModel.isLiked(viewModel.currentTrack!.id);
    return Column(
      children: [
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
