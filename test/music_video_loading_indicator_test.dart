import 'dart:async';

import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/model/music_track.dart';
import 'package:do_x/model/music_video.dart';
import 'package:do_x/screen/music/music_fullscreen_video_player.dart';
import 'package:do_x/services/music_playback_session.dart';
import 'package:do_x/utils/device_type.dart';
import 'package:do_x/view_model/music/music_view_model.dart';
import 'package:do_x/widgets/loading.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'fake_video_player_platform.dart';

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

const _track = MusicTrack(
  id: 'a',
  title: 'Track a',
  artist: 'Artist',
  artworkUrl: '',
  streamUrl: 'transcoding-a',
  duration: Duration(minutes: 3),
);

/// Where the full-screen player shows that the video is still on its way:
/// over the picture while nothing plays yet, and on the video button once
/// the music has started.
void main() {
  for (final isTv in [false, true]) {
    final device = isTv ? 'a television' : 'a phone';

    testWidgets('on $device the video wait moves from the picture to the '
        'video button once the music plays', (tester) async {
      deviceType.isTv = isTv;
      addTearDown(() => deviceType.isTv = false);
      VideoPlayerPlatform.instance = FakeVideoPlayerPlatform(
        playing: {'https://cdn/a'},
      );
      // Never answers: the video is still being looked for throughout.
      final video = Completer<MusicVideo?>();
      final vm = MusicViewModel(
        resolveStream: (_) async => 'https://cdn/a',
        playback: _SilentPlayback(),
        findVideo: (_) => video.future,
        findHdVideo: (_) async => null,
        videoEnabled: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              vm.setCurrentContext(context);
              return ChangeNotifierProvider.value(
                value: vm,
                child: MusicFullscreenVideoPlayer(
                  onExit: () {},
                  onToggleLike: () {},
                  seekable: (slider) => slider,
                ),
              );
            },
          ),
        ),
      );
      unawaited(vm.playTrack(_track));
      await tester.pump(const Duration(milliseconds: 100));

      // Nothing is playing yet: the spinner is over the picture, and the
      // video button is its plain self.
      expect(vm.audioController, isNull);
      expect(vm.isVideoLoadingOverSound, isFalse);
      expect(find.byType(Loading), findsOneWidget);
      expect(find.byIcon(Icons.videocam_rounded), findsOneWidget);

      // Past the wait for an official sound: the track's own stream plays,
      // and only the picture is still to come.
      await tester.pump(const Duration(seconds: 5));
      await tester.pump();
      expect(vm.audioController, isNotNull);
      expect(vm.isVideoLoadingOverSound, isTrue);
      expect(find.byType(Loading), findsOneWidget);
      expect(find.byIcon(Icons.videocam_rounded), findsNothing);
      expect(
        find.descendant(
          of: find.byType(Tooltip),
          matching: find.byType(Loading),
        ),
        findsOneWidget,
        reason: 'the spinner is on the video button, not over the picture',
      );

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      vm.dispose();
      await tester.pump(const Duration(seconds: 6));
    });
  }
}
