import 'package:do_x/model/music_track.dart';
import 'package:do_x/services/music_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a like asks for an account before it asks the network', () async {
    // Nobody is signed in, so the call must stop here: a like is addressed to
    // the account's own likes collection, and without one there is no URL to
    // send it to.
    const track = MusicTrack(
      id: '1',
      title: 'Track',
      artist: 'Artist',
      artworkUrl: '',
      streamUrl: 'https://example.com/stream',
      duration: Duration(minutes: 3),
    );

    expect(
      () => MusicService().toggleLikeTrack(track),
      throwsA(isA<MusicSignInRequired>()),
    );
  });
}
