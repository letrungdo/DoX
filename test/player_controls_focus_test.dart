import 'package:do_x/widgets/player_controls_focus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The player's shape, reduced to what decides where the remote can go: a
/// focus node over the whole picture, with the transport bar stacked *inside*
/// it. That containment is the whole problem — directional traversal only ever
/// looks outside the rectangle it starts from.
class _Harness extends StatefulWidget {
  const _Harness({super.key, this.controlsVisible = true});

  /// Whether the bar starts on screen. Hidden, it is held out of the focus
  /// tree — the rule both players are built on.
  final bool controlsVisible;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  final videoNode = FocusNode(debugLabel: 'video');
  final controlsScope = FocusScopeNode(debugLabel: 'controls');
  final playNode = FocusNode(debugLabel: 'play');
  final fullScreenNode = FocusNode(debugLabel: 'fullscreen');

  late bool showControls = widget.controlsVisible;
  int seeks = 0;
  int playPauses = 0;
  int fullScreenPresses = 0;

  @override
  void dispose() {
    videoNode.dispose();
    controlsScope.dispose();
    playNode.dispose();
    fullScreenNode.dispose();
    super.dispose();
  }

  KeyEventResult _onVideoKey(FocusNode node, KeyEvent event) {
    if (!node.hasPrimaryFocus) return KeyEventResult.ignored;
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
        event.logicalKey == LogicalKeyboardKey.arrowRight) {
      seeks++;
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      // Exactly what the two players do: a bar already on screen is entered
      // straight away, one that has to be woken first only once the frame
      // carrying it has been built.
      if (showControls) {
        focusPlayerControls(controlsScope);
      } else {
        setState(() => showControls = true);
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => focusPlayerControls(controlsScope),
        );
      }
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter) {
      playPauses++;
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: videoNode,
      autofocus: true,
      onKeyEvent: _onVideoKey,
      child: Stack(
        children: [
          const Positioned.fill(child: ColoredBox(color: Colors.black)),
          Align(
            alignment: Alignment.bottomCenter,
            child: ExcludeFocus(
              excluding: !showControls,
              child: PlayerControlsFocus(
                node: controlsScope,
                exit: TraversalDirection.up,
                onExit: videoNode.requestFocus,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      focusNode: playNode,
                      icon: const Icon(Icons.play_arrow_rounded),
                      onPressed: () {},
                    ),
                    IconButton(
                      focusNode: fullScreenNode,
                      icon: const Icon(Icons.fullscreen_rounded),
                      onPressed: () => fullScreenPresses++,
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

/// A bar whose controls are stacked: one at the top of the picture and one in
/// the middle of it, both in one bar, with the picture holding the focus until
/// an arrow is pressed.
class _StackedHarness extends StatefulWidget {
  const _StackedHarness({super.key});

  @override
  State<_StackedHarness> createState() => _StackedHarnessState();
}

class _StackedHarnessState extends State<_StackedHarness> {
  final videoNode = FocusNode(debugLabel: 'video');
  final controlsScope = FocusScopeNode(debugLabel: 'controls');
  final backNode = FocusNode(debugLabel: 'back');
  final playNode = FocusNode(debugLabel: 'play');

  @override
  void dispose() {
    videoNode.dispose();
    controlsScope.dispose();
    backNode.dispose();
    playNode.dispose();
    super.dispose();
  }

  KeyEventResult _onVideoKey(FocusNode node, KeyEvent event) {
    if (!node.hasPrimaryFocus || event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    final isUp = event.logicalKey == LogicalKeyboardKey.arrowUp;
    if (isUp || event.logicalKey == LogicalKeyboardKey.arrowDown) {
      focusPlayerControls(controlsScope, preferred: isUp ? backNode : playNode);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: videoNode,
      autofocus: true,
      onKeyEvent: _onVideoKey,
      child: PlayerControlsFocus(
        node: controlsScope,
        exit: TraversalDirection.up,
        onExit: videoNode.requestFocus,
        child: Column(
          children: [
            IconButton(
              focusNode: backNode,
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () {},
            ),
            Expanded(
              child: Center(
                child: IconButton(
                  focusNode: playNode,
                  icon: const Icon(Icons.play_arrow_rounded),
                  onPressed: () {},
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The inline player of the movie page: a picture with its transport bar, and
/// the page it sits on carrying on underneath — the episode list.
class _InlineHarness extends StatefulWidget {
  const _InlineHarness({super.key});

  @override
  State<_InlineHarness> createState() => _InlineHarnessState();
}

class _InlineHarnessState extends State<_InlineHarness> {
  final videoNode = FocusNode(debugLabel: 'video');
  final controlsScope = FocusScopeNode(debugLabel: 'controls');
  final playNode = FocusNode(debugLabel: 'play');
  final episodeNode = FocusNode(debugLabel: 'episode');

  @override
  void dispose() {
    videoNode.dispose();
    controlsScope.dispose();
    playNode.dispose();
    episodeNode.dispose();
    super.dispose();
  }

  KeyEventResult _onVideoKey(FocusNode node, KeyEvent event) {
    if (!node.hasPrimaryFocus || event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      focusPlayerControls(controlsScope, preferred: playNode);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 200,
          child: Focus(
            focusNode: videoNode,
            autofocus: true,
            onKeyEvent: _onVideoKey,
            child: Stack(
              children: [
                const Positioned.fill(child: ColoredBox(color: Colors.black)),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: PlayerControlsFocus(
                    node: controlsScope,
                    exit: TraversalDirection.up,
                    onExit: videoNode.requestFocus,
                    child: IconButton(
                      focusNode: playNode,
                      icon: const Icon(Icons.play_arrow_rounded),
                      onPressed: () {},
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        IconButton(
          focusNode: episodeNode,
          icon: const Icon(Icons.list_rounded),
          onPressed: () {},
        ),
      ],
    );
  }
}

void main() {
  Future<_HarnessState> pump(WidgetTester tester) async {
    final key = GlobalKey<_HarnessState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: _Harness(key: key)),
      ),
    );
    await tester.pumpAndSettle();
    return key.currentState!;
  }

  testWidgets('pressing down puts the remote on the first control', (
    tester,
  ) async {
    final state = await pump(tester);
    expect(state.videoNode.hasPrimaryFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    expect(state.playNode.hasPrimaryFocus, isTrue);
  });

  testWidgets('the remote can walk along the bar to the full screen button', (
    tester,
  ) async {
    final state = await pump(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();

    // Right seeks the film only while the picture itself holds the focus; on
    // a control it has to move along the bar instead.
    expect(state.fullScreenNode.hasPrimaryFocus, isTrue);
    expect(state.seeks, 0);
  });

  testWidgets('OK presses the control the remote is on, not play/pause', (
    tester,
  ) async {
    final state = await pump(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(state.fullScreenPresses, 1);
    expect(state.playPauses, 0);
  });

  testWidgets('pressing up off the bar hands the remote back to the picture', (
    tester,
  ) async {
    final state = await pump(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();

    expect(state.videoNode.hasPrimaryFocus, isTrue);

    // And the picture has its keys back: left/right seek again.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(state.seeks, 1);
  });

  group('a bar with its controls stacked', () {
    Future<_StackedHarnessState> pumpStacked(WidgetTester tester) async {
      final key = GlobalKey<_StackedHarnessState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: _StackedHarness(key: key)),
        ),
      );
      await tester.pumpAndSettle();
      return key.currentState!;
    }

    testWidgets('the press towards the picture aims at the play button', (
      tester,
    ) async {
      final state = await pumpStacked(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();

      expect(state.playNode.hasPrimaryFocus, isTrue);
    });

    testWidgets('up off the play button reaches the back button above it', (
      tester,
    ) async {
      final state = await pumpStacked(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();

      // Not the picture: there is still a control above, and only the press
      // that leaves the last of them goes back.
      expect(state.backNode.hasPrimaryFocus, isTrue);
    });

    testWidgets('up off the topmost control goes back to the picture', (
      tester,
    ) async {
      final state = await pumpStacked(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();

      expect(state.videoNode.hasPrimaryFocus, isTrue);
    });

    testWidgets('down off the back button reaches the play button again', (
      tester,
    ) async {
      final state = await pumpStacked(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(state.backNode.hasPrimaryFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();

      expect(state.playNode.hasPrimaryFocus, isTrue);
    });
  });

  testWidgets('the press away from the player reaches the page below it', (
    tester,
  ) async {
    final key = GlobalKey<_InlineHarnessState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: _InlineHarness(key: key)),
      ),
    );
    await tester.pumpAndSettle();
    final state = key.currentState!;

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(state.playNode.hasPrimaryFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    // A scope holds directional focus inside itself unless it is told not to,
    // which left the remote stuck on the transport bar with the episode list
    // one press away underneath it.
    expect(state.episodeNode.hasPrimaryFocus, isTrue);
  });

  testWidgets('a hidden bar holds no focus, so the outline marks nothing', (
    tester,
  ) async {
    final key = GlobalKey<_HarnessState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: _Harness(key: key, controlsVisible: false)),
      ),
    );
    await tester.pumpAndSettle();
    final state = key.currentState!;

    // Nothing may reach into a bar that is not on screen — not the remote,
    // and not the code that hands it over either.
    focusPlayerControls(state.controlsScope);
    await tester.pumpAndSettle();

    expect(state.playNode.hasPrimaryFocus, isFalse);
    expect(state.fullScreenNode.hasPrimaryFocus, isFalse);
    expect(state.videoNode.hasPrimaryFocus, isTrue);
  });

  testWidgets('waking the bar puts the remote on it in the same press', (
    tester,
  ) async {
    final key = GlobalKey<_HarnessState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: _Harness(key: key, controlsVisible: false)),
      ),
    );
    await tester.pumpAndSettle();
    final state = key.currentState!;

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    expect(state.showControls, isTrue);
    expect(state.playNode.hasPrimaryFocus, isTrue);
  });

  testWidgets('coming back to the bar lands on the control it left', (
    tester,
  ) async {
    final state = await pump(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    expect(state.fullScreenNode.hasPrimaryFocus, isTrue);
  });
}
