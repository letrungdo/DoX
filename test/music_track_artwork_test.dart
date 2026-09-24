import 'package:do_x/model/music_track.dart';
import 'package:flutter_test/flutter_test.dart';

MusicTrack _track(String artworkUrl) => MusicTrack(
  id: '1',
  title: 'Track',
  artist: 'Artist',
  artworkUrl: artworkUrl,
  streamUrl: 'transcoding',
  duration: Duration.zero,
);

void main() {
  const url = 'https://i1.example.com/artworks-000-abc-large.jpg';

  test('a small square gets the smallest size that covers it', () {
    expect(_track(url).artworkUrlFor(90), url);
    expect(
      _track(url).artworkUrlFor(168),
      'https://i1.example.com/artworks-000-abc-t300x300.jpg',
    );
  });

  test('anything bigger than the largest size gets the largest', () {
    expect(
      _track(url).artworkUrlFor(720),
      'https://i1.example.com/artworks-000-abc-t500x500.jpg',
    );
    expect(
      _track(url).largeArtworkUrl,
      'https://i1.example.com/artworks-000-abc-t500x500.jpg',
    );
  });

  test('a link with no size in it is left as it is', () {
    const other = 'https://i1.example.com/artworks-000-abc-t500x500.jpg';
    expect(_track(other).artworkUrlFor(100), other);
    expect(_track('').artworkUrlFor(100), '');
  });
}
