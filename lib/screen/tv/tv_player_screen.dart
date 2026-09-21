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
  const TvPlayerScreen({
    super.key,
    required this.channel,
    this.playlist = const [],
  });

  /// The channel to open with.
  final TvChannel channel;

  /// The channels either side of it, in the order the grid showed them.
  ///
  /// This is what makes the page behave like a television rather than like a
  /// video: up and down move to the next channel without going back to a
  /// list, and OK brings the list to the viewer over the picture that keeps
  /// playing. Left empty, the page is a single-channel player as before.
  final List<TvChannel> playlist;

  @override
  State<TvPlayerScreen> createState() => _TvPlayerScreenState();
}

class _TvPlayerScreenState extends State<TvPlayerScreen> {
  VideoPlayerController? _controller;
  VoidCallback? _listener;

  /// What is on screen now, which is not what the page was opened on once the
  /// viewer has pressed up or down.
  late TvChannel _channel = widget.channel;

  /// Where [_channel] sits in [TvPlayerScreen.playlist]. -1 when the page was
  /// opened without one, which is what turns the channel keys off.
  late int _index = widget.playlist.indexWhere(
    (channel) => channel.url == widget.channel.url,
  );

  bool get _canChangeChannel => _index >= 0 && widget.playlist.length > 1;

  /// The channel name over the picture, just after a change.
  ///
  /// A television names the channel it has just moved to and then gets out of
  /// the way; without it, pressing up twice quickly leaves the viewer with no
  /// idea where they have landed until the stream comes up.
  bool _showChannelName = false;
  Timer? _channelNameTimer;

  /// Whether the channel list is open over the picture.
  bool _showChannelList = false;

  /// The channel number being typed on the remote's keypad.
  ///
  /// A television takes digits one at a time and waits a moment to see
  /// whether another is coming — 1 then 2 is channel 12, not channel 1 and
  /// then channel 2 — so what has been typed so far sits here until the
  /// pause says the number is finished.
  String _typedNumber = '';
  Timer? _typedNumberTimer;

  /// Which of [_channel]'s mirrors is on screen.
  ///
  /// A live link dies quietly — the manifest still loads, the segments are
  /// gone, and the picture never starts — so a channel that will not come up
  /// is not a channel that is off the air until every link it has behind it
  /// has been tried too.
  int _sourceIndex = 0;

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

  /// The channel list, which is its own scope so the D-pad stays inside it
  /// while it is open instead of walking off onto the picture behind.
  final FocusScopeNode _channelListScope = FocusScopeNode(
    debugLabel: 'tv-channels',
  );

  final ScrollController _channelListController = ScrollController();

  /// The row of the channel playing, so the list opens on it rather than on
  /// whichever row happens to be built first.
  final FocusNode _currentChannelFocusNode = FocusNode(
    debugLabel: 'tv-current-channel',
  );

  /// How many times the playlist is repeated inside the open list.
  ///
  /// The list scrolls on past either end the way the channel keys wrap, so a
  /// viewer who keeps pressing down never hits a wall. An odd number of
  /// copies so the middle one — the copy the list opens on — has as much room
  /// either side of it.
  static const _channelListLoops = 101;

  bool get _controlsHaveFocus => _controlsScope.hasFocus;

  /// Where the middle copy of the playlist starts inside the looping list.
  int get _channelListBase => widget.playlist.length * (_channelListLoops ~/ 2);

  /// How long the controls stay up after a tap before they fade away again.
  static const _controlsTimeout = Duration(seconds: 4);

  /// How long the name of a channel just moved to stays over the picture.
  /// Long enough to read from a sofa, short enough that pressing up three
  /// times does not leave a banner sitting on the programme.
  static const _channelNameTimeout = Duration(seconds: 3);

  /// How long a typed digit waits for the next one before the number is
  /// taken as finished. The pause every television keypad has.
  static const _typedNumberTimeout = Duration(milliseconds: 1500);

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
    _channelNameTimer?.cancel();
    _typedNumberTimer?.cancel();
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
    _channelListScope.dispose();
    _channelListController.dispose();
    _currentChannelFocusNode.dispose();
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

    if (_channel.urls.isEmpty) {
      _showError();
      return;
    }

    final url = _channel.urls[_sourceIndex.clamp(0, _channel.urls.length - 1)];
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(url),
      httpHeaders: _channel.headers,
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
          unawaited(_onSourceFailed());
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
        'TvPlayerScreen could not open ${_channel.name}',
        error: e,
        stackTrace: st,
      );
      // Not awaited: a controller whose creation threw never finishes
      // disposing — it waits on the very creation that failed — and the
      // channel would sit on the spinner for good waiting with it.
      unawaited(controller.dispose());
      if (!mounted) return;
      await _onSourceFailed();
    }
  }

  /// Moves to the channel's next mirror, or gives up when there is none.
  ///
  /// Silent on purpose: swapping links is the player doing its job, and a
  /// viewer who sees the spinner run a moment longer has been told everything
  /// worth telling them. The error state is for a channel with nothing left.
  Future<void> _onSourceFailed() async {
    if (_sourceIndex >= _channel.urls.length - 1) {
      _showError();
      return;
    }
    logger.d(
      'TvPlayerScreen falling back to mirror ${_sourceIndex + 1} '
      'of ${_channel.name}',
    );
    _sourceIndex++;
    await _replaceController();
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

  /// Moves [delta] channels along the list and starts playing what is there.
  ///
  /// Wraps around: a remote has no end of the list, and stopping dead at the
  /// last channel is the one thing no television does.
  Future<void> _changeChannel(int delta) async {
    if (!_canChangeChannel) return;
    final channels = widget.playlist;
    final next = (_index + delta) % channels.length;

    _channelNameTimer?.cancel();
    setState(() {
      _index = next;
      _channel = channels[next];
      _sourceIndex = 0;
      _showChannelName = true;
      // The list is what the viewer was choosing from, and they have chosen.
      _showChannelList = false;
    });
    _channelNameTimer = Timer(_channelNameTimeout, () {
      if (!mounted) return;
      setState(() => _showChannelName = false);
    });

    await _replaceController();
  }

  /// Opens the picture on a channel picked out of the list.
  Future<void> _playFromList(int index) async {
    if (index == _index) {
      setState(() => _showChannelList = false);
      _videoFocusNode.requestFocus();
      return;
    }
    await _changeChannel(index - _index);
    if (!mounted) return;
    _videoFocusNode.requestFocus();
  }

  /// Brings the list up, and leaves it up if it already is.
  ///
  /// What up and down do: the remote has its own pair of channel keys for
  /// moving one at a time, so the arrows are better spent on the list, where
  /// the viewer can see what they are moving to.
  void _openChannelList() {
    if (_showChannelList) return;
    _toggleChannelList();
  }

  void _toggleChannelList() {
    if (!_canChangeChannel) return;
    setState(() => _showChannelList = !_showChannelList);
    if (_showChannelList) {
      // The list is only now being built, so there is nothing to hand the
      // remote to until the frame carrying it exists.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_showChannelList) return;
        _centreChannelList();
        // And the row it was scrolled to is itself only built by that scroll,
        // so the remote waits one more frame for it.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_showChannelList) return;
          if (_currentChannelFocusNode.context != null) {
            _currentChannelFocusNode.requestFocus();
            return;
          }
          _channelListScope.requestFocus();
        });
      });
      return;
    }
    _videoFocusNode.requestFocus();
  }

  /// Puts the channel playing in the middle of the open list.
  ///
  /// The list is thousands of rows long, and the one that matters is the one
  /// the viewer is on: opening at the top would leave them scrolling down to
  /// find out where they already are.
  void _centreChannelList() {
    if (!_channelListController.hasClients) return;
    const rowHeight = Dimens.tvChannelListRowHeight;
    final position = _channelListController.position;
    final target =
        (_channelListBase + _index) * rowHeight -
        (position.viewportDimension - rowHeight) / 2;
    _channelListController.jumpTo(
      target.clamp(position.minScrollExtent, position.maxScrollExtent),
    );
  }

  /// Drops the controller on screen so another channel can take its place.
  Future<void> _replaceController() async {
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

  Future<void> _retry() async {
    // The retry button is about to leave with the error state it belongs to.
    _videoFocusNode.requestFocus();
    // From the top of the list again: the mirrors were exhausted minutes ago
    // at the earliest, and the best of them is the one most likely to be back.
    _sourceIndex = 0;
    await _replaceController();
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
  /// The keys are a television's, not a video player's, because that is what
  /// this is: up, down and OK all bring the channel list up, and the way to
  /// the controls is sideways. A live channel has no timeline and nothing to
  /// pause, so there is nothing here to seek or stop with.
  ///
  /// The arrows open the list rather than changing channel, because the
  /// remote already has a pair of keys that change channel — and a blind hop
  /// to the next channel is the worse of the two things an arrow could mean
  /// when the list can show the viewer where they are going.
  ///
  /// Opened on a single channel — from a link, or from anywhere that has no
  /// list to hand — there are no neighbouring channels to move to, and the
  /// arrows go back to being the way to the controls.
  KeyEventResult _handleVideoKeyEvent(FocusNode node, KeyEvent event) {
    // The controls are inside this node, so their keys walk up through here.
    // Claiming them would swallow the OK meant for the focused button.
    if (!node.hasPrimaryFocus || event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;
    if (_canChangeChannel) {
      if (key == LogicalKeyboardKey.arrowUp ||
          key == LogicalKeyboardKey.arrowDown) {
        _openChannelList();
        return KeyEventResult.handled;
      }
      if (_isSelectKey(key)) {
        _toggleChannelList();
        return KeyEventResult.handled;
      }
    }

    final wakesControls = _canChangeChannel
        ? key == LogicalKeyboardKey.arrowLeft ||
              key == LogicalKeyboardKey.arrowRight
        : key == LogicalKeyboardKey.arrowUp ||
              key == LogicalKeyboardKey.arrowDown;
    if (wakesControls) {
      final wasVisible = _showControls;
      if (!wasVisible) setState(() => _showControls = true);
      _scheduleHideControls();
      // On a television the bar is shown and nothing more. Handing the
      // remote to the back button inside it would take the picture's keys
      // away with it — and the channel list, the channel buttons and the
      // keypad are the point of this page. The remote's own Back key is the way out, which is
      // where a viewer reaches for it anyway.
      if (deviceType.isTv && !_canChangeChannel) {
        _enterControls(afterFrame: !wasVisible);
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// The keys a television remote has that a game-pad style one does not:
  /// the channel pair and the number keypad.
  ///
  /// Handled for the whole page rather than for the picture, because they
  /// mean the same thing wherever the remote happens to be resting — on the
  /// back button, on the retry button of a channel that would not come up,
  /// anywhere. Only the arrows are the picture's own, because there they
  /// compete with moving between controls.
  KeyEventResult _handlePageKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || !_canChangeChannel) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;

    // CH+ is the next channel number, CH- the previous one. The skip pair a
    // recorder remote is printed with means the same thing here: there is no
    // track to skip on a live channel, and the two buttons sit where a thumb
    // expects to change channel from.
    if (key == LogicalKeyboardKey.channelDown ||
        key == LogicalKeyboardKey.mediaTrackPrevious) {
      unawaited(_changeChannel(-1));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.channelUp ||
        key == LogicalKeyboardKey.mediaTrackNext) {
      unawaited(_changeChannel(1));
      return KeyEventResult.handled;
    }
    final digit = _digitOf(key);
    if (digit != null) {
      _typeDigit(digit);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// The OK button, under each of the names a remote sends it by.
  bool _isSelectKey(LogicalKeyboardKey key) =>
      key == LogicalKeyboardKey.select ||
      key == LogicalKeyboardKey.enter ||
      key == LogicalKeyboardKey.gameButtonA;

  /// The digit [key] stands for, from the row of numbers or from a keypad.
  // Not `const`: `LogicalKeyboardKey` defines its own equality, which a
  // constant map may not have for its keys.
  static final _digits = <LogicalKeyboardKey, String>{
    LogicalKeyboardKey.digit0: '0',
    LogicalKeyboardKey.digit1: '1',
    LogicalKeyboardKey.digit2: '2',
    LogicalKeyboardKey.digit3: '3',
    LogicalKeyboardKey.digit4: '4',
    LogicalKeyboardKey.digit5: '5',
    LogicalKeyboardKey.digit6: '6',
    LogicalKeyboardKey.digit7: '7',
    LogicalKeyboardKey.digit8: '8',
    LogicalKeyboardKey.digit9: '9',
    LogicalKeyboardKey.numpad0: '0',
    LogicalKeyboardKey.numpad1: '1',
    LogicalKeyboardKey.numpad2: '2',
    LogicalKeyboardKey.numpad3: '3',
    LogicalKeyboardKey.numpad4: '4',
    LogicalKeyboardKey.numpad5: '5',
    LogicalKeyboardKey.numpad6: '6',
    LogicalKeyboardKey.numpad7: '7',
    LogicalKeyboardKey.numpad8: '8',
    LogicalKeyboardKey.numpad9: '9',
  };

  String? _digitOf(LogicalKeyboardKey key) => _digits[key];

  /// Takes one more digit of a channel number.
  ///
  /// The number is only acted on once it can no longer grow: either the
  /// viewer has typed as many digits as the list has, or they have stopped.
  /// A leading zero is nobody's channel, so it is ignored rather than
  /// counted towards the length.
  void _typeDigit(String digit) {
    final typed = _typedNumber + digit;
    if (typed == '0') return;

    _typedNumberTimer?.cancel();
    setState(() {
      _typedNumber = typed;
      // The name of the channel being left has nothing to say now.
      _showChannelName = false;
    });

    if (typed.length >= widget.playlist.length.toString().length) {
      _openTypedNumber();
      return;
    }
    _typedNumberTimer = Timer(_typedNumberTimeout, _openTypedNumber);
  }

  /// Goes to the channel the typed number stands for.
  ///
  /// Out of range it is simply forgotten: a television does not explain that
  /// channel 300 is not a channel, it goes back to what was on.
  void _openTypedNumber() {
    _typedNumberTimer?.cancel();
    final typed = int.tryParse(_typedNumber);
    if (!mounted) return;
    setState(() => _typedNumber = '');
    if (typed == null || typed < 1 || typed > widget.playlist.length) return;
    unawaited(_changeChannel(typed - 1 - _index));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final controller = _controller;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        // The list is what the Back key is pointed at while it is open; only
        // once it is gone does Back mean leaving the channel.
        if (_showChannelList) {
          _toggleChannelList();
          return;
        }
        Navigator.of(context).pop(_channel);
      },
      child: Focus(
        // Watching the whole page, taking no turn of its own: the keys below
        // are read after whatever holds the focus has declined them.
        canRequestFocus: false,
        skipTraversal: true,
        onKeyEvent: _handlePageKeyEvent,
        child: Scaffold(
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
                    if (_typedNumber.isNotEmpty)
                      _buildTypedNumber()
                    else if (_showChannelName && !_showChannelList)
                      _buildChannelName(),
                    if (_showChannelList) _buildChannelList(l10n),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The channel number as it is being typed.
  ///
  /// Bigger than the banner it stands in for, and in the same corner: it is
  /// the one thing on screen the viewer is waiting on, and they are reading
  /// it to check they pressed what they meant to.
  Widget _buildTypedNumber() {
    return IgnorePointer(
      child: Align(
        alignment: AlignmentDirectional.bottomStart,
        child: SafeArea(
          child: Padding(
            padding: Dimens.screenPadding,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(Dimens.radiusCard),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                child: Text(
                  _typedNumber,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The channel just moved to, named over the corner of the picture.
  ///
  /// Bottom left, where a television has always put it, and out of the way of
  /// the controls that come down from the top.
  Widget _buildChannelName() {
    return IgnorePointer(
      child: Align(
        alignment: AlignmentDirectional.bottomStart,
        child: SafeArea(
          child: Padding(
            padding: Dimens.screenPadding,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(Dimens.radiusCard),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 10,
                  children: [
                    Text(
                      // The position in the list, which is the closest thing
                      // these playlists have to a channel number.
                      '${_index + 1}',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      _channel.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The channel list, over the picture that keeps playing behind it.
  ///
  /// Down the side rather than across the screen: a viewer opening it is
  /// still watching, and a list that covered the programme would be a list
  /// they had to close before they could decide.
  Widget _buildChannelList(AppLocalizations l10n) {
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: FocusScope(
        node: _channelListScope,
        child: Shortcuts(
          shortcuts: const <ShortcutActivator, Intent>{
            SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
          },
          child: Actions(
            actions: {
              DismissIntent: CallbackAction<DismissIntent>(
                onInvoke: (_) {
                  _toggleChannelList();
                  return null;
                },
              ),
            },
            child: Container(
              width: Dimens.tvChannelListWidth,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: AlignmentDirectional.centerEnd,
                  end: AlignmentDirectional.centerStart,
                  colors: [
                    Colors.black.withValues(alpha: 0.92),
                    Colors.black.withValues(alpha: 0.55),
                  ],
                ),
              ),
              child: SafeArea(
                child: ListView.builder(
                  controller: _channelListController,
                  // No page padding down the sides: the row it would inset is
                  // the one the remote lifts, and the lift needs the room.
                  padding: EdgeInsets.zero,
                  // A known row height is what lets the list jump straight to
                  // the channel playing, thousands of rows in, without
                  // building everything above it.
                  itemExtent: Dimens.tvChannelListRowHeight,
                  itemCount: widget.playlist.length * _channelListLoops,
                  itemBuilder: (context, index) {
                    final position = index % widget.playlist.length;
                    final isPlaying = position == _index;
                    return _ChannelRow(
                      position: position + 1,
                      channel: widget.playlist[position],
                      isPlaying: isPlaying,
                      // Only the middle copy's row is the one the list opens
                      // on; the others are the same channel further along.
                      focusNode: index == _channelListBase + _index
                          ? _currentChannelFocusNode
                          : null,
                      onTap: () => _playFromList(position),
                    );
                  },
                ),
              ),
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
                    ExcludeFocus(
                      // The remote has a Back key of its own, so the button
                      // is a label for it rather than a stop on the way
                      // round the page — and leaving it out of the focus
                      // tree is what keeps the picture holding the keys.
                      excluding: deviceType.isTv && _canChangeChannel,
                      child: FocusableTap(
                        focusNode: _backFocusNode,
                        onTap: () => Navigator.of(context).pop(_channel),
                        child: const Padding(
                          padding: EdgeInsets.all(12),
                          child: Icon(
                            Icons.arrow_back_rounded,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        _channel.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
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

/// One channel in the list the player opens over the picture.
class _ChannelRow extends StatelessWidget {
  const _ChannelRow({
    required this.position,
    required this.channel,
    required this.isPlaying,
    required this.onTap,
    this.focusNode,
  });

  final int position;
  final TvChannel channel;

  /// The channel behind the list, marked so the viewer can see where they
  /// are before they start moving.
  final bool isPlaying;

  final VoidCallback onTap;

  /// Set on the row of the channel playing, which is where the remote is put
  /// when the list opens.
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    return FocusableTap(
      focusNode: focusNode,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Dimens.pagePadding,
          vertical: 4,
        ),
        child: Row(
          spacing: 12,
          children: [
            SizedBox(
              width: Dimens.tvChannelListNumberWidth,
              child: Text(
                '$position',
                textAlign: TextAlign.end,
                // Three digits stay on the line they belong to rather than
                // breaking under the first two.
                maxLines: 1,
                softWrap: false,
                style: const TextStyle(
                  color: Colors.white38,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(
              child: Text(
                channel.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isPlaying ? Colors.white : Colors.white70,
                  fontWeight: isPlaying ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            if (isPlaying)
              const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 18,
              ),
          ],
        ),
      ),
    );
  }
}
