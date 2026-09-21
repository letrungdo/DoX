import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:do_x/constants/dimens.dart';
import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/model/tv_channel.dart';
import 'package:do_x/utils/device_type.dart';
import 'package:do_x/utils/logger.dart';
import 'package:do_x/widgets/focusable_tap.dart';
import 'package:do_x/widgets/loading.dart';
import 'package:do_x/widgets/player_controls_focus.dart';
import 'package:do_x/widgets/tv_shell.dart';
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

  /// Holds the remote while it is on the picture rather than on a control.
  final FocusNode _videoFocusNode = FocusNode(debugLabel: 'tv-video');

  /// The controls sit inside [_videoFocusNode]'s own rectangle, where
  /// directional traversal cannot find them, so the overlay is one scope the
  /// remote is handed by name. See [PlayerControlsFocus].
  final FocusScopeNode _controlsScope = FocusScopeNode(
    debugLabel: 'tv-controls',
  );

  /// Named so a press can aim at it: the way out of the channel, which is the
  /// only control a live picture has.
  final FocusNode _backFocusNode = FocusNode(debugLabel: 'tv-back');

  /// The retry button of the error state, which the remote is put on as soon
  /// as it appears.
  final FocusNode _retryFocusNode = FocusNode(debugLabel: 'tv-retry');

  bool get _controlsHaveFocus => _controlsScope.hasFocus;

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
    _videoFocusNode.dispose();
    _controlsScope.dispose();
    _backFocusNode.dispose();
    _retryFocusNode.dispose();
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
          _showError();
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
      _showError();
    }
  }

  /// Shows the channel as unplayable and puts the remote on the retry button.
  ///
  /// Explicitly, not by `autofocus`: that only takes effect while nothing in
  /// the scope holds the focus, and the picture has held it since the page
  /// opened. Without this the only control on screen is one the D-pad cannot
  /// reach — it sits inside the picture's own rectangle, where directional
  /// traversal never looks.
  void _showError() {
    setState(() {
      _hasError = true;
      _isLoading = false;
      _showControls = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_hasError) return;
      _retryFocusNode.requestFocus();
    });
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
    // The retry button is about to leave with the error state it belongs to.
    _videoFocusNode.requestFocus();
    await _open();
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) {
      _scheduleHideControls();
    } else {
      _releaseControlsFocus();
    }
  }

  void _scheduleHideControls() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(_controlsTimeout, () {
      // While playback is broken the controls are the only way out of the
      // page, so they stay put until something plays — and so does a control
      // the remote is resting on, which would otherwise be pulled out from
      // under the user mid-choice.
      if (!mounted || _hasError || _isLoading || _controlsHaveFocus) return;
      setState(() => _showControls = false);
    });
  }

  /// Puts the remote back on the picture. Hidden controls are held out of the
  /// focus tree, so the focus they were holding has to go somewhere first.
  void _releaseControlsFocus() {
    if (!_controlsHaveFocus) return;
    _videoFocusNode.requestFocus();
  }

  /// Takes the remote off a control and puts it back on the picture, keeping
  /// the controls up for as long as they would have stayed anyway.
  void _backToPicture() {
    _videoFocusNode.requestFocus();
    _scheduleHideControls();
  }

  /// Hands the remote to the controls, which on a live channel means the back
  /// button — and the press that leaves it goes back to the picture.
  ///
  /// [afterFrame] for controls that are only now being shown: hidden ones are
  /// held out of the focus tree, so there is nothing to hand the remote to
  /// until the frame carrying them exists.
  void _enterControls({required bool afterFrame}) {
    void enter() {
      focusPlayerControls(_controlsScope, preferred: _backFocusNode);
    }

    if (!afterFrame) {
      enter();
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_showControls) return;
      enter();
    });
  }

  /// The remote, on the picture itself.
  ///
  /// Arrows wake the controls and then walk onto them; OK puts them up and
  /// takes them down again. A live channel has no timeline and nothing to
  /// pause, so there is nothing here for the remote to seek or stop with.
  KeyEventResult _handleVideoKeyEvent(FocusNode node, KeyEvent event) {
    // The controls are inside this node, so their keys walk up through here.
    // Claiming them would swallow the OK meant for the focused button.
    if (!node.hasPrimaryFocus || event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowUp ||
        event.logicalKey == LogicalKeyboardKey.arrowDown) {
      final wasVisible = _showControls;
      if (!wasVisible) setState(() => _showControls = true);
      _scheduleHideControls();
      if (deviceType.isTv) _enterControls(afterFrame: !wasVisible);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final controller = _controller;

    return Scaffold(
      backgroundColor: Colors.black,
      body: TvFocusSurface(
        node: _videoFocusNode,
        child: Focus(
          focusNode: _videoFocusNode,
          autofocus: true,
          onKeyEvent: _handleVideoKeyEvent,
          child: GestureDetector(
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
                ExcludeFocus(
                  // Hidden, the controls are only invisible: left in the focus
                  // tree the remote lands on a button nobody can see, and the TV
                  // paints its outline around nothing at all.
                  excluding: !_showControls,
                  child: AnimatedOpacity(
                    opacity: _showControls ? 1 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: IgnorePointer(
                      ignoring: !_showControls,
                      child: _buildControls(l10n),
                    ),
                  ),
                ),
              ],
            ),
          ),
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
              focusNode: _retryFocusNode,
              onPressed: _retry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(l10n.retry),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControls(AppLocalizations l10n) {
    // One scope for the controls; the press that leaves them goes back to the
    // picture.
    return PlayerControlsFocus(
      node: _controlsScope,
      exit: TraversalDirection.up,
      onExit: _backToPicture,
      // A column for one bar: it is what keeps the bar at its own height at
      // the top of the picture, where the stack would otherwise stretch it
      // over the whole frame and the gradient with it.
      child: Column(
        children: [
          // The gradient is what keeps the white bar readable over a bright
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
                      focusNode: _backFocusNode,
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
                    if (!_hasError && !_isLoading)
                      _LiveBadge(label: l10n.tvLive),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
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
