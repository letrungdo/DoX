import 'dart:async';

import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/theme/app_theme.dart';
import 'package:do_x/model/music_track.dart';
import 'package:do_x/model/music_video.dart';
import 'package:do_x/screen/music/music_fullscreen_video_player.dart';
import 'package:do_x/screen/music/music_screen.dart';
import 'package:do_x/screen/music/music_video_view.dart';
import 'package:do_x/services/music_playback_session.dart';
import 'package:do_x/view_model/music/music_view_model.dart';
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

/// Long enough for the video's run between the player and full screen.
const _run = Duration(milliseconds: 400);

void main() {
  testWidgets('the video opens full screen again after leaving it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    VideoPlayerPlatform.instance = FakeVideoPlayerPlatform(
      playing: {'https://cdn/a', 'https://yt/muxed'},
    );
    final vm = MusicViewModel(
      resolveStream: (_) async => 'https://cdn/a',
      playback: _SilentPlayback(),
      findVideo: (_) async => const MusicVideo(
        videoId: 'v',
        duration: Duration(minutes: 5),
        useAudio: false,
        muxedUrl: 'https://yt/muxed',
      ),
      findHdVideo: (_) async => null,
      videoEnabled: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ChangeNotifierProvider.value(
          value: vm,
          child: const MusicScreen(),
        ),
      ),
    );
    await tester.runAsync(() async {
      await vm.playTrack(
        const MusicTrack(
          id: 'a',
          title: 'Track a',
          artist: 'Artist',
          artworkUrl: '',
          streamUrl: 't',
          duration: Duration(minutes: 3),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();

    for (var round = 1; round <= 3; round++) {
      expect(
        find.byType(MusicVideoThumbnail),
        findsOneWidget,
        reason: 'round $round',
      );
      await tester.tap(find.byType(MusicVideoThumbnail));
      await tester.pump();
      await tester.pump(_run);
      expect(
        find.byType(MusicFullscreenVideoPlayer),
        findsOneWidget,
        reason: 'round $round: tap opens full screen',
      );

      await tester.tap(find.byIcon(Icons.fullscreen_exit_rounded));
      await tester.pump();
      await tester.pump(_run);
      expect(
        find.byType(MusicFullscreenVideoPlayer),
        findsNothing,
        reason: 'round $round: exit closes it',
      );
    }

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 6));
    vm.dispose();
  });

  testWidgets('the video opens full screen again after leaving it, sideways', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(2532, 1170);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    VideoPlayerPlatform.instance = FakeVideoPlayerPlatform(
      playing: {'https://cdn/a', 'https://yt/muxed'},
    );
    final vm = MusicViewModel(
      resolveStream: (_) async => 'https://cdn/a',
      playback: _SilentPlayback(),
      findVideo: (_) async => const MusicVideo(
        videoId: 'v',
        duration: Duration(minutes: 5),
        useAudio: false,
        muxedUrl: 'https://yt/muxed',
      ),
      findHdVideo: (_) async => null,
      videoEnabled: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ChangeNotifierProvider.value(
          value: vm,
          child: const MusicScreen(),
        ),
      ),
    );
    await tester.runAsync(() async {
      await vm.playTrack(
        const MusicTrack(
          id: 'a',
          title: 'Track a',
          artist: 'Artist',
          artworkUrl: '',
          streamUrl: 't',
          duration: Duration(minutes: 3),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();

    // Sideways, the video takes the screen by itself; leave it first.
    expect(find.byType(MusicFullscreenVideoPlayer), findsOneWidget);
    await tester.tap(find.byIcon(Icons.fullscreen_exit_rounded));
    await tester.pump();
    await tester.pump(_run);

    for (var round = 1; round <= 3; round++) {
      expect(
        find.byType(MusicVideoThumbnail),
        findsOneWidget,
        reason: 'round $round',
      );
      await tester.tap(find.byType(MusicVideoThumbnail));
      await tester.pump();
      await tester.pump(_run);
      expect(
        find.byType(MusicFullscreenVideoPlayer),
        findsOneWidget,
        reason: 'round $round: tap opens full screen',
      );

      await tester.tap(find.byIcon(Icons.fullscreen_exit_rounded));
      await tester.pump();
      await tester.pump(_run);
      expect(
        find.byType(MusicFullscreenVideoPlayer),
        findsNothing,
        reason: 'round $round: exit closes it',
      );
    }

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 6));
    vm.dispose();
  });

  testWidgets('a drag takes the video up to full screen and back down', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    VideoPlayerPlatform.instance = FakeVideoPlayerPlatform(
      playing: {'https://cdn/a', 'https://yt/muxed'},
    );
    final vm = MusicViewModel(
      resolveStream: (_) async => 'https://cdn/a',
      playback: _SilentPlayback(),
      findVideo: (_) async => const MusicVideo(
        videoId: 'v',
        duration: Duration(minutes: 5),
        useAudio: false,
        muxedUrl: 'https://yt/muxed',
      ),
      findHdVideo: (_) async => null,
      videoEnabled: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ChangeNotifierProvider.value(
          value: vm,
          child: const MusicScreen(),
        ),
      ),
    );
    await tester.runAsync(() async {
      await vm.playTrack(
        const MusicTrack(
          id: 'a',
          title: 'Track a',
          artist: 'Artist',
          artworkUrl: '',
          streamUrl: 't',
          duration: Duration(minutes: 3),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
    final thumbnail = find.byType(MusicVideoThumbnail);
    expect(thumbnail, findsOneWidget);

    // Part of the way up, the picture follows the finger.
    final gesture = await tester.startGesture(tester.getCenter(thumbnail));
    await gesture.moveBy(const Offset(0, -40));
    await gesture.moveBy(const Offset(0, -100));
    await tester.pump();
    expect(find.byType(MusicVideoFill), findsNWidgets(1));
    expect(find.byType(MusicFullscreenVideoPlayer), findsNothing);
    // Let go slowly, well short of halfway: back into the player.
    await tester.pump(const Duration(seconds: 1));
    await gesture.up();
    await tester.pump();
    await tester.pump(_run);
    expect(find.byType(MusicFullscreenVideoPlayer), findsNothing);

    // A flick up opens it however short.
    await tester.fling(thumbnail, const Offset(0, -120), 1500);
    await tester.pump();
    await tester.pump(_run);
    expect(find.byType(MusicFullscreenVideoPlayer), findsOneWidget);

    // And a flick down on the full screen takes it back.
    await tester.fling(
      find.byType(MusicFullscreenVideoPlayer),
      const Offset(0, 300),
      1500,
    );
    await tester.pump();
    await tester.pump(_run);
    expect(find.byType(MusicFullscreenVideoPlayer), findsNothing);
    expect(thumbnail, findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 6));
    vm.dispose();
  });

  testWidgets('full screen holds through a skip while the next picture opens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final gate = Completer<void>();
    VideoPlayerPlatform.instance = FakeVideoPlayerPlatform(
      playing: {'https://cdn/a', 'https://yt/a', 'https://yt/b'},
      held: {'https://yt/b': gate},
    );
    final vm = MusicViewModel(
      resolveStream: (_) async => 'https://cdn/a',
      playback: _SilentPlayback(),
      findVideo: (track) async => MusicVideo(
        videoId: track.id,
        duration: const Duration(minutes: 5),
        useAudio: false,
        muxedUrl: 'https://yt/${track.id}',
      ),
      // Answers at once, the way a resting client does — before the picture
      // it follows has opened.
      findHdVideo: (_) async => null,
      videoEnabled: true,
    );
    MusicTrack track(String id) => MusicTrack(
      id: id,
      title: 'Track $id',
      artist: 'Artist',
      artworkUrl: '',
      streamUrl: 't$id',
      duration: const Duration(minutes: 3),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ChangeNotifierProvider.value(
          value: vm,
          child: const MusicScreen(),
        ),
      ),
    );
    await tester.runAsync(() async {
      await vm.playTrack(track('a'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
    await tester.tap(find.byType(MusicVideoThumbnail));
    await tester.pump();
    await tester.pump(_run);
    expect(find.byType(MusicFullscreenVideoPlayer), findsOneWidget);

    await tester.runAsync(() async {
      await vm.playTrack(track('b'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
    await tester.pump();
    expect(vm.isFindingVideo, isFalse, reason: 'the lookup has answered');
    expect(
      find.byType(MusicFullscreenVideoPlayer),
      findsOneWidget,
      reason: 'the picture is still opening',
    );

    await tester.runAsync(() async {
      gate.complete();
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
    expect(find.byType(MusicFullscreenVideoPlayer), findsOneWidget);
    expect(vm.videoController?.dataSource, 'https://yt/b');

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 6));
    vm.dispose();
  });
}
