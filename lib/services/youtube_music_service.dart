import 'package:dio/dio.dart';
import 'package:do_x/model/music_track.dart';
import 'package:do_x/model/music_video.dart';
import 'package:do_x/services/music_video_matcher.dart';
import 'package:do_x/utils/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// Finds the YouTube video that goes with a Music track, and a stream of it
/// the player can open.
///
/// The search is YouTube Music's own (the InnerTube API its web player calls,
/// as SimpMusic does) rather than YouTube's: only YouTube Music says which
/// results are the artist's official video, and that is what decides whether
/// the video's sound can stand in for the track's.
///
/// The stream is the muxed one. The adaptive streams go up to 1080p, but
/// without a proof-of-origin token YouTube serves only their first few
/// hundred kilobytes and answers `403` to every range after that — a player
/// fetches a video in ranges, so it stalls within seconds. The muxed stream
/// stops at 360p and plays to the end.
class YoutubeMusicService {
  YoutubeMusicService({Dio? dio, YoutubeExplode? explode})
    : _dio = dio ?? Dio(_options),
      _explode = explode ?? YoutubeExplode();

  static final _options = BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {
      'Content-Type': 'application/json',
      'Origin': 'https://music.youtube.com',
      'Referer': 'https://music.youtube.com/',
      'User-Agent':
          'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    },
  );

  static const _searchUrl =
      'https://music.youtube.com/youtubei/v1/search?prettyPrint=false';

  /// The web player YouTube Music answers the search for.
  static const _client = {
    'clientName': 'WEB_REMIX',
    'clientVersion': '1.20250310.01.00',
    'hl': 'en',
    'gl': 'VN',
  };

  /// The search's "Videos" filter. Songs are left out: a song result is the
  /// label's audio over a still cover, which is no picture at all.
  static const _videosFilter = 'EgWKAQIQAWoKEAkQBRAKEAMQBA==';

  final Dio _dio;
  final YoutubeExplode _explode;

  /// The pick made for each track, including "none", so a track played again
  /// is not searched for again. Only an answer is kept; a search that failed
  /// is tried afresh next time.
  final _picks = <String, MusicVideoPick?>{};

  /// The video for [track], or null when there is none worth showing or it
  /// could not be reached. Never throws: a missing video leaves the track
  /// playing as it always has.
  Future<MusicVideo?> findVideo(MusicTrack track) async {
    try {
      final MusicVideoPick? pick;
      if (_picks.containsKey(track.id)) {
        pick = _picks[track.id];
      } else {
        final videos = await searchVideos(MusicVideoMatcher.searchQuery(track));
        pick = MusicVideoMatcher.pick(track, videos);
        _picks[track.id] = pick;
      }
      if (pick == null) return null;

      final streamUrl = await _muxedStream(pick.video.id);
      if (streamUrl == null) return null;
      return MusicVideo(
        videoId: pick.video.id,
        streamUrl: streamUrl,
        duration: pick.video.duration,
        carriesAudio: pick.useAudio,
      );
    } on Object catch (e) {
      logger.d('YoutubeMusicService no video for ${track.id}: $e');
      return null;
    }
  }

  Future<List<YoutubeVideo>> searchVideos(String query) async {
    final response = await _dio.post<Map<String, dynamic>>(
      _searchUrl,
      data: {
        'context': {'client': _client},
        'query': query,
        'params': _videosFilter,
      },
    );
    final data = response.data;
    return data == null ? const [] : parseSearch(data);
  }

  /// The videos in a search answer, in the order YouTube ranked them.
  @visibleForTesting
  static List<YoutubeVideo> parseSearch(Map<String, dynamic> json) {
    final videos = <YoutubeVideo>[];
    final tabs = json['contents']?['tabbedSearchResultsRenderer']?['tabs'];
    if (tabs is! List || tabs.isEmpty) return videos;
    final sections = tabs
        .first['tabRenderer']?['content']?['sectionListRenderer']?['contents'];
    if (sections is! List) return videos;

    for (final section in sections) {
      final items = section['musicShelfRenderer']?['contents'];
      if (items is! List) continue;
      for (final item in items) {
        final video = _parseItem(item['musicResponsiveListItemRenderer']);
        if (video != null) videos.add(video);
      }
    }
    return videos;
  }

  static YoutubeVideo? _parseItem(dynamic renderer) {
    if (renderer is! Map) return null;
    final columns = renderer['flexColumns'];
    if (columns is! List || columns.length < 2) return null;

    List<String> runs(dynamic column) {
      final list =
          column['musicResponsiveListItemFlexColumnRenderer']?['text']?['runs'];
      if (list is! List) return const [];
      return [for (final run in list) run['text']?.toString() ?? ''];
    }

    final watch =
        renderer['overlay']?['musicItemThumbnailOverlayRenderer']?['content']?['musicPlayButtonRenderer']?['playNavigationEndpoint']?['watchEndpoint'];
    final id =
        (watch?['videoId'] ?? renderer['playlistItemData']?['videoId'])
            ?.toString() ??
        '';
    if (id.isEmpty) return null;
    final type =
        watch?['watchEndpointMusicSupportedConfigs']?['watchEndpointMusicConfig']?['musicVideoType'];

    // "Artist • 1.2M views • 4:37": the channel first, the length last.
    final details = runs(columns[1]);
    final length = details.reversed
        .map(_parseLength)
        .firstWhere((d) => d != null, orElse: () => null);

    return YoutubeVideo(
      id: id,
      title: runs(columns[0]).join(),
      author: details.isEmpty ? '' : details.first,
      duration: length ?? Duration.zero,
      isOfficial: type == 'MUSIC_VIDEO_TYPE_OMV',
    );
  }

  static final _lengthPattern = RegExp(r'^(?:(\d+):)?(\d{1,2}):(\d{2})$');

  static Duration? _parseLength(String text) {
    final match = _lengthPattern.firstMatch(text.trim());
    if (match == null) return null;
    return Duration(
      hours: int.parse(match.group(1) ?? '0'),
      minutes: int.parse(match.group(2)!),
      seconds: int.parse(match.group(3)!),
    );
  }

  /// A link to [videoId]'s muxed mp4 — see the class notes for why that one.
  ///
  /// The watch page is skipped: the player API answers without it, and it is
  /// the one request YouTube is quickest to turn into a "prove you are not a
  /// bot" page.
  Future<String?> _muxedStream(String videoId) async {
    final manifest = await _explode.videos.streams.getManifest(
      videoId,
      requireWatchPage: false,
    );
    final muxed = manifest.muxed
        .where((s) => s.container == StreamContainer.mp4)
        .toList();
    if (muxed.isEmpty) return null;
    return muxed.bestQuality.url.toString();
  }
}

final youtubeMusicService = YoutubeMusicService();
