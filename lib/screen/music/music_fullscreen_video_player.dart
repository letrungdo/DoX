import 'dart:async';
import 'dart:math';

import 'package:do_x/constants/dimens.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/model/music_track.dart';
import 'package:do_x/screen/music/music_seek_bar.dart';
import 'package:do_x/screen/music/music_video_view.dart';
import 'package:do_x/store/immersive_mode.dart';
import 'package:do_x/utils/device_type.dart';
import 'package:do_x/view_model/music/music_view_model.dart';
import 'package:do_x/widgets/focusable_tap.dart';
import 'package:do_x/widgets/loading.dart';
import 'package:do_x/widgets/player_controls_focus.dart';
import 'package:do_x/widgets/tv_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

/// The current track's video across the whole screen, with the player's
/// controls laid over it.
///
/// On a television it is built for the remote. The controls come up over the
/// picture and go away again on their own, the way a television's own player
/// behaves: any arrow or OK on the bare picture brings them back with the
/// remote on play, and the transport keys a remote is printed with — play,
/// pause, next, previous, the channel pair — work whether the controls are up
/// or not. Back leaves for the track list, and the music plays on.
///
/// On a phone a tap on the picture shows or hides the controls. The page
/// takes the whole screen while it is up — the status and navigation bars and
/// the bottom tab bar step aside — and gives it back when it closes. It never
/// turns the phone: turning the phone is what opens it (see the music page).
///
/// A bare [Scaffold] rather than `AppScaffold`: the picture bleeds to every
/// edge, and only the controls keep clear of the overscan band or the notch.
class MusicFullscreenVideoPlayer extends StatefulWidget {
  const MusicFullscreenVideoPlayer({
    super.key,
    required this.onExit,
    required this.onToggleLike,
    required this.seekable,
    this.videoKey,
  });

  /// Back to the track list.
  final VoidCallback onExit;
  final VoidCallback onToggleLike;

  /// Makes a slider one the remote can step off — see the music page.
  final Widget Function(Widget slider) seekable;

  /// Carried by the picture, so the one the page was showing moves in here
  /// rather than being made again — see the music page.
  final Key? videoKey;

  @override
  State<MusicFullscreenVideoPlayer> createState() =>
      _MusicFullscreenVideoPlayerState();
}

class _MusicFullscreenVideoPlayerState
    extends State<MusicFullscreenVideoPlayer> {
  final _pictureNode = FocusNode(debugLabel: 'tv-music-video-picture');
  final _controlsScope = FocusScopeNode(debugLabel: 'tv-music-video-controls');
  final _playNode = FocusNode(debugLabel: 'tv-music-video-play');

  bool _controlsVisible = true;

  /// The controls have faded all the way out, and are no longer built: the
  /// seek bar in them was still being rebuilt twice a second out of sight.
  bool _controlsGone = false;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _showControls();
    if (!deviceType.isTv) _takeTheScreen();
  }

  /// The phone's whole screen: the bars and the tab bar out of the way.
  void _takeTheScreen() {
    _open++;
    _settleImmersiveMode();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _giveTheScreenBack() {
    _open--;
    _settleImmersiveMode();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  /// How many of these players are up. Two can overlap for a frame — the
  /// page rebuilt with a new one before the old one is gone — so the tab bar
  /// follows the count, not whichever of them spoke last.
  static int _open = 0;

  /// Tells the tab bar once the frame is done. Said from `initState` or
  /// `dispose` directly, it rebuilt the shell in the middle of a build:
  /// Flutter refused, the frame was dropped, and a tap on the video did
  /// nothing on screen until some other touch drew the next one.
  static void _settleImmersiveMode() {
    WidgetsBinding.instance
      ..addPostFrameCallback((_) => immersiveMode.value = _open > 0)
      ..ensureVisualUpdate();
  }

  @override
  void dispose() {
    if (!deviceType.isTv) _giveTheScreenBack();
    _hideTimer?.cancel();
    _pictureNode.dispose();
    _controlsScope.dispose();
    _playNode.dispose();
    super.dispose();
  }

  /// Brings the controls up with the remote on them, and starts the clock
  /// that takes them down again.
  void _showControls() {
    if (!_controlsVisible || _controlsGone) {
      setState(() {
        _controlsVisible = true;
        _controlsGone = false;
      });
    }
    _scheduleHide();
    // Only a remote needs to be put anywhere.
    if (!deviceType.isTv) return;
    // After the frame: hidden controls are out of the focus tree, so there
    // is nothing to focus until they have been laid out again.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controlsVisible) return;
      if (!_controlsScope.hasFocus) {
        focusPlayerControls(_controlsScope, preferred: _playNode);
      }
    });
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(Dimens.musicFullscreenControlsHideDelay, _hideControls);
  }

  void _hideControls() {
    if (!mounted) return;
    setState(() => _controlsVisible = false);
    _pictureNode.requestFocus();
  }

  /// A tap on the picture: the controls if they are hidden, and away with
  /// them if they are up.
  void _onPictureTap() {
    if (_controlsVisible) {
      _hideTimer?.cancel();
      _hideControls();
    } else {
      _showControls();
    }
  }

  static bool _isArrowOrSelect(LogicalKeyboardKey key) =>
      key == LogicalKeyboardKey.arrowUp ||
      key == LogicalKeyboardKey.arrowDown ||
      key == LogicalKeyboardKey.arrowLeft ||
      key == LogicalKeyboardKey.arrowRight ||
      key == LogicalKeyboardKey.select ||
      key == LogicalKeyboardKey.enter ||
      key == LogicalKeyboardKey.gameButtonA;

  /// The bare picture: the first press only brings the controls up, so the
  /// viewer sees what they are reaching for before anything happens.
  KeyEventResult _onPictureKey(FocusNode node, KeyEvent event) {
    if (!node.hasPrimaryFocus) return KeyEventResult.ignored;
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (!_isArrowOrSelect(event.logicalKey)) return KeyEventResult.ignored;
    if (event is KeyDownEvent) _showControls();
    return KeyEventResult.handled;
  }

  /// The transport keys, wherever the remote is resting. Every other key
  /// only keeps the controls up while the viewer is using them.
  KeyEventResult _onPageKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (_controlsVisible) _scheduleHide();
    final vm = context.read<MusicViewModel>();
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.mediaPlayPause) {
      vm.togglePlay();
    } else if (key == LogicalKeyboardKey.mediaPlay) {
      vm.resume();
    } else if (key == LogicalKeyboardKey.mediaPause) {
      vm.pause();
    } else if (key == LogicalKeyboardKey.mediaTrackNext ||
        key == LogicalKeyboardKey.channelUp) {
      vm.nextTrack();
    } else if (key == LogicalKeyboardKey.mediaTrackPrevious ||
        key == LogicalKeyboardKey.channelDown) {
      vm.previousTrack();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MusicViewModel>();
    final video = vm.videoController;
    final track = vm.currentTrack;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) widget.onExit();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Focus(
          canRequestFocus: false,
          skipTraversal: true,
          onKeyEvent: _onPageKey,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // The picture holds the focus while the controls are away, and
              // is the whole screen: the shell's focus ring around it read as
              // the video's corners being rounded.
              TvFocusSurface(
                node: _pictureNode,
                child: Focus(
                  focusNode: _pictureNode,
                  onKeyEvent: _onPictureKey,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _onPictureTap,
                    child: Center(
                      child: video != null
                          ? MusicVideoView(
                              key: widget.videoKey,
                              controller: video,
                              isOfficialAudio: vm.isAudioFromVideo,
                              borderRadius: BorderRadius.zero,
                            )
                          : _buildWaiting(
                              track,
                              // Off, or none to be had: the artwork stands in
                              // for it, with nothing to wait for. With the
                              // music already playing, the picture's wait is
                              // shown on the video button instead.
                              loading:
                                  vm.isVideoEnabled &&
                                  vm.isVideoPending &&
                                  !vm.isVideoLoadingOverSound,
                            ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: ExcludeFocus(
                  excluding: !_controlsVisible,
                  child: IgnorePointer(
                    ignoring: !_controlsVisible,
                    child: AnimatedOpacity(
                      opacity: _controlsVisible ? 1 : 0,
                      duration: Dimens.musicFullscreenControlsFade,
                      onEnd: () {
                        if (!_controlsVisible && mounted) {
                          setState(() => _controlsGone = true);
                        }
                      },
                      // A finger on the controls keeps them up, the way a
                      // key press does on a television.
                      child: _controlsGone
                          ? const SizedBox.shrink()
                          : Listener(
                              onPointerDown: (_) => _scheduleHide(),
                              child: _buildControls(vm),
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Clear of the notch, the home indicator and the edges the system takes
  /// its swipes from, wherever the phone has turned them.
  ///
  /// Not the plain safe-area padding: with the bars hidden it falls to
  /// nothing, which left the buttons on the very strip where a touch goes to
  /// the home indicator first — so a tap on them sometimes did nothing.
  static EdgeInsets _phoneControlsPadding(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final viewPadding = MediaQuery.viewPaddingOf(context);
    final gestures = MediaQuery.systemGestureInsetsOf(context);
    double edge(double a, double b, double c) => max(a, max(b, c));
    return EdgeInsets.only(
          left: edge(padding.left, viewPadding.left, gestures.left),
          right: edge(padding.right, viewPadding.right, gestures.right),
          bottom: edge(
            padding.bottom,
            viewPadding.bottom,
            max(gestures.bottom, Dimens.musicPhoneGestureClearance),
          ),
        ) +
        Dimens.musicPhoneControlsPadding;
  }

  /// The next track's artwork while its video is still being fetched, so a
  /// skip does not flash the track list up between two videos.
  /// The artwork where the picture goes: dimmed under a spinner while the
  /// video is on its way, as it is when there is no video to show.
  Widget _buildWaiting(MusicTrack? track, {required bool loading}) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Opacity(
          opacity: loading ? 0.4 : 1,
          child: MusicArtwork(
            track: track,
            size: Dimens.musicFullscreenWaitingArtSize,
          ),
        ),
        if (loading) const Loading(),
      ],
    );
  }

  Widget _buildControls(MusicViewModel vm) {
    final l10n = context.l10n;
    final track = vm.currentTrack;
    final isLiked = track != null && vm.isLiked(track.id);
    final isTv = deviceType.isTv;
    const white = Colors.white;
    final muted = Colors.white.withValues(alpha: 0.7);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.85)],
        ),
      ),
      child: Padding(
        padding: isTv
            ? Dimens.tvOverscan.copyWith(top: Dimens.musicFullscreenControlsTop)
            : _phoneControlsPadding(context),
        child: FocusScope(
          node: _controlsScope,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                spacing: 12,
                children: [
                  Expanded(
                    child: Text(
                      track?.title ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: white,
                        fontSize: isTv ? 22 : 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (vm.videoController case final video?)
                    _QualityChip(
                      label: musicVideoQualityLabel(video.value.size),
                    ),
                ],
              ),
              Text(
                track?.artist ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: muted, fontSize: isTv ? 14 : 12),
              ),
              MusicSeekBar(
                builder: (context, position, slider) => Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 4,
                        activeTrackColor: white,
                        inactiveTrackColor: Colors.white24,
                        thumbColor: white,
                      ),
                      child: widget.seekable(slider),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _format(position),
                          style: TextStyle(color: muted, fontSize: 12),
                        ),
                        Text(
                          _format(vm.duration),
                          style: TextStyle(color: muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Shrunk rather than cut off where a portrait phone is too
              // narrow for the whole row.
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: Dimens.musicFullscreenControlSpacing,
                  children: [
                    _ControlButton(
                      icon: vm.isShuffleEnabled
                          ? Icons.shuffle_on_rounded
                          : Icons.shuffle_rounded,
                      onTap: vm.toggleShuffle,
                    ),
                    _ControlButton(
                      icon: Icons.skip_previous_rounded,
                      onTap: vm.previousTrack,
                    ),
                    _ControlButton(
                      icon: vm.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      focusNode: _playNode,
                      large: true,
                      onTap: vm.togglePlay,
                    ),
                    _ControlButton(
                      icon: Icons.skip_next_rounded,
                      onTap: vm.nextTrack,
                    ),
                    _ControlButton(
                      icon: vm.isRepeatEnabled
                          ? Icons.repeat_on_rounded
                          : Icons.repeat_rounded,
                      onTap: vm.toggleRepeat,
                    ),
                    _ControlButton(
                      icon: isLiked
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: isLiked ? context.theme.colorScheme.error : null,
                      onTap: widget.onToggleLike,
                    ),
                    // The video's state, as in the page's player; live only
                    // for a track that has one to show or hide, but always
                    // there, so a skip does not shove the row along.
                    _ControlButton(
                      icon: vm.isVideoEnabled
                          ? Icons.videocam_rounded
                          : Icons.videocam_off_rounded,
                      tooltip: vm.isVideoEnabled
                          ? l10n.musicVideoHide
                          : l10n.musicVideoShow,
                      loading: vm.isVideoLoadingOverSound,
                      onTap: vm.hasVideo ? vm.toggleVideo : null,
                    ),
                    _ControlButton(
                      icon: isTv
                          ? Icons.queue_music_rounded
                          : Icons.fullscreen_exit_rounded,
                      tooltip: isTv
                          ? l10n.musicVideoBackToList
                          : l10n.musicVideoExitFullscreen,
                      onTap: widget.onExit,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _format(Duration d) {
    final minutes = d.inMinutes.toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

/// A round control on the picture, light on dark whatever the theme: the
/// picture behind it is what sets the background.
class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.onTap,
    this.focusNode,
    this.color,
    this.tooltip,
    this.large = false,
    this.loading = false,
  });

  final IconData icon;

  /// Null greys the control out and takes it off the remote's path.
  final VoidCallback? onTap;
  final FocusNode? focusNode;
  final Color? color;
  final String? tooltip;
  final bool large;

  /// A spinner in the icon's place, the control still what it was.
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final size = large
        ? Dimens.musicFullscreenPlayButtonSize
        : Dimens.musicFullscreenControlSize;
    final button = FocusableTap(
      focusNode: focusNode,
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: large ? 0.25 : 0.12),
        ),
        child: loading
            ? Center(
                child: Loading(size: size * Dimens.musicFullscreenIconShare),
              )
            : Icon(
                icon,
                size: size * Dimens.musicFullscreenIconShare,
                color: onTap == null
                    ? Colors.white.withValues(alpha: 0.35)
                    : color ?? Colors.white,
              ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

/// What the picture is playing at, as a badge. Read only.
class _QualityChip extends StatelessWidget {
  const _QualityChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    if (label.isEmpty) return const SizedBox.shrink();
    return DecoratedBox(
      decoration: BoxDecoration(
        // Dark under the text so it reads over a bright frame as well.
        color: Colors.black.withValues(alpha: 0.35),
        border: Border.all(color: Colors.white70),
        borderRadius: BorderRadius.circular(Dimens.radiusControlSmall),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
