import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:do_x/model/music_track.dart';
import 'package:do_x/utils/logger.dart';
import 'package:flutter/foundation.dart';

/// What the system's media controls can ask the music player to do — the
/// lock screen, the notification, a headset's buttons.
abstract interface class MusicPlaybackControls {
  void resume();
  void pause();
  void nextTrack();
  void previousTrack();
  void seekTo(Duration position);
  void stopPlayback();
}

/// Keeps the Music page playing once the app has left the screen.
///
/// Leaving the player to itself is not enough for that: Android freezes an
/// app in the background after a while unless a foreground service says it is
/// busy playing, and iOS only lets audio carry on for an app that has told the
/// system what it is playing. `audio_service` provides both, along with the
/// lock-screen and notification controls that come with it, which is why the
/// player reports every change of track and state here.
///
/// Started on the first track rather than at launch: most sessions never open
/// the Music page, and they should not pay for a media service they do not use.
class MusicPlaybackSession {
  Future<_MusicAudioHandler?>? _handler;
  MusicPlaybackControls? _controls;

  /// Makes [controls] the player the system's buttons drive. [channelName] is
  /// the translated name Android lists the notification under.
  void attach(MusicPlaybackControls controls, {required String channelName}) {
    _controls = controls;
    _handler ??= _init(channelName);
  }

  /// Lets go of [controls], and clears the notification with it — the page
  /// that owned the music is gone, and so is the music.
  void detach(MusicPlaybackControls controls) {
    if (_controls != controls) return;
    _controls = null;
    unawaited(_withHandler((handler) => handler.clear()));
  }

  void updateTrack(MusicTrack track, Duration duration) {
    unawaited(
      _withHandler(
        (handler) => handler.mediaItem.add(
          MediaItem(
            id: track.id,
            title: track.title,
            artist: track.artist,
            duration: duration > Duration.zero ? duration : null,
            artUri: track.artworkUrl.isEmpty
                ? null
                : Uri.tryParse(track.largeArtworkUrl),
          ),
        ),
      ),
    );
  }

  void updateState({
    required bool playing,
    required Duration position,
    bool loading = false,
  }) {
    unawaited(
      _withHandler(
        (handler) => handler.playbackState.add(
          handler.playbackState.value.copyWith(
            controls: [
              MediaControl.skipToPrevious,
              playing ? MediaControl.pause : MediaControl.play,
              MediaControl.skipToNext,
            ],
            systemActions: const {MediaAction.seek},
            androidCompactActionIndices: const [0, 1, 2],
            processingState: loading
                ? AudioProcessingState.loading
                : AudioProcessingState.ready,
            playing: playing,
            updatePosition: position,
            speed: 1,
          ),
        ),
      ),
    );
  }

  Future<void> _withHandler(
    FutureOr<void> Function(_MusicAudioHandler handler) action,
  ) async {
    final handler = await _handler;
    if (handler != null) await action(handler);
  }

  Future<_MusicAudioHandler?> _init(String channelName) async {
    // The web has no background to keep playing in.
    if (kIsWeb) return null;
    try {
      return await AudioService.init(
        builder: () => _MusicAudioHandler(() => _controls),
        config: AudioServiceConfig(
          androidNotificationChannelId: 'vn.dox.app.music',
          androidNotificationChannelName: channelName,
          androidNotificationIcon: 'drawable/ic_stat_notification',
        ),
      );
    } on Object catch (e, st) {
      // Without it the music still plays while the app is open; it only
      // stops with the screen, as it did before.
      logger.e(
        'Music background playback unavailable',
        error: e,
        stackTrace: st,
      );
      return null;
    }
  }
}

class _MusicAudioHandler extends BaseAudioHandler with SeekHandler {
  _MusicAudioHandler(this._controls);

  final MusicPlaybackControls? Function() _controls;

  @override
  Future<void> play() async => _controls()?.resume();

  @override
  Future<void> pause() async => _controls()?.pause();

  @override
  Future<void> skipToNext() async => _controls()?.nextTrack();

  @override
  Future<void> skipToPrevious() async => _controls()?.previousTrack();

  @override
  Future<void> seek(Duration position) async => _controls()?.seekTo(position);

  @override
  Future<void> stop() async {
    _controls()?.stopPlayback();
    await clear();
  }

  /// Takes the notification and the lock-screen entry down.
  Future<void> clear() async {
    playbackState.add(
      playbackState.value.copyWith(
        controls: const [],
        processingState: AudioProcessingState.idle,
        playing: false,
      ),
    );
    mediaItem.add(null);
  }
}

final musicPlayback = MusicPlaybackSession();
