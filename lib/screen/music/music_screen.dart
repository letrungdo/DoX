import 'dart:async';
import 'dart:math';

import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:do_x/constants/dimens.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/model/music_shelf.dart';
import 'package:do_x/model/music_track.dart';
import 'package:do_x/router/app_router.gr.dart';
import 'package:do_x/screen/core/screen_state.dart';
import 'package:do_x/screen/core/tab_reselect.mixin.dart';
import 'package:do_x/screen/music/music_challenge_sheet.dart';
import 'package:do_x/screen/music/music_track_card.dart';
import 'package:do_x/screen/music/music_fullscreen_video_player.dart';
import 'package:do_x/screen/music/music_seek_bar.dart';
import 'package:do_x/screen/music/music_video_view.dart';
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
import 'package:video_player/video_player.dart';

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

class _MusicScreenState extends ScreenState<MusicScreen, MusicViewModel>
    with SingleTickerProviderStateMixin, TabReselect {
  /// Shared by every tab's list; only one of them is on screen at a time.
  final _scrollController = ScrollController();

  /// The track the list was last brought round to. A track that becomes the
  /// current one without the list having chosen it — next, previous, the end
  /// of the one before, the lock screen — has the list ride to it.
  String? _followedTrackId;

  static const _shelfHeadingPadding = EdgeInsets.fromLTRB(16, 16, 16, 8);
  static const _searchListPadding = EdgeInsets.all(4);
  static const _trackListPadding = EdgeInsets.all(8);

  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode(debugLabel: 'tv-music-search');

  /// The Search tab on the rail, where the remote waits for the answer to a
  /// search sent from the keyboard — see [_onSearchSubmitted].
  final _searchTabFocusNode = FocusNode(debugLabel: 'tv-music-search-tab');

  /// A search was sent from the keyboard and the remote is waiting on the
  /// Search tab to be put on the first result once the answer is in.
  bool _awaitingSearchResults = false;
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
  final FocusNode _videoToggleFocusNode = FocusNode(
    debugLabel: 'tv-music-video-toggle',
  );
  final FocusNode _fullscreenFocusNode = FocusNode(
    debugLabel: 'tv-music-video-fullscreen',
  );

  /// The track whose full-screen video the viewer backed out of. Its video
  /// stays in the dashboard, or on a sideways phone in the player, until they
  /// ask for it again; the next track's video takes the screen as usual.
  String? _leftVideoFor;

  /// A phone's full screen asked for by a tap on the video, which holds
  /// whichever way the phone is turned.
  bool _phoneFullscreen = false;

  /// The way the phone was turned at the last frame, to tell a turn from a
  /// rebuild.
  Orientation? _lastOrientation;

  /// Whether the remote was on the dashboard's full-screen button when the
  /// full-screen video went up, to be put back there when it comes down.
  bool _fullscreenFromDashboard = false;

  /// Whether the last frame was the full-screen video. Carried across the
  /// gap between two tracks, while the next one's video is still being
  /// fetched, so a skip does not flash the track list up in between.
  bool _showingFullscreenVideo = false;

  /// On a phone, where the video is between the small picture in the player
  /// (0) and the whole screen (1). A drag moves it; letting go, a tap or
  /// back finishes the run.
  ///
  /// Built in [initState], not lazily: a TV never touches it, and its first
  /// read would then be in [dispose], where `vsync: this` looks up the tree
  /// of an element that has already left it.
  late final AnimationController _videoExpansion;

  /// A drag on the video is under way: the picture follows the finger, and
  /// the full-screen player waits for it to be let go.
  bool _draggingVideo = false;

  /// The small picture in the phone's player, which the video grows out of
  /// and shrinks back into; and the layer it is drawn on on its way.
  final _thumbnailKey = GlobalKey();
  final _videoLayerKey = GlobalKey();

  /// A television's one picture, which moves between the dashboard and the
  /// full screen instead of being made again: it is a platform view, and a
  /// new one is a new native view for the player to find its surface in.
  final _tvVideoKey = GlobalKey();

  /// Where the page's route is looked up, to tell whether it is the one on
  /// screen — see [_onNavigationChanged].
  RouteData? _routeData;
  Listenable? _navigationHistory;

  /// The lists the focus nodes were last pruned against — see
  /// [_pruneFocusNodes].
  Object? _prunedFor;

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

  /// Lets go of the nodes of rows no list has any more, once the frame that
  /// dropped them is done — a node is only disposed of after its row has
  /// left the tree. Every refresh of Discover brings new tracks, and the
  /// nodes of the old ones were kept for as long as the page was.
  void _pruneFocusNodes(Object lists) {
    // Compared field by field, and the lists by identity: a list the view
    // model changes is a new one.
    if (lists == _prunedFor) return;
    _prunedFor = lists;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final viewModel = vm;
      final live = <String>{
        for (final shelf in viewModel.shelves)
          for (final track in shelf.tracks) track.id,
        for (final track in viewModel.searchResults) track.id,
        for (final track in viewModel.likedTracks) track.id,
      };
      for (final nodes in [_trackFocusNodes, _likeFocusNodes]) {
        nodes.removeWhere((id, node) {
          if (live.contains(id) || node.hasFocus) return false;
          node.dispose();
          return true;
        });
      }
    });
  }

  @override
  String get tabRouteName => MusicRoute.name;

  @override
  ScrollController get tabScrollController => _scrollController;

  @override
  Future<void> onTabRefresh() => vm.onRefresh();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Looked up rather than required: a widget test builds the page without
    // a router, and the page is then simply always on screen.
    final routeData = context
        .findAncestorWidgetOfExactType<RouteDataScope>()
        ?.routeData;
    final history = routeData?.router.navigationHistory;
    if (identical(routeData, _routeData) &&
        identical(history, _navigationHistory)) {
      return;
    }
    _navigationHistory?.removeListener(_onNavigationChanged);
    _routeData = routeData;
    _navigationHistory = history;
    history?.addListener(_onNavigationChanged);
    _onNavigationChanged();
  }

  /// Tells the view model whether the page is on screen. Its tab is kept
  /// alive once visited, so another tab, or a page pushed over it, leaves it
  /// playing out of sight — where its muted video had gone on streaming.
  void _onNavigationChanged() {
    final routeData = _routeData;
    final history = _navigationHistory;
    if (!mounted || routeData == null || history == null) return;
    vm.setPageVisible(routeData.router.isRouteDataActive(routeData));
  }

  @override
  void initState() {
    super.initState();
    _videoExpansion = AnimationController(
      vsync: this,
      duration: Dimens.musicVideoExpandDuration,
    );
  }

  @override
  void dispose() {
    _navigationHistory?.removeListener(_onNavigationChanged);
    for (final node in _trackFocusNodes.values) {
      node.dispose();
    }
    for (final node in _likeFocusNodes.values) {
      node.dispose();
    }
    _searchFocusNode.dispose();
    _searchTabFocusNode.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    _playPauseFocusNode.dispose();
    _nextFocusNode.dispose();
    _prevFocusNode.dispose();
    _shuffleFocusNode.dispose();
    _repeatFocusNode.dispose();
    _likeActionFocusNode.dispose();
    _videoToggleFocusNode.dispose();
    _fullscreenFocusNode.dispose();
    _videoExpansion.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.read<MusicViewModel>();
    final isTv = deviceType.isTv;
    final l10n = context.l10n;

    final pageTitle = l10n.tvCategoryMusic;

    // Only what decides between the page and the full-screen video is
    // listened for here. Every other part of the page listens for what it
    // shows itself, so a track coming up — six or eight notifications — no
    // longer rebuilds every row of the list with it.
    final track = context.select((MusicViewModel vm) => vm.currentTrack);
    final isVideoEnabled = context.select(
      (MusicViewModel vm) => vm.isVideoEnabled,
    );
    final videoController = context.select(
      (MusicViewModel vm) => vm.videoController,
    );
    final isVideoPending = context.select(
      (MusicViewModel vm) => vm.isVideoPending,
    );
    final hasNoSound = context.select(
      (MusicViewModel vm) => vm.audioController == null,
    );

    final currentId = track?.id;
    if (currentId != _followedTrackId) {
      _followedTrackId = currentId;
      if (currentId != null) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _followTrack(currentId),
        );
      }
    }

    // On a television a track with a video is watched, not listened to: the
    // picture takes the whole screen, with the controls over it. So it does
    // on a phone turned on its side, the way the film player does, and on an
    // upright one whose video was tapped.
    final isLandscape =
        deviceType.canDriveOrientation && _onPhoneTurned(context);
    // A tap on the video counts whichever way the phone is turned — the
    // video backed out of on a sideways phone is still one tap away.
    final opensByItself = (isTv || isLandscape) && track?.id != _leftVideoFor;
    final hasPicture =
        isVideoEnabled &&
        (videoController != null ||
            (_showingFullscreenVideo && (isVideoPending || hasNoSound)));
    // Asked for on a phone, full screen holds with the video off or none to
    // be had: the artwork takes the picture's place. Opened by itself, it is
    // there for the video and goes with it.
    final showFullscreen =
        track != null && (_phoneFullscreen || (opensByItself && hasPicture));
    // Read before the page is put away, which takes the remote off it.
    if (showFullscreen && !_showingFullscreenVideo) {
      _fullscreenFromDashboard =
          FocusManager.instance.primaryFocus == _fullscreenFocusNode;
    }
    _showingFullscreenVideo = showFullscreen;
    // Up on a phone, it stays up as though tapped: turning the video off
    // there shows the artwork instead of closing it. A turn of the phone
    // still starts afresh — see [_onPhoneTurned].
    if (showFullscreen && !isTv) _phoneFullscreen = true;
    // Opened or closed by anything but a drag, a tap or back — the phone
    // turned, the next track had no video: the picture is where it belongs
    // at once.
    final settled = showFullscreen ? 1.0 : 0.0;
    if (!isTv &&
        !_draggingVideo &&
        !_videoExpansion.isAnimating &&
        _videoExpansion.value != settled) {
      _videoExpansion.value = settled;
    }
    // Nothing is playing any more: the phone is back on the list.
    if (_phoneFullscreen && track == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_showingFullscreenVideo) {
          setState(() => _phoneFullscreen = false);
        }
      });
    }

    final mainContent = isTv
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Selector<MusicViewModel, MusicTab>(
                selector: (_, vm) => vm.currentTab,
                builder: (_, _, _) => _buildTvSidebarNavigation(viewModel),
              ),
              Container(
                width: 1,
                color: context.theme.dividerColor.withValues(alpha: 0.1),
              ),
              Expanded(flex: 3, child: _buildMainBodyArea(isTv)),
              Container(
                width: 1,
                color: context.theme.dividerColor.withValues(alpha: 0.1),
              ),
              Expanded(
                flex: 2,
                child: Consumer<MusicViewModel>(
                  builder: (_, vm, _) =>
                      _buildRightPlayerDashboard(vm, showFullscreen),
                ),
              ),
            ],
          )
        : Column(
            children: [
              Selector<MusicViewModel, MusicTab>(
                selector: (_, vm) => vm.currentTab,
                builder: (_, _, _) => _buildMobileTabs(viewModel),
              ),
              Expanded(child: _buildMainBodyArea(isTv)),
              Consumer<MusicViewModel>(
                builder: (_, vm, _) => _buildBottomMobilePlayer(vm),
              ),
            ],
          );

    final page = AppScaffold(
      // On a television the rail is the leftmost thing on the page, exactly as
      // it is on the home page — so it takes the screen's edge and the columns
      // apply their own insets. Inset here instead, the rail sat a safe area
      // *and* its own margin away from the edge while its other side had only
      // the margin, and it leaned to the right.
      bodyHorizontal: !isTv,
      appBar: DoAppBar(
        title: pageTitle,
        actions: [
          Selector<MusicViewModel, (bool, String)>(
            selector: (_, vm) => (vm.isSignedIn, vm.accountName),
            builder: (_, _, _) => _buildAccountAction(viewModel),
          ),
        ],
        titleSuffix: const AppBarSyncIcon<MusicViewModel>(selector: _isLoading),
      ),
      body: mainContent,
    );
    if (isTv) {
      // The page stays under the full-screen video, out of sight, rather
      // than being thrown away and built again each way: the list keeps its
      // place, and the picture moves between the two — see [_tvVideoKey].
      return Stack(
        fit: StackFit.expand,
        children: [
          _stow(page, stowed: showFullscreen),
          if (showFullscreen)
            MusicFullscreenVideoPlayer(
              onExit: () => _leaveFullscreen(track.id),
              onToggleLike: () => _onToggleLike(track),
              seekable: _seekable,
              videoKey: _tvVideoKey,
            ),
        ],
      );
    }
    // On a phone the page stays under the full-screen video, so the picture
    // can shrink back into its place in the player.
    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedBuilder(
          animation: _videoExpansion,
          child: page,
          // Put away only once the video covers it all. A drag starts from
          // the page as it was, so it is back the moment one begins.
          builder: (context, page) => _stow(
            page!,
            stowed:
                showFullscreen && _videoExpansion.value == 1 && !_draggingVideo,
          ),
        ),
        Positioned.fill(
          child: Consumer<MusicViewModel>(
            builder: (_, vm, _) =>
                _buildVideoLayer(vm, showFullscreen: showFullscreen),
          ),
        ),
      ],
    );
  }

  /// The page under an opaque full-screen video: still laid out — the small
  /// picture's place in the player is read off it on the way back down —
  /// but not painted, its animations stopped, and the remote kept off it.
  ///
  /// The same widgets whether or not it is [stowed], so putting it away
  /// and bringing it back loses nothing.
  Widget _stow(Widget page, {required bool stowed}) {
    return Offstage(
      offstage: stowed,
      child: TickerMode(
        enabled: !stowed,
        child: ExcludeFocus(excluding: stowed, child: page),
      ),
    );
  }

  /// The phone's video above the page: the full-screen player once it is
  /// all the way up, the bare picture while it is on its way, and nothing
  /// while it sits in the player.
  ///
  /// One drag detector for all three, so a drag begun on the full-screen
  /// player carries on once the player has made way for the picture.
  Widget _buildVideoLayer(
    MusicViewModel viewModel, {
    required bool showFullscreen,
  }) {
    final track = viewModel.currentTrack;
    return GestureDetector(
      key: _videoLayerKey,
      onVerticalDragStart: _onVideoDragStart,
      onVerticalDragUpdate: _onVideoDragUpdate,
      onVerticalDragEnd: _onVideoDragEnd,
      onVerticalDragCancel: () => _onVideoDragEnd(DragEndDetails()),
      child: AnimatedBuilder(
        animation: _videoExpansion,
        builder: (context, _) {
          final t = _videoExpansion.value;
          if (track != null && showFullscreen && t == 1 && !_draggingVideo) {
            return MusicFullscreenVideoPlayer(
              onExit: () => _collapseVideo(track.id),
              onToggleLike: () => _onToggleLike(track),
              seekable: _seekable,
            );
          }
          if (t == 0 || track == null) return const SizedBox.shrink();
          final video = viewModel.isVideoEnabled
              ? viewModel.videoController
              : null;
          return LayoutBuilder(
            builder: (context, constraints) =>
                _buildPictureInFlight(video, track, t, constraints.biggest),
          );
        },
      ),
    );
  }

  /// The picture [t] of the way from the player to the whole screen, over
  /// a page that darkens as it grows: the video, or with none the artwork,
  /// which lands where the full-screen player draws it.
  Widget _buildPictureInFlight(
    VideoPlayerController? video,
    MusicTrack track,
    double t,
    Size screen,
  ) {
    final Rect full;
    if (video != null) {
      final aspectRatio = video.value.aspectRatio > 0
          ? video.value.aspectRatio
          : Dimens.musicMiniVideoAspect;
      full = Rect.fromCenter(
        center: screen.center(Offset.zero),
        width: min(screen.width, screen.height * aspectRatio),
        height: min(screen.height, screen.width / aspectRatio),
      );
    } else {
      full = Rect.fromCenter(
        center: screen.center(Offset.zero),
        width: Dimens.musicFullscreenWaitingArtSize,
        height: Dimens.musicFullscreenWaitingArtSize,
      );
    }
    final miniSize = video != null
        ? const Size(
            Dimens.musicMiniVideoHeight * Dimens.musicMiniVideoAspect,
            Dimens.musicMiniVideoHeight,
          )
        : const Size.square(Dimens.musicMiniVideoHeight);
    final mini =
        _thumbnailRect() ??
        Rect.fromCenter(
          center: Offset(screen.width / 2, screen.height - miniSize.height),
          width: miniSize.width,
          height: miniSize.height,
        );
    return Stack(
      children: [
        Positioned.fill(
          child: ColoredBox(color: Colors.black.withValues(alpha: t)),
        ),
        Positioned.fromRect(
          rect: Rect.lerp(mini, full, t)!,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(
              Dimens.radiusControlSmall * (1 - t),
            ),
            child: video != null
                ? MusicVideoFill(controller: video)
                : MusicArtwork(track: track),
          ),
        ),
      ],
    );
  }

  /// Where the small picture in the player sits on the video's layer, as of
  /// the last frame.
  Rect? _thumbnailRect() {
    final thumbnail = _thumbnailKey.currentContext?.findRenderObject();
    final layer = _videoLayerKey.currentContext?.findRenderObject();
    if (thumbnail is! RenderBox || layer is! RenderBox) return null;
    if (!thumbnail.hasSize || !layer.hasSize) return null;
    return thumbnail.localToGlobal(Offset.zero, ancestor: layer) &
        thumbnail.size;
  }

  void _onVideoDragStart(DragStartDetails _) {
    if (context.read<MusicViewModel>().currentTrack == null) return;
    _videoExpansion.stop();
    setState(() => _draggingVideo = true);
  }

  void _onVideoDragUpdate(DragUpdateDetails details) {
    if (!_draggingVideo) return;
    final travel =
        MediaQuery.sizeOf(context).height * Dimens.musicVideoDragTravelShare;
    // Up is towards the whole screen. The controller keeps it within 0–1.
    _videoExpansion.value -= (details.primaryDelta ?? 0) / travel;
  }

  /// Let go: a flick goes the way it was flicked, anything slower to
  /// whichever end is nearer.
  void _onVideoDragEnd(DragEndDetails details) {
    if (!_draggingVideo) return;
    final velocity = details.primaryVelocity ?? 0;
    final open = velocity.abs() > Dimens.musicVideoFlingVelocity
        ? velocity < 0
        : _videoExpansion.value > 0.5;
    final trackId = context.read<MusicViewModel>().currentTrack?.id;
    _draggingVideo = false;
    if (open || trackId == null) {
      _expandVideo();
    } else {
      _collapseVideo(trackId);
    }
  }

  /// Takes the video up to the whole screen. The run is started before the
  /// page is rebuilt, so the rebuild finds it moving and leaves it be.
  void _expandVideo() {
    _videoExpansion.animateTo(1, curve: Curves.easeOutCubic);
    setState(() => _phoneFullscreen = true);
  }

  /// Takes the video back down into the player.
  void _collapseVideo(String trackId) {
    _videoExpansion.animateTo(0, curve: Curves.easeOutCubic);
    if (_showingFullscreenVideo) {
      _leaveFullscreen(trackId);
    } else {
      setState(() {});
    }
  }

  /// Whether the phone is on its side, noting a turn as it happens: turned
  /// either way, the phone starts afresh — a video backed out of sideways is
  /// offered again on the next turn, and turning upright leaves a full
  /// screen that the turn opened.
  bool _onPhoneTurned(BuildContext context) {
    final orientation = MediaQuery.orientationOf(context);
    if (_lastOrientation != null && orientation != _lastOrientation) {
      _leftVideoFor = null;
      _phoneFullscreen = false;
    }
    _lastOrientation = orientation;
    return orientation == Orientation.landscape;
  }

  /// Back from the full-screen video to the list, with the list brought
  /// round to the track playing — and, on a television, the remote on that
  /// track's row.
  void _leaveFullscreen(String trackId) {
    // The page was put away with the remote on it, and putting it away took
    // the remote off (see [_stow]): nothing is left focused on it to come
    // back to, so the remote has to be put somewhere by hand.
    final isTv = deviceType.isTv;
    // Laid out, though out of sight, so the list can be moved to the row
    // before it is shown: the row is then built by the frame that brings the
    // page back, and there to take the remote.
    if (isTv) _jumpToTrack(trackId);
    setState(() {
      _leftVideoFor = trackId;
      _phoneFullscreen = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!isTv) {
        _followTrack(trackId);
        return;
      }
      if (_fullscreenFromDashboard) {
        _fullscreenFromDashboard = false;
        _fullscreenFocusNode.requestFocus();
        return;
      }
      // The row the track was picked from; a track that is not in the list
      // on screen — played from another tab — leaves the remote on the
      // player instead.
      final row = _trackFocusNodes[trackId];
      if (row != null && row.context != null && row.canRequestFocus) {
        row.requestFocus();
      } else {
        _playPauseFocusNode.requestFocus();
      }
    });
  }

  /// Moves the list straight to [id]'s row, parked where [_followTrack]
  /// parks it.
  void _jumpToTrack(String id) {
    final target = _followTarget(id);
    if (target != null) _scrollController.jumpTo(target);
  }

  /// A search sent from the keyboard. On a television the field lets go of
  /// the remote as the keyboard goes (see `EditableText`), and left on the
  /// page's scope, `TvShell` hands it to the first control on the page — the
  /// Discover tab. It goes to the first result instead, or waits for one on
  /// the Search tab while the answer is on its way.
  void _onSearchSubmitted(String query) {
    final viewModel = vm;
    unawaited(viewModel.submitSearch(query));
    if (!deviceType.isTv) return;
    if (_focusFirstResult()) return;
    _searchTabFocusNode.requestFocus();
    _awaitingSearchResults = true;
    // Already answered, the list only needs bringing to its first row;
    // otherwise the list's rebuild with the answer asks again.
    if (!viewModel.isLoading) _onSearchAnswered();
  }

  /// Puts the remote on the first search result, if one is on screen.
  bool _focusFirstResult() {
    final viewModel = vm;
    if (viewModel.isLoading || viewModel.currentTab != MusicTab.search) {
      return false;
    }
    final first = viewModel.searchResults.firstOrNull;
    final row = first == null ? null : _trackFocusNodes[first.id];
    if (row == null || row.context == null || !row.canRequestFocus) {
      return false;
    }
    row.requestFocus();
    return true;
  }

  /// Once the answer to a search sent from the keyboard is on screen, moves
  /// the remote from the Search tab to the first result — unless the viewer
  /// has put it somewhere else in the meantime.
  void _onSearchAnswered() {
    WidgetsBinding.instance
      ..ensureVisualUpdate()
      ..addPostFrameCallback((_) {
        if (!mounted || !_awaitingSearchResults || vm.isLoading) return;
        _awaitingSearchResults = false;
        if (FocusManager.instance.primaryFocus != _searchTabFocusNode) return;
        if (_focusFirstResult()) return;
        // The list came back scrolled down, where the page kept it for the
        // last search: the first row is not built until it is at the top.
        if (!_scrollController.hasClients ||
            _scrollController.positions.length != 1) {
          return;
        }
        _scrollController.jumpTo(_scrollController.position.minScrollExtent);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (FocusManager.instance.primaryFocus != _searchTabFocusNode) return;
          _focusFirstResult();
        });
      });
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
      case MusicLikeOutcome.challengeRequired:
        // Once: a like still refused after the check is a failure to report,
        // not a reason to put the check up again.
        final url = vm.likeChallengeUrl;
        if (url == null) return;
        final passed = await showMusicChallengeSheet(context, url);
        if (!passed || !mounted) return;
        final retried = await vm.toggleLike(track);
        if (retried != MusicLikeOutcome.done && mounted) {
          context.showToast(l10n.musicLikeFailed, isError: true);
        }
      case MusicLikeOutcome.failed:
        context.showToast(l10n.musicLikeFailed, isError: true);
    }
  }

  /// Rides the list to [id]'s row and parks it half way up the viewport.
  ///
  /// Worked out rather than found: the rows are built lazily, so a row off
  /// screen has no context to ask `Scrollable.ensureVisible` about. Every row
  /// is the same height, which leaves only the shelf headings to measure.
  void _followTrack(String id) {
    final target = _followTarget(id);
    if (target == null) return;
    _scrollController.animateTo(
      target,
      duration: Dimens.musicFollowScrollDuration,
      curve: Curves.easeOutCubic,
    );
  }

  /// Where the list is scrolled to to park [id]'s row half way up it, or
  /// null when there is no one list on screen, or the row is not in it.
  double? _followTarget(String id) {
    if (!mounted || !_scrollController.hasClients) return null;
    if (_scrollController.positions.length != 1) return null;
    final offset = _trackOffset(vm, id);
    // Not in the list on screen: the track came from another tab's list,
    // or from one refreshed since.
    if (offset == null) return null;
    final position = _scrollController.position;
    final target =
        offset -
        (position.viewportDimension - Dimens.musicTrackTileHeight) *
            Dimens.tvFocusScrollAlignment;
    return target.clamp(position.minScrollExtent, position.maxScrollExtent);
  }

  /// Where [id]'s row starts in the current tab's list, or null when it is
  /// not there. Mirrors the padding each list is built with.
  double? _trackOffset(MusicViewModel viewModel, String id) {
    const spacing = Dimens.musicTrackSpacing;
    final stride = Dimens.musicTrackTileHeight + spacing;
    double? inGrid(List<MusicTrack> tracks, double leading) {
      final index = tracks.indexWhere((t) => t.id == id);
      return index < 0 ? null : leading + index * stride;
    }

    switch (viewModel.currentTab) {
      case MusicTab.home:
        final heading = _shelfHeadingHeight(deviceType.isTv);
        var offset = 0.0;
        for (final shelf in viewModel.shelves) {
          offset += heading;
          final found = inGrid(shelf.tracks, offset);
          if (found != null) return found;
          if (shelf.tracks.isNotEmpty) {
            offset += shelf.tracks.length * stride - spacing;
          }
        }
        return null;
      case MusicTab.search:
        return inGrid(viewModel.searchResults, _searchListPadding.top);
      case MusicTab.likes:
        return inGrid(viewModel.likedTracks, _trackListPadding.top);
    }
  }

  TextStyle _shelfHeadingStyle(bool isTv) =>
      TextStyle(fontSize: isTv ? 14 : 12, fontWeight: FontWeight.bold);

  /// One shelf heading's height, laid out the way [Text] lays it out.
  double _shelfHeadingHeight(bool isTv) {
    final painter = TextPainter(
      text: TextSpan(
        text: 'Ag',
        style: DefaultTextStyle.of(
          context,
        ).style.merge(_shelfHeadingStyle(isTv)),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final height = painter.height;
    painter.dispose();
    return _shelfHeadingPadding.vertical + height;
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
                  focusNode: _searchTabFocusNode,
                ),
                _buildRailItem(
                  viewModel,
                  MusicTab.likes,
                  Icons.favorite_rounded,
                  l10n.musicTabLikes,
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
    String label, {
    FocusNode? focusNode,
  }) {
    final scheme = context.theme.colorScheme;
    final isSelected = viewModel.currentTab == tab;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: FocusableTap(
        focusNode: focusNode,
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
        ],
      ),
    );
  }

  /// The list, rebuilt only when what it lists changes: which row is
  /// playing and which are liked are for each row to listen for — see
  /// [_TrackRow].
  Widget _buildMainBodyArea(bool isTv) {
    return Selector<
      MusicViewModel,
      (bool, MusicTab, List<MusicShelf>, List<MusicTrack>, List<MusicTrack>)
    >(
      selector: (_, vm) => (
        vm.isLoading,
        vm.currentTab,
        vm.shelves,
        vm.searchResults,
        vm.likedTracks,
      ),
      builder: (context, lists, _) {
        final (isLoading, tab, shelves, searchResults, likedTracks) = lists;
        _pruneFocusNodes((shelves, searchResults, likedTracks));
        if (_awaitingSearchResults && !isLoading) _onSearchAnswered();
        final viewModel = context.read<MusicViewModel>();
        if (isLoading && tab == MusicTab.home && shelves.isEmpty) {
          return const Center(child: Loading());
        }

        switch (tab) {
          case MusicTab.home:
            return _buildDiscoverHome(viewModel, isTv);
          case MusicTab.search:
            return _buildSearchTab(viewModel);
          case MusicTab.likes:
            return _buildTrackListSection(
              MusicTab.likes,
              viewModel.likedTracks,
              context.l10n.musicLikesEmpty,
              Icons.favorite_border_rounded,
            );
        }
      },
    );
  }

  Widget _buildDiscoverHome(MusicViewModel viewModel, bool isTv) {
    return CustomScrollView(
      key: const ValueKey(MusicTab.home),
      controller: _scrollController,
      slivers: [
        // The rows, and their headings, are whatever the service sent for this
        // account — so the page is built from them rather than from a fixed
        // pair of sections.
        for (final shelf in viewModel.shelves) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: _shelfHeadingPadding,
              // One line, so [_trackOffset] knows how tall it is.
              child: Text(
                shelf.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _shelfHeadingStyle(isTv),
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
          // Only the field listens to the text, for its clear button: the
          // whole page was being rebuilt on every key to show or hide it.
          child: ValueListenableBuilder(
            valueListenable: _searchController,
            builder: (context, value, _) => TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              textInputAction: TextInputAction.search,
              // A tap anywhere else puts the keyboard away, as on the TV page.
              onTapOutside: (_) => FocusScope.of(context).unfocus(),
              onChanged: viewModel.searchTracks,
              onSubmitted: _onSearchSubmitted,
              decoration: InputDecoration(
                hintText: context.l10n.musicSearchHint,
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: value.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchController.clear();
                          viewModel.searchTracks('');
                        },
                      ),
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
                      Text(context.l10n.musicSearchEmpty),
                    ],
                  ),
                )
              : CustomScrollView(
                  key: const ValueKey(MusicTab.search),
                  controller: _scrollController,
                  // Reading down the results is done with the keyboard away.
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  slivers: [
                    SliverPadding(
                      padding: _searchListPadding,
                      sliver: _buildSliverGrid(viewModel.searchResults),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildTrackListSection(
    MusicTab tab,
    List<MusicTrack> tracks,
    String emptyMessage,
    IconData emptyIcon,
  ) {
    if (tracks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 8,
          children: [
            Icon(emptyIcon, size: 48, color: context.theme.disabledColor),
            Text(emptyMessage),
          ],
        ),
      );
    }
    return CustomScrollView(
      key: ValueKey(tab),
      controller: _scrollController,
      slivers: [
        SliverPadding(
          padding: _trackListPadding,
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
          crossAxisSpacing: Dimens.musicTrackSpacing,
          mainAxisSpacing: Dimens.musicTrackSpacing,
        ),
        delegate: SliverChildBuilderDelegate((context, index) {
          final track = trackList[index];
          return _TrackRow(
            key: ValueKey(track.id),
            track: track,
            focusNode: _getNodeForTrack(track.id),
            likeFocusNode: _getLikeNodeForTrack(track.id),
            onTap: () {
              // Chosen from the list, so the list stays where it is.
              _followedTrackId = track.id;
              context.read<MusicViewModel>().playFromList(track);
            },
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
  ///
  /// Read in a builder of its own: read with the page's context, the whole
  /// page depended on every change of the media query, the keyboard's
  /// every frame on its way up included.
  Widget _seekable(Widget slider) {
    if (!deviceType.isTv) return slider;
    return Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(navigationMode: NavigationMode.directional),
        child: slider,
      ),
    );
  }

  /// The player beside the list. [showFullscreen] leaves the picture to the
  /// full-screen video, which takes it over — see [_tvVideoKey].
  Widget _buildRightPlayerDashboard(
    MusicViewModel viewModel,
    bool showFullscreen,
  ) {
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
                    Text(
                      context.l10n.musicDashboardIdle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Expanded(
                child: Center(
                  child: viewModel.videoController != null
                      ? showFullscreen
                            // Up on the full screen; one picture is all a
                            // platform view has.
                            ? const SizedBox.shrink()
                            : MusicVideoView(
                                key: _tvVideoKey,
                                controller: viewModel.videoController!,
                                isOfficialAudio: viewModel.isAudioFromVideo,
                                // Square: a rounded clip over a platform
                                // view is paid for on every frame of the
                                // video, and it also lets the picture move
                                // to the full screen unchanged.
                                borderRadius: BorderRadius.zero,
                              )
                      : AspectRatio(
                          aspectRatio: 1,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(
                                Dimens.radiusPanel,
                              ),
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
                              borderRadius: BorderRadius.circular(
                                Dimens.radiusPanel,
                              ),
                              child:
                                  viewModel.currentTrack!.artworkUrl.isNotEmpty
                                  ? _buildDashboardArtwork(
                                      viewModel.currentTrack!,
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

  /// The artwork filling the dashboard's square, fetched and decoded at the
  /// size the square comes out at rather than the service's largest.
  Widget _buildDashboardArtwork(MusicTrack track) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final pixels =
            min(constraints.maxWidth, constraints.maxHeight) *
            MediaQuery.devicePixelRatioOf(context);
        return CachedNetworkImage(
          imageUrl: track.artworkUrlFor(pixels),
          memCacheWidth: pixels.isFinite ? pixels.round() : null,
          fit: BoxFit.cover,
          placeholder: (_, _) => const Center(child: Loading()),
          errorWidget: (_, _, _) => Icon(
            Icons.music_note_rounded,
            size: 64,
            color: context.theme.disabledColor,
          ),
        );
      },
    );
  }

  Widget _buildBottomMobilePlayer(MusicViewModel viewModel) {
    if (viewModel.currentTrack == null) return const SizedBox.shrink();
    final isTrackLiked = viewModel.isLiked(viewModel.currentTrack!.id);
    final video = viewModel.isVideoEnabled ? viewModel.videoController : null;
    final miniArtPixels =
        Dimens.musicMiniVideoHeight * MediaQuery.devicePixelRatioOf(context);
    final player = NeuCard(
      margin: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                if (video != null)
                  AnimatedBuilder(
                    animation: _videoExpansion,
                    builder: (context, _) => MusicVideoThumbnail(
                      key: _thumbnailKey,
                      controller: video,
                      hidden: _videoExpansion.value > 0,
                      onTap: _expandVideo,
                    ),
                  )
                else
                  // No video to show: the artwork opens the full screen the
                  // same way, and it is the artwork that goes up.
                  AnimatedBuilder(
                    animation: _videoExpansion,
                    builder: (context, _) => GestureDetector(
                      key: _thumbnailKey,
                      behavior: HitTestBehavior.opaque,
                      onTap: _expandVideo,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(
                          Dimens.radiusControlSmall,
                        ),
                        child: SizedBox.square(
                          dimension: Dimens.musicMiniVideoHeight,
                          child: _videoExpansion.value > 0
                              ? const ColoredBox(color: Colors.black)
                              : viewModel.currentTrack!.artworkUrl.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: viewModel.currentTrack!
                                      .artworkUrlFor(miniArtPixels),
                                  memCacheWidth: miniArtPixels.round(),
                                  fit: BoxFit.cover,
                                )
                              : const Icon(Icons.music_note_rounded),
                        ),
                      ),
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
                // Always there, and only live for a track that has a video
                // to show or hide: coming and going with each skip, it shoved
                // the buttons beside it along.
                IconButton(
                  tooltip: viewModel.isVideoEnabled
                      ? context.l10n.musicVideoHide
                      : context.l10n.musicVideoShow,
                  icon: Icon(
                    viewModel.isVideoEnabled
                        ? Icons.videocam_rounded
                        : Icons.videocam_off_rounded,
                    size: 20,
                  ),
                  color: context.theme.hintColor,
                  onPressed: viewModel.hasVideo ? viewModel.toggleVideo : null,
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
              child: MusicSeekBar(
                builder: (context, _, slider) => _seekable(slider),
              ),
            ),
          ),
        ],
      ),
    );
    // Dragged up, the picture — the video, or the artwork — comes out of the
    // player after the finger and opens full screen; see [_buildVideoLayer]
    // for the way back down.
    return GestureDetector(
      onVerticalDragStart: _onVideoDragStart,
      onVerticalDragUpdate: _onVideoDragUpdate,
      onVerticalDragEnd: _onVideoDragEnd,
      onVerticalDragCancel: () => _onVideoDragEnd(DragEndDetails()),
      child: player,
    );
  }

  Widget _buildPlayerControls(MusicViewModel viewModel) {
    final isTrackLiked = viewModel.isLiked(viewModel.currentTrack!.id);
    return Column(
      children: [
        MusicSeekBar(
          builder: (context, position, slider) => Column(
            children: [
              _seekable(
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 6,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 14,
                    ),
                  ),
                  child: slider,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDuration(position),
                      style: TextStyle(
                        fontSize: 12,
                        color: context.theme.hintColor,
                      ),
                    ),
                    Text(
                      _formatDuration(viewModel.duration),
                      style: TextStyle(
                        fontSize: 12,
                        color: context.theme.hintColor,
                      ),
                    ),
                  ],
                ),
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
          ],
        ),
        // The track's own actions on a row of their own: with the video's
        // two buttons they no longer fit beside the transport in the
        // dashboard's column.
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: Dimens.musicDashboardActionSpacing,
          children: [
            NeuIconButton(
              icon: isTrackLiked
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              focusNode: _likeActionFocusNode,
              size: 36,
              color: isTrackLiked ? context.theme.colorScheme.error : null,
              onPressed: () => _onToggleLike(viewModel.currentTrack!),
            ),
            // Both always there, and live only while they have something to
            // do: coming and going with each skip, they shoved the row along.
            NeuIconButton(
              icon: viewModel.isVideoEnabled
                  ? Icons.videocam_rounded
                  : Icons.videocam_off_rounded,
              focusNode: _videoToggleFocusNode,
              size: 36,
              tooltip: viewModel.isVideoEnabled
                  ? context.l10n.musicVideoHide
                  : context.l10n.musicVideoShow,
              onPressed: viewModel.hasVideo ? viewModel.toggleVideo : null,
            ),
            // The way back to the full-screen video after leaving it.
            NeuIconButton(
              icon: Icons.fullscreen_rounded,
              focusNode: _fullscreenFocusNode,
              size: 36,
              tooltip: context.l10n.musicVideoFullscreen,
              onPressed: viewModel.videoController != null
                  ? () => setState(() => _leftVideoFor = null)
                  : null,
            ),
          ],
        ),
      ],
    );
  }
}

/// One row of the list, listening for the two things about it that change
/// while the list itself stays the same: whether it is the track playing,
/// and whether it is liked. A track starting notifies the page six or eight
/// times, and only the rows whose answer changed are rebuilt for it.
class _TrackRow extends StatelessWidget {
  const _TrackRow({
    super.key,
    required this.track,
    required this.focusNode,
    required this.likeFocusNode,
    required this.onTap,
    required this.onToggleLike,
  });

  final MusicTrack track;
  final FocusNode focusNode;
  final FocusNode likeFocusNode;
  final VoidCallback onTap;
  final VoidCallback onToggleLike;

  @override
  Widget build(BuildContext context) {
    final (isCurrent, isLiked) = context.select(
      (MusicViewModel vm) =>
          (vm.currentTrack?.id == track.id, vm.isLiked(track.id)),
    );
    return MusicTrackCard(
      track: track,
      isCurrent: isCurrent,
      isLiked: isLiked,
      focusNode: focusNode,
      likeFocusNode: likeFocusNode,
      onTap: onTap,
      onToggleLike: onToggleLike,
    );
  }
}
