import 'package:do_x/screen/movie/movie_player_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'fake_video_player_platform.dart';

/// The movie seek bar: the progress is drawn where the film is, with no
/// animation chasing it — a bar that animates every position report keeps the
/// player drawing frames for the whole film.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const barWidth = 400.0;
  const duration = Duration(minutes: 10);

  late VideoPlayerController controller;

  setUp(() {
    VideoPlayerPlatform.instance = FakeVideoPlayerPlatform();
    controller = VideoPlayerController.networkUrl(Uri.parse('https://a/b'))
      ..value = const VideoPlayerValue(duration: duration, isInitialized: true);
  });

  tearDown(() => controller.dispose());

  Future<void> pumpBar(WidgetTester tester, {bool live = true}) {
    return tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: barWidth,
            child: VideoSeekBar(
              controller: controller,
              isFocused: false,
              isHovered: false,
              isDragging: false,
              isScrubbing: false,
              live: live,
            ),
          ),
        ),
      ),
    );
  }

  /// The played part of the bar: the one track filled with the played colour.
  double playedWidth(WidgetTester tester) {
    final played = find.byWidgetPredicate(
      (widget) =>
          widget is Container &&
          widget.decoration is BoxDecoration &&
          (widget.decoration! as BoxDecoration).color == Colors.pinkAccent,
    );
    return tester.getSize(played).width;
  }

  void moveTo(Duration position) {
    controller.value = controller.value.copyWith(position: position);
  }

  testWidgets('the played part jumps to the position without animating', (
    tester,
  ) async {
    await pumpBar(tester);

    moveTo(duration * 0.5);
    await tester.pump();

    expect(playedWidth(tester), barWidth * 0.5);
    // Nothing left to draw: the bar is already where the film is.
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('a hidden bar does not follow the film', (tester) async {
    await pumpBar(tester, live: false);

    moveTo(duration * 0.5);
    await tester.pump();

    expect(playedWidth(tester), 0);
    expect(tester.binding.hasScheduledFrame, isFalse);

    // Shown again, it picks up where the film has got to.
    await pumpBar(tester);
    expect(playedWidth(tester), barWidth * 0.5);
  });
}
