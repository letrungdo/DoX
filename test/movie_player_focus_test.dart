import 'package:do_x/screen/movie/player_controls_focus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The player's shape, reduced to what decides where the remote can go: a
/// focus node over the whole picture, with the transport bar stacked *inside*
/// it. That containment is the whole problem — directional traversal only ever
/// looks outside the rectangle it starts from.
class _Harness extends StatefulWidget {
  const _Harness({super.key});

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  final videoNode = FocusNode(debugLabel: 'video');
  final controlsScope = FocusScopeNode(debugLabel: 'controls');
  final playNode = FocusNode(debugLabel: 'play');
  final fullScreenNode = FocusNode(debugLabel: 'fullscreen');

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
      focusPlayerControls(controlsScope);
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
        ],
      ),
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
