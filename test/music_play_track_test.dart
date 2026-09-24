import 'dart:async';

import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/model/music_shelf.dart';
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

  testWidgets('a refresh of Discover while a track plays keeps next and '
      'previous on the list it was picked from', (tester) async {
    final a = [_track('a'), _track('a2'), _track('a3')];
    final b = [_track('b'), _track('b2')];
    var fetches = 0;
    vm = MusicViewModel(
      resolveStream: (url) async => 'https://cdn/a',
      playback: _SilentPlayback(),
      findVideo: (_) async => null,
      findHdVideo: (_) async => null,
      discoverShelves: () async => [
        MusicShelf(title: 'Shelf', tracks: fetches++ == 0 ? a : b),
      ],
      videoEnabled: true,
    );
    await pumpHost(tester);
    await tester.runAsync(() async {
      await vm.loadHomeData();
      await vm.playFromList(a[1]);
      // The tab switched back to: the rows on screen are new ones.
      await vm.loadHomeData();
      expect(vm.discoverTracks.map((t) => t.id), ['b', 'b2']);

      vm.nextTrack();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(vm.currentTrack?.id, 'a3');

      vm.previousTrack();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(vm.currentTrack?.id, 'a2');
    });
    vm.dispose();
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

    testWidgets('a muted picture pauses while the page is out of sight, '
        'and the sound plays on', (tester) async {
      await play(
        tester,
        withVideo(
          // A looped stand-in: the fake player reports no length, and any
          // other picture would count as run out and stay paused anyway.
          const MusicVideo(
            videoId: 'other',
            duration: Duration(minutes: 1),
            useAudio: false,
            loops: true,
            muxedUrl: 'https://yt/muxed',
          ),
        ),
      );
      final video = vm.videoController!;
      final sound = vm.audioController!;
      expect(video.value.isPlaying, isTrue);

      vm.setPageVisible(false);
      expect(video.value.isPlaying, isFalse);
      expect(sound.value.isPlaying, isTrue);

      await tester.runAsync(() async {
        vm.setPageVisible(true);
        // A play from the start seeks there first.
        await Future<void>.delayed(Duration.zero);
      });
      expect(video.value.isPlaying, isTrue);
      vm.dispose();
    });

    testWidgets('an HD picture found in time goes up without the 360p one', (
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

      expect(platform.opened, ['https://cdn/a', 'https://yt/hd-video']);
      expect(vm.videoController?.dataSource, 'https://yt/hd-video');
      expect(vm.videoController!.value.volume, 0);
      vm.dispose();
    });

    testWidgets('an HD picture that is slow to come replaces the 360p one', (
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
        MusicViewModel(
          resolveStream: (url) async => 'https://cdn/a',
          playback: _SilentPlayback(),
          findVideo: (_) async => basic,
          findHdVideo: (_) async {
            await Future<void>.delayed(const Duration(milliseconds: 30));
            return basic.withHd(videoUrl: 'https://yt/hd-video');
          },
          videoEnabled: true,
          hdPictureGrace: const Duration(milliseconds: 10),
        ),
      );

      expect(platform.opened, [
        'https://cdn/a',
        'https://yt/muxed',
        'https://yt/hd-video',
      ]);
      expect(vm.videoController?.dataSource, 'https://yt/hd-video');
      vm.dispose();
    });

    testWidgets('a video found with no stream yet shows the 360p one the '
        'lookup falls back to', (tester) async {
      const found = MusicVideo(
        videoId: 'ugc',
        duration: Duration(minutes: 5),
        useAudio: false,
      );
      await play(
        tester,
        withVideo(found, hd: found.withHd(muxedUrl: 'https://yt/muxed')),
      );

      expect(platform.opened, ['https://cdn/a', 'https://yt/muxed']);
      expect(vm.videoController?.dataSource, 'https://yt/muxed');
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

    testWidgets('an HD picture the player refuses with the client headers '
        'is tried without them', (tester) async {
      platform = FakeVideoPlayerPlatform(
        playing: {'https://cdn/a', 'https://yt/muxed', 'https://yt/hd-video'},
        refusedWithHeaders: {'https://yt/hd-video'},
      );
      VideoPlayerPlatform.instance = platform;
      const basic = MusicVideo(
        videoId: 'ugc',
        duration: Duration(minutes: 5),
        useAudio: false,
        muxedUrl: 'https://yt/muxed',
      );
      await play(
        tester,
        withVideo(
          basic,
          hd: basic.withHd(
            videoUrl: 'https://yt/hd-video',
            headers: const {'User-Agent': 'vr'},
          ),
        ),
      );

      expect(vm.videoController?.dataSource, 'https://yt/hd-video');
      vm.dispose();
    });

    testWidgets('on Android the muted picture leaves the audio focus to the '
        'sound', (tester) async {
      await play(
        tester,
        withVideo(
          const MusicVideo(
            videoId: 'ugc',
            duration: Duration(minutes: 5),
            useAudio: false,
            muxedUrl: 'https://yt/muxed',
          ),
        ),
      );

      // Tests run as Android.
      expect(platform.mixedWithOthers['https://cdn/a'], isFalse);
      expect(platform.mixedWithOthers['https://yt/muxed'], isTrue);
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
