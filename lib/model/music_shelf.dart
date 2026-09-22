import 'package:do_x/model/music_track.dart';

/// One row of the Discover tab, titled by the service rather than by us: the
/// shelves it sends back differ per account and change over time, so the page
/// shows what arrives instead of asking for two fixed lists.
class MusicShelf {
  const MusicShelf({required this.title, required this.tracks});

  final String title;
  final List<MusicTrack> tracks;
}
