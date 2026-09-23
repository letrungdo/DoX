import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:do_x/constants/dimens.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/screen/music/music_video_view.dart';
import 'package:do_x/store/immersive_mode.dart';
import 'package:do_x/utils/device_type.dart';
import 'package:do_x/view_model/music/music_view_model.dart';
import 'package:do_x/widgets/focusable_tap.dart';
import 'package:do_x/widgets/loading.dart';
import 'package:do_x/widgets/player_controls_focus.dart';
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
  });

  /// Back to the track list.
  final VoidCallback onExit;
  final VoidCallback onToggleLike;

  /// Makes a slider one the remote can step off — see the music page.
  final Widget Function(Widget slider) seekable;

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
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _showControls();
    if (!deviceType.isTv) _takeTheScreen();
  }

  /// The phone's whole screen: the bars and the tab bar out of the way.
  void _takeTheScreen() {
    immersiveMode.value = true;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _giveTheScreenBack() {
    immersiveMode.value = false;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
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
    if (!_controlsVisible) setState(() => _controlsVisible = true);
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
              Focus(
                focusNode: _pictureNode,
                onKeyEvent: _onPictureKey,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _onPictureTap,
                  child: Center(
                    child: video != null
                        ? MusicVideoView(
                            controller: video,
                            isOfficialAudio: vm.isAudioFromVideo,
                            borderRadius: BorderRadius.zero,
                          )
                        : _buildWaiting(track?.artworkUrl ?? ''),
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
                      // A finger on the controls keeps them up, the way a
                      // key press does on a television.
                      child: Listener(
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

  /// The next track's artwork while its video is still being fetched, so a
  /// skip does not flash the track list up between two videos.
  Widget _buildWaiting(String artworkUrl) {
    return Stack(
      alignment: Alignment.center,
      children: [
        if (artworkUrl.isNotEmpty)
          Opacity(
            opacity: 0.4,
            child: CachedNetworkImage(
              imageUrl: artworkUrl,
              width: Dimens.musicFullscreenWaitingArtSize,
              height: Dimens.musicFullscreenWaitingArtSize,
              fit: BoxFit.cover,
            ),
          ),
        const Loading(),
      ],
    );
  }

  Widget _buildControls(MusicViewModel vm) {
    final l10n = context.l10n;
    final track = vm.currentTrack;
    final duration = vm.duration.inMilliseconds.toDouble();
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
            // Clear of the notch and the home indicator, wherever the phone
            // has turned them.
            : MediaQuery.paddingOf(context).copyWith(top: 0) +
                  Dimens.musicPhoneControlsPadding,
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
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 4,
                  activeTrackColor: white,
                  inactiveTrackColor: Colors.white24,
                  thumbColor: white,
                ),
                child: widget.seekable(
                  Slider(
                    value: vm.position.inMilliseconds.toDouble().clamp(
                      0.0,
                      duration,
                    ),
                    max: duration == 0 ? 1 : duration,
                    onChanged: (value) =>
                        vm.seekTo(Duration(milliseconds: value.toInt())),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _format(vm.position),
                    style: TextStyle(color: muted, fontSize: 12),
                  ),
                  Text(
                    _format(vm.duration),
                    style: TextStyle(color: muted, fontSize: 12),
                  ),
                ],
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
                    _ControlButton(
                      icon: Icons.videocam_off_rounded,
                      tooltip: l10n.musicVideoHide,
                      onTap: vm.toggleVideo,
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
  });

  final IconData icon;
  final VoidCallback onTap;
  final FocusNode? focusNode;
  final Color? color;
  final String? tooltip;
  final bool large;

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
        child: Icon(icon, size: size * 0.55, color: color ?? Colors.white),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

/// What the picture is playing at, so a soft one is explained.
class _QualityChip extends StatelessWidget {
  const _QualityChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    if (label.isEmpty) return const SizedBox.shrink();
    return DecoratedBox(
      decoration: BoxDecoration(
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
