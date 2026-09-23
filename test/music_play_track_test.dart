import 'dart:async';

import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/model/music_track.dart';
import 'package:do_x/services/music_playback_session.dart';
import 'package:do_x/view_model/music/music_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

MusicTrack _track(String id) => MusicTrack(
  id: id,
  title: 'Track $id',
  artist: 'Artist',
  artworkUrl: '',
  streamUrl: 'transcoding-$id',
  duration: const Duration(minutes: 3),
);

void main() {
  late FakeVideoPlayerPlatform platform;
  late Map<String, Completer<String>> pending;
  late MusicViewModel vm;

  Future<void> pumpHost(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            vm.setCurrentContext(context);
            return const SizedBox();
          },
        ),
      ),
    );
  }

  setUp(() {
    platform = FakeVideoPlayerPlatform(
      playing: {'https://cdn/a', 'https://cdn/b'},
    );
    VideoPlayerPlatform.instance = platform;
    pending = {};
    vm = MusicViewModel(
      resolveStream: (url) => (pending[url] = Completer<String>()).future,
      playback: _SilentPlayback(),
    );
  });

  testWidgets('a track tapped while another loads is the only one heard', (
    tester,
  ) async {
    await pumpHost(tester);
    await tester.runAsync(() async {
      final first = vm.playTrack(_track('a'));
      final second = vm.playTrack(_track('b'));
      await Future<void>.delayed(Duration.zero);
      // The first stream answers last-but-not-least: after the second tap.
      pending['transcoding-a']!.complete('https://cdn/a');
      pending['transcoding-b']!.complete('https://cdn/b');
      await Future.wait([first, second]);
    });

    expect(platform.sounding, hasLength(1));
    expect(vm.currentTrack?.id, 'b');
    vm.dispose();
  });

  testWidgets('leaving the page mid-load leaves nothing playing', (
    tester,
  ) async {
    await pumpHost(tester);
    await tester.runAsync(() async {
      final play = vm.playTrack(_track('a'));
      await Future<void>.delayed(Duration.zero);
      vm.dispose();
      pending['transcoding-a']!.complete('https://cdn/a');
      await play;
    });

    expect(platform.sounding, isEmpty);
  });
}
