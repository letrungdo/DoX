import 'dart:async';

import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/model/music_track.dart';
import 'package:do_x/model/music_video.dart';
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
      findVideo: (_) async => null,
      findHdVideo: (_) async => null,
      videoEnabled: true,
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

  group('with a YouTube video', () {
    MusicViewModel withVideo(
      MusicVideo? video, {
      bool enabled = true,
      MusicVideo? hd,
    }) => MusicViewModel(
      resolveStream: (url) async => 'https://cdn/a',
      playback: _SilentPlayback(),
      findVideo: (_) async => video,
      findHdVideo: (_) async => hd,
      videoEnabled: enabled,
    );

    Future<void> play(WidgetTester tester, MusicViewModel model) async {
      vm = model;
      await pumpHost(tester);
      await tester.runAsync(() async {
        await vm.playTrack(_track('a'));
        // The muted picture is attached after the sound has started.
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
    }

    setUp(() {
      platform = FakeVideoPlayerPlatform(
        playing: {
          'https://cdn/a',
          'https://yt/muxed',
          'https://yt/hd-audio',
          'https://yt/hd-video',
        },
      );
      VideoPlayerPlatform.instance = platform;
    });

    testWidgets('an official video in HD plays its own sound under its '
        'picture', (tester) async {
      await play(
        tester,
        withVideo(
          const MusicVideo(
            videoId: 'omv',
            duration: Duration(minutes: 3),
            useAudio: true,
            hdAudioUrl: 'https://yt/hd-audio',
            hdVideoUrl: 'https://yt/hd-video',
            muxedUrl: 'https://yt/muxed',
          ),
        ),
      );

      expect(platform.opened, ['https://yt/hd-audio', 'https://yt/hd-video']);
      expect(vm.isAudioFromVideo, isTrue);
      expect(vm.videoController, isNot(same(vm.audioController)));
      expect(vm.videoController!.value.volume, 0);
      vm.dispose();
    });

    testWidgets('an official video with only the muxed stream is played '
        'as one', (tester) async {
      await play(
        tester,
        withVideo(
          const MusicVideo(
            videoId: 'omv',
            duration: Duration(minutes: 3),
            useAudio: true,
            muxedUrl: 'https://yt/muxed',
          ),
        ),
      );

      expect(platform.opened, ['https://yt/muxed']);
      expect(vm.isAudioFromVideo, isTrue);
      expect(vm.videoController, same(vm.audioController));
      vm.dispose();
    });

    testWidgets('an official video that will not open falls back to the '
        'track', (tester) async {
      await play(
        tester,
        withVideo(
          const MusicVideo(
            videoId: 'omv',
            duration: Duration(minutes: 3),
            useAudio: true,
            muxedUrl: 'https://yt/dead',
          ),
        ),
      );

      expect(platform.opened.take(2), ['https://yt/dead', 'https://cdn/a']);
      expect(vm.isAudioFromVideo, isFalse);
      expect(vm.isPlaying, isTrue);
      vm.dispose();
    });

    testWidgets('any other video is laid, muted, over the track — the '
        '360p one when HD will not open', (tester) async {
      await play(
        tester,
        withVideo(
          const MusicVideo(
            videoId: 'ugc',
            duration: Duration(minutes: 5),
            useAudio: false,
            hdVideoUrl: 'https://yt/dead',
            muxedUrl: 'https://yt/muxed',
          ),
        ),
      );

      expect(platform.opened, [
        'https://cdn/a',
        'https://yt/dead',
        'https://yt/muxed',
      ]);
      expect(vm.isAudioFromVideo, isFalse);
      final video = vm.videoController;
      expect(video, isNotNull);
      expect(video, isNot(same(vm.audioController)));
      expect(video!.value.volume, 0);
      vm.dispose();
    });

    testWidgets('the 360p picture goes up first and HD replaces it', (
      tester,
    ) async {
      const basic = MusicVideo(
        videoId: 'ugc',
        duration: Duration(minutes: 5),
        useAudio: false,
        muxedUrl: 'https://yt/muxed',
      );
      await play(
        tester,
        withVideo(basic, hd: basic.withHd(videoUrl: 'https://yt/hd-video')),
      );

      expect(platform.opened, [
        'https://cdn/a',
        'https://yt/muxed',
        'https://yt/hd-video',
      ]);
      expect(vm.videoController?.dataSource, 'https://yt/hd-video');
      expect(vm.videoController!.value.volume, 0);
      vm.dispose();
    });

    testWidgets('a video shorter than the track is not shown', (tester) async {
      await play(
        tester,
        withVideo(
          const MusicVideo(
            videoId: 'ugc',
            duration: Duration(minutes: 2, seconds: 30),
            useAudio: false,
            muxedUrl: 'https://yt/muxed',
          ),
        ),
      );

      expect(platform.opened, ['https://cdn/a']);
      expect(vm.videoController, isNull);
      vm.dispose();
    });

    testWidgets('a stand-in video is looped rather than kept in step', (
      tester,
    ) async {
      await play(
        tester,
        withVideo(
          const MusicVideo(
            videoId: 'other',
            duration: Duration(minutes: 1),
            useAudio: false,
            loops: true,
            muxedUrl: 'https://yt/muxed',
          ),
        ),
      );

      final video = vm.videoController;
      expect(video?.dataSource, 'https://yt/muxed');
      expect(video!.value.isLooping, isTrue);
      expect(video.value.volume, 0);
      vm.dispose();
    });

    testWidgets('with the video turned off it is still found, but not '
        'played', (tester) async {
      await play(
        tester,
        withVideo(
          const MusicVideo(
            videoId: 'omv',
            duration: Duration(minutes: 3),
            useAudio: true,
            muxedUrl: 'https://yt/muxed',
          ),
          enabled: false,
        ),
      );

      expect(platform.opened, ['https://cdn/a']);
      expect(vm.hasVideo, isTrue);
      expect(vm.videoController, isNull);
      vm.dispose();
    });

    testWidgets('a track without a video offers no video switch', (
      tester,
    ) async {
      await play(tester, withVideo(null));

      expect(vm.hasVideo, isFalse);
      expect(vm.isFindingVideo, isFalse);
      vm.dispose();
    });
  });
}
