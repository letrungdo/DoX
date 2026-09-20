import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:do_x/constants/dimens.dart';
import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/model/tv_channel.dart';
import 'package:do_x/utils/logger.dart';
import 'package:do_x/widgets/focusable_tap.dart';
import 'package:do_x/widgets/loading.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

/// Plays one live channel, full screen.
///
/// A bare [Scaffold] on purpose: the picture bleeds to every edge, so the
/// insets [AppScaffold] applies would frame it in black bars. The controls sit
/// over it inside their own [SafeArea].
@RoutePage()
class TvPlayerScreen extends StatefulWidget {
  const TvPlayerScreen({super.key, required this.channel});

  final TvChannel channel;

  @override
  State<TvPlayerScreen> createState() => _TvPlayerScreenState();
}

class _TvPlayerScreenState extends State<TvPlayerScreen> {
  VideoPlayerController? _controller;
  VoidCallback? _listener;

  bool _isLoading = true;
  bool _hasError = false;
  bool _showControls = true;
  Timer? _hideControlsTimer;

  /// How long the controls stay up after a tap before they fade away again.
  static const _controlsTimeout = Duration(seconds: 4);

  @override
  void initState() {
    super.initState();
    unawaited(_setImmersive(true));
    _open();
    _scheduleHideControls();
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    unawaited(_setImmersive(false));
    final controller = _controller;
    final listener = _listener;
    if (controller != null && listener != null) {
      controller.removeListener(listener);
    }
    unawaited(controller?.dispose());
    super.dispose();
  }

  /// Hides the system bars while the channel is on screen and restores the
  /// app's edge-to-edge mode on the way out — the same pair the movie player
  /// uses when it goes full screen.
  Future<void> _setImmersive(bool enabled) async {
    try {
      await SystemChrome.setEnabledSystemUIMode(
        enabled ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
      );
    } on Object catch (e) {
      // A platform without the channel is no reason to fail playback.
      logger.d('TvPlayerScreen system UI mode failed: $e');
    }
  }

  Future<void> _open() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    final controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.channel.url),
      httpHeaders: widget.channel.headers,
    );

    try {
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }

      void listener() {
        if (!mounted || !identical(_controller, controller)) return;
        // A live stream that drops surfaces only here; left alone the last
        // frame simply freezes on screen with no way to tell.
        if (controller.value.hasError && !_hasError) {
          logger.e(
            'TvPlayerScreen playback error: '
            '${controller.value.errorDescription}',
          );
          setState(() {
            _hasError = true;
            _isLoading = false;
            _showControls = true;
          });
          return;
        }
        setState(() {});
      }

      controller
        ..addListener(listener)
        ..setLooping(false);
      await controller.play();

      if (!mounted) {
        controller.removeListener(listener);
        await controller.dispose();
        return;
      }

      setState(() {
        _controller = controller;
        _listener = listener;
        _isLoading = false;
      });
    } on Object catch (e, st) {
      logger.e(
        'TvPlayerScreen could not open ${widget.channel.name}',
        error: e,
        stackTrace: st,
      );
      await controller.dispose();
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _isLoading = false;
        _showControls = true;
      });
    }
  }

  Future<void> _retry() async {
    final controller = _controller;
    final listener = _listener;
    if (controller != null && listener != null) {
      controller.removeListener(listener);
    }
    unawaited(controller?.dispose());
    setState(() {
      _controller = null;
      _listener = null;
    });
    await _open();
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _scheduleHideControls();
  }

  void _scheduleHideControls() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(_controlsTimeout, () {
      // While playback is broken the controls are the only way out of the
      // page, so they stay put until something plays.
      if (!mounted || _hasError || _isLoading) return;
      setState(() => _showControls = false);
    });
  }

  void _togglePlayback() {
    final controller = _controller;
    if (controller == null) return;
    if (controller.value.isPlaying) {
      controller.pause();
    } else {
      controller.play();
    }
    _scheduleHideControls();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final controller = _controller;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggleControls,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (controller != null && controller.value.isInitialized)
              Center(
                child: AspectRatio(
                  aspectRatio: controller.value.aspectRatio,
                  child: VideoPlayer(controller),
                ),
              ),
            if (_isLoading) const Center(child: Loading()),
            if (_hasError) _buildError(l10n),
            AnimatedOpacity(
              opacity: _showControls ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: IgnorePointer(
                ignoring: !_showControls,
                child: _buildControls(l10n, controller),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: Dimens.screenPadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 12,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.white70,
              size: 44,
            ),
            Text(
              l10n.tvPlaybackFailed,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            FilledButton.icon(
              onPressed: _retry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(l10n.retry),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControls(
    AppLocalizations l10n,
    VideoPlayerController? controller,
  ) {
    final isPlaying = controller?.value.isPlaying ?? false;

    return Column(
      children: [
        // The gradients are what keep white controls readable over a bright
        // frame; the picture underneath is not ours to dim any further.
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black87, Colors.transparent],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 12, 12),
              child: Row(
                spacing: 8,
                children: [
                  FocusableTap(
                    onTap: () => Navigator.of(context).maybePop(),
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      widget.channel.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  if (!_hasError && !_isLoading) _LiveBadge(label: l10n.tvLive),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: Center(
            child: controller == null
                ? const SizedBox.shrink()
                : FocusableTap(
                    onTap: _togglePlayback,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

/// The "this is a live stream" marker: a live channel has no timeline to show
/// how far in it is, so this is what stands in for one.
class _LiveBadge extends StatelessWidget {
  const _LiveBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.redAccent,
        borderRadius: BorderRadius.circular(Dimens.radiusSmall),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
