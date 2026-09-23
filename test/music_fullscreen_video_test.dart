import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/model/music_track.dart';
import 'package:do_x/screen/music/music_fullscreen_video_player.dart';
import 'package:do_x/screen/music/music_video_view.dart';
import 'package:do_x/services/music_playback_session.dart';
import 'package:do_x/store/immersive_mode.dart';
import 'package:do_x/view_model/music/music_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// Keeps the system's media service out of it: a test has none to start.
class _SilentPlayback extends MusicPlaybackSession {
  @override
  void attach(MusicPlaybackControls controls, {required String channelName}) {}

  @override
  void detach(MusicPlaybackControls controls) {}

  @override
  void updateTrack(MusicTrack track, Duration duration) {}

  @override
  void updateState({
    required bool playing,
    required Duration position,
    bool loading = false,
  }) {}
}

void main() {
  late MusicViewModel vm;

  setUp(() {
    vm = MusicViewModel(
      resolveStream: (_) async => '',
      playback: _SilentPlayback(),
      findVideo: (_) async => null,
      findHdVideo: (_) async => null,
      videoEnabled: true,
    );
  });

  tearDown(() => vm.dispose());

  Widget host({required bool open, required VoidCallback onExit}) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ChangeNotifierProvider.value(
        value: vm,
        child: open
            ? MusicFullscreenVideoPlayer(
                onExit: onExit,
                onToggleLike: () {},
                seekable: (slider) => slider,
              )
            : const SizedBox(),
      ),
    );
  }

  testWidgets('a phone gets the whole screen and gives it back', (
    tester,
  ) async {
    var exits = 0;
    await tester.pumpWidget(host(open: true, onExit: () => exits++));
    expect(immersiveMode.value, isTrue);

    await tester.tap(find.byIcon(Icons.fullscreen_exit_rounded));
    expect(exits, 1);

    await tester.pumpWidget(host(open: false, onExit: () {}));
    // Past the delay after which the phone may rotate freely again.
    await tester.pump(const Duration(seconds: 1));
    expect(immersiveMode.value, isFalse);
  });

  testWidgets('the bottom row keeps off the system gesture strip', (
    tester,
  ) async {
    tester.view.systemGestureInsets = const FakeViewPadding(bottom: 90);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host(open: true, onExit: () {}));

    // 90 physical pixels at the test's ratio of 3 is 30 logical.
    final screen = tester.getSize(find.byType(MaterialApp));
    final row = tester.getBottomLeft(find.byIcon(Icons.skip_next_rounded));
    expect(screen.height - row.dy, greaterThanOrEqualTo(30));

    await tester.pumpWidget(host(open: false, onExit: () {}));
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('a tap on the picture hides the controls and another brings '
      'them back', (tester) async {
    await tester.pumpWidget(host(open: true, onExit: () {}));
    double opacity() =>
        tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity;
    expect(opacity(), 1);

    await tester.tapAt(const Offset(200, 100));
    await tester.pump();
    expect(opacity(), 0);

    await tester.tapAt(const Offset(200, 100));
    await tester.pump();
    expect(opacity(), 1);

    await tester.pumpWidget(host(open: false, onExit: () {}));
    await tester.pump(const Duration(seconds: 1));
  });

  test('the quality is named the way YouTube names its streams', () {
    expect(musicVideoQualityLabel(Size.zero), '');
    expect(musicVideoQualityLabel(const Size(640, 360)), '360p');
    // Letterboxed: YouTube's 720p, not a 536p.
    expect(musicVideoQualityLabel(const Size(1280, 536)), '720p HD');
    expect(musicVideoQualityLabel(const Size(1920, 1080)), '1080p HD');
    // Upright video, named by its short side.
    expect(musicVideoQualityLabel(const Size(720, 1280)), '720p HD');
  });
}
