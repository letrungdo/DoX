import 'package:dio/dio.dart';
import 'package:do_x/model/music_track.dart';
import 'package:do_x/model/music_video.dart';
import 'package:do_x/services/music_video_matcher.dart';
import 'package:do_x/services/youtube_js_solver.dart';
import 'package:do_x/utils/device_type.dart';
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
/// Two sets of streams are asked for at once:
///
/// - **HD** — the adaptive streams, picture and sound apart, up to 1080p. The
///   app's default client gets them too, but without a proof-of-origin token
///   YouTube serves only their first few hundred kilobytes and answers `403`
///   to every range after that, so a player stalls within seconds. The
///   clients that need no such token are asked instead — see [_hdStreams].
///   Every HD stream is also tried from the middle before it is handed over,
///   because a link that only opens is not yet one that plays.
/// - **Muxed** — picture and sound together at 360p, which plays to the end
///   with no challenge at all. It is what is left when HD is not.
class YoutubeMusicService {
  YoutubeMusicService({Dio? dio, YoutubeExplode? explode})
    : _dio = dio ?? Dio(_options),
      _explode = explode ?? YoutubeExplode();

  /// For trying a stream out: none of the search's headers, and any status
  /// is an answer rather than an error.
  final _probe = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
      responseType: ResponseType.bytes,
      validateStatus: (_) => true,
    ),
  );

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

  /// How long HD is waited for before the video carries on without it.
  static const _hdWait = Duration(seconds: 20);

  final Dio _dio;

  /// The default client, for the muxed stream.
  final YoutubeExplode _explode;

  /// The TV client with the challenge solver, for HD. Only made where a web
  /// view can run the solver, and only once HD is first asked for.
  YoutubeExplode? _hdExplode;
  YoutubeExplode? get _hd => WebViewJsSolver.isSupported
      ? _hdExplode ??= YoutubeExplode(jsSolver: WebViewJsSolver())
      : null;

  /// The pick made for each track, including "none", so a track played again
  /// is not searched for again. Only an answer is kept; a search that failed
  /// is tried afresh next time.
  final _picks = <String, MusicVideoPick?>{};

  /// The video for [track] with its 360p stream, or null when there is no
  /// video worth showing. Quick, so the picture can come up early; the HD
  /// streams follow from [withHd]. Never throws: a missing video leaves the
  /// track playing as it always has.
  Future<MusicVideo?> findVideo(MusicTrack track) async {
    try {
      final MusicVideoPick? pick;
      if (_picks.containsKey(track.id)) {
        pick = _picks[track.id];
      } else {
        var videos = await searchVideos(MusicVideoMatcher.searchQuery(track));
        // A title YouTube finds nothing for still has an artist who has
        // videos, and any of them is a picture to put up.
        if (videos.isEmpty && track.artist.trim().isNotEmpty) {
          videos = await searchVideos(track.artist.trim());
        }
        pick = MusicVideoMatcher.pick(track, videos);
        _picks[track.id] = pick;
      }
      if (pick == null) return null;

      final id = pick.video.id;
      final muxed = await _muxedStream(id).catchError((Object e) {
        logger.d('[MusicVideo] no muxed stream for $id: $e');
        return null;
      });
      return MusicVideo(
        videoId: id,
        duration: pick.video.duration,
        useAudio: pick.useAudio,
        loops: pick.loops,
        muxedUrl: muxed,
      );
    } on Object catch (e) {
      logger.d('[MusicVideo] no video for ${track.id}: $e');
      return null;
    }
  }

  /// [video] with its HD streams, or null when there are none that play.
  /// Bounded in time: the first one also fetches the solver and the player
  /// script. Never throws.
  Future<MusicVideo?> withHd(MusicVideo video) async {
    try {
      final hd = await _hdStreams(video.videoId).timeout(_hdWait);
      if (hd == null || (hd.video == null && hd.audio == null)) return null;
      return video.withHd(videoUrl: hd.video, audioUrl: hd.audio);
    } on Object catch (e) {
      logger.d('[MusicVideo] no HD streams for ${video.videoId}: $e');
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

  /// The largest picture a screen of this kind is given, in pixels: 1080p on
  /// a television, 720p on anything held in a hand. Counted in pixels rather
  /// than lines so a letterboxed video (1920×804) lands in the right tier.
  static int get _maxPixels => deviceType.isTv ? 1920 * 1080 : 1280 * 720;

  /// [videoId]'s HD picture and sound, each only if it plays from the middle.
  ///
  /// Asked of the clients that hand adaptive streams over without a
  /// proof-of-origin token, one after the other until one of them plays:
  ///
  /// - `ANDROID_VR`, which needs nothing else — no watch page, no challenge.
  /// - `TV`, whose links carry signature and `n` challenges for
  ///   [WebViewJsSolver] to solve, and which needs the watch page for the
  ///   player script those challenges are written in.
  ///
  /// H.264 only: every phone and television decodes it in hardware, which
  /// is not yet true of AV1, and VP9 comes in WebM, which iOS will not open.
  Future<({String? video, String? audio})?> _hdStreams(String videoId) async {
    final attempts = <(String, YoutubeExplode?, YoutubeApiClient, bool)>[
      ('ANDROID_VR', _explode, YoutubeApiClient.androidVr, false),
      ('TV', _hd, YoutubeApiClient.tv, true),
    ];
    for (final (name, explode, client, watchPage) in attempts) {
      if (explode == null) {
        logger.d('[MusicVideo] HD $name skipped: no web view for its solver');
        continue;
      }
      try {
        final manifest = await explode.videos.streams.getManifest(
          videoId,
          ytClients: [client],
          requireWatchPage: watchPage,
        );
        final found = await _playableHd(manifest);
        if (found.video != null) {
          logger.d('[MusicVideo] HD $name plays for $videoId');
          return found;
        }
        logger.d('[MusicVideo] HD $name streams refused mid-file ($videoId)');
      } on Object catch (e) {
        logger.d('[MusicVideo] HD $name failed for $videoId: $e');
      }
    }
    return null;
  }

  /// The best H.264 picture and mp4 sound in [manifest] that play through.
  Future<({String? video, String? audio})> _playableHd(
    StreamManifest manifest,
  ) async {
    final pictures =
        manifest.videoOnly
            .where(
              (s) =>
                  s.container == StreamContainer.mp4 &&
                  s.videoCodec.startsWith('avc1') &&
                  _pixels(s) <= _maxPixels,
            )
            .toList()
          ..sort((a, b) => _pixels(b).compareTo(_pixels(a)));
    final sounds =
        manifest.audioOnly
            .where((s) => s.container == StreamContainer.mp4)
            .toList()
          ..sort((a, b) => b.bitrate.compareTo(a.bitrate));

    final video = pictures.isEmpty ? null : pictures.first;
    final audio = sounds.isEmpty ? null : sounds.first;
    final (videoPlays, audioPlays) = await (
      video == null ? Future.value(false) : _playsThrough(video),
      audio == null ? Future.value(false) : _playsThrough(audio),
    ).wait;
    return (
      video: videoPlays ? video!.url.toString() : null,
      audio: audioPlays ? audio!.url.toString() : null,
    );
  }

  static int _pixels(VideoOnlyStreamInfo s) =>
      s.videoResolution.width * s.videoResolution.height;

  /// Whether [stream] answers a range from its middle — the request a stream
  /// that would stall after its first few hundred kilobytes turns down.
  Future<bool> _playsThrough(StreamInfo stream) async {
    final middle = stream.size.totalBytes ~/ 2;
    final response = await _probe.getUri<List<int>>(
      stream.url,
      options: Options(headers: {'Range': 'bytes=$middle-${middle + 1023}'}),
    );
    return response.statusCode == 206;
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
