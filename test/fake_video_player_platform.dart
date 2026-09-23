import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

/// A stand-in for the platform player, which a test has none of.
///
/// Two things it lets a test say that a real player cannot be asked for:
/// which streams come up and which do not, and which stream the page reached
/// for next when one of them did not.
class FakeVideoPlayerPlatform extends VideoPlayerPlatform {
  FakeVideoPlayerPlatform({this.playing = const {}, this.stalls = false});

  /// The streams that come up. Anything else fails the way a dead link does.
  final Set<String> playing;

  /// Every stream opens but none of them ever reports itself ready — the
  /// channel that is still trying, which is where a page waiting on a live
  /// stream spends its first seconds.
  final bool stalls;

  /// Every stream the page has asked for, in the order it asked.
  final opened = <String>[];

  /// The players currently making sound: played, and neither paused nor
  /// disposed since.
  final sounding = <int>{};

  final _events = <int, StreamController<VideoEvent>>{};
  int _nextId = 0;

  @override
  Future<void> init() async {}

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    final uri = options.dataSource.uri ?? '';
    opened.add(uri);
    if (!stalls && !playing.contains(uri)) {
      throw PlatformException(code: 'VideoError', message: 'dead stream');
    }

    final playerId = _nextId++;
    final events = StreamController<VideoEvent>();
    _events[playerId] = events;
    if (!stalls) {
      events.add(
        VideoEvent(
          eventType: VideoEventType.initialized,
          // Zero, the way a live stream with no end reports itself.
          duration: Duration.zero,
          size: const Size(1920, 1080),
        ),
      );
    }
    return playerId;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) =>
      _events[playerId]?.stream ?? const Stream.empty();

  @override
  Future<void> dispose(int playerId) async {
    sounding.remove(playerId);
    await _events.remove(playerId)?.close();
  }

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> play(int playerId) async => sounding.add(playerId);

  @override
  Future<void> pause(int playerId) async => sounding.remove(playerId);

  @override
  Future<void> setVolume(int playerId, double volume) async {}

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<void> seekTo(int playerId, Duration position) async {}

  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;

  @override
  Widget buildViewWithOptions(VideoViewOptions options) =>
      const SizedBox.expand();
}
