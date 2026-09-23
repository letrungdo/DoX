import 'dart:async';

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

  /// The `ANDROID_VR` client at the version yt-dlp asks as. The package's own
  /// is older, and an old app version is one more reason for YouTube to turn
  /// a request away.
  static const _vrUserAgent =
      'com.google.android.apps.youtube.vr.oculus/1.65.10 '
      '(Linux; U; Android 12L; eureka-user Build/SQ3A.220605.009.A1) gzip';
  static const _androidVr = YoutubeApiClient({
    'context': {
      'client': {
        'clientName': 'ANDROID_VR',
        'clientVersion': '1.65.10',
        'deviceMake': 'Oculus',
        'deviceModel': 'Quest 3',
        'androidSdkVersion': 32,
        'userAgent': _vrUserAgent,
        'osName': 'Android',
        'osVersion': '12L',
        'hl': 'en',
        'timeZone': 'UTC',
        'utcOffsetMinutes': 0,
      },
    },
    'contentCheckOk': true,
    'racyCheckOk': true,
  }, 'https://www.youtube.com/youtubei/v1/player?prettyPrint=false');

  /// How long a client YouTube has put its bot check in front of is left
  /// alone. Asking again straight away only costs every track the wait for
  /// the refusal, and a network that keeps asking is one it keeps flagging.
  static const _botCheckRest = Duration(minutes: 15);

  /// The clients resting after a bot check, and what YouTube said.
  final _blocked = <String, ({DateTime until, String reason})>{};

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

  /// [video] with its HD streams added — or without them, but with the
  /// reason in [MusicVideo.hdReport], so the page can say why the picture
  /// is 360p. Bounded in time: the first one also fetches the solver and the
  /// player script. Never throws.
  Future<MusicVideo> withHd(MusicVideo video) async {
    try {
      final hd = await _hdStreams(video.videoId).timeout(_hdWait);
      return video.withHd(
        videoUrl: hd.video,
        audioUrl: hd.audio,
        headers: hd.headers,
        report: hd.report,
      );
    } on TimeoutException {
      return video.withHd(report: 'HD: timed out after ${_hdWait.inSeconds}s');
    } on Object catch (e) {
      return video.withHd(report: 'HD: $e');
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
  Future<_HdStreams> _hdStreams(String videoId) async {
    final attempts = <(String, YoutubeExplode?, YoutubeApiClient, bool)>[
      ('ANDROID_VR', _explode, _androidVr, false),
      ('TV', _hd, YoutubeApiClient.tv, true),
    ];
    final report = <String>[];
    void note(String line) {
      report.add(line);
      logger.d('[MusicVideo] $videoId $line');
    }

    for (final (name, explode, client, watchPage) in attempts) {
      if (explode == null) {
        note('$name: skipped, no web view for its solver');
        continue;
      }
      final blocked = _blocked[name];
      if (blocked != null && DateTime.now().isBefore(blocked.until)) {
        final left = blocked.until.difference(DateTime.now()).inMinutes + 1;
        note('$name: resting ${left}m after — ${blocked.reason}');
        continue;
      }
      try {
        final manifest = await explode.videos.streams.getManifest(
          videoId,
          ytClients: [client],
          requireWatchPage: watchPage,
        );
        final userAgent = client.payload['context']?['client']?['userAgent'];
        final headers = {if (userAgent is String) 'User-Agent': userAgent};
        final found = await _playableHd(manifest, headers);
        note('$name: ${found.note}');
        if (found.video != null) {
          return _HdStreams(
            video: found.video,
            audio: found.audio,
            headers: headers,
            report: report.join('\n'),
          );
        }
      } on Object catch (e) {
        final reason = _firstLine(e);
        note('$name: $reason');
        if (_isBotCheck(e)) {
          _blocked[name] = (
            until: DateTime.now().add(_botCheckRest),
            reason: reason,
          );
        }
      }
    }
    return _HdStreams(report: report.join('\n'));
  }

  /// [e] in a line: its first, and the reason YouTube gave if it gave one —
  /// which the package puts further down.
  /// YouTube turning this network away rather than this video: its bot
  /// check, or the watch page swapped for a captcha.
  static bool _isBotCheck(Object e) {
    final text = e.toString();
    return e is RequestLimitExceededException ||
        text.contains('not a bot') ||
        text.contains('Sign in to confirm');
  }

  static String _firstLine(Object e) {
    final lines = e
        .toString()
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (lines.isEmpty) return '$e';
    final reason = lines.firstWhere(
      (line) => line.startsWith('Reason:'),
      orElse: () => '',
    );
    return reason.isEmpty ? lines.first : '${lines.first} $reason';
  }

  /// The best H.264 picture and mp4 sound in [manifest] that play through,
  /// with a line saying what was found and what was not.
  Future<({String? video, String? audio, String note})> _playableHd(
    StreamManifest manifest,
    Map<String, String> headers,
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
    if (video == null) {
      return (
        video: null,
        audio: null,
        note: 'no H.264 picture among ${manifest.videoOnly.length} streams',
      );
    }
    final (videoStatus, audioStatus) = await (
      _middleStatus(video, headers),
      audio == null ? Future.value(0) : _middleStatus(audio, headers),
    ).wait;
    final size =
        '${video.videoResolution.width}x${video.videoResolution.height}';
    return (
      video: videoStatus == 206 ? video.url.toString() : null,
      audio: audioStatus == 206 ? audio!.url.toString() : null,
      note: videoStatus == 206
          ? 'plays $size'
          : '$size refused mid-file (HTTP $videoStatus)',
    );
  }

  static int _pixels(VideoOnlyStreamInfo s) =>
      s.videoResolution.width * s.videoResolution.height;

  /// What [stream] answers to a range from its middle: `206` for one that
  /// plays through, `403` for one that would stall after its first few
  /// hundred kilobytes.
  Future<int> _middleStatus(
    StreamInfo stream,
    Map<String, String> headers,
  ) async {
    final middle = stream.size.totalBytes ~/ 2;
    final response = await _probe.getUri<List<int>>(
      stream.url,
      options: Options(
        headers: {...headers, 'Range': 'bytes=$middle-${middle + 1023}'},
      ),
    );
    return response.statusCode ?? 0;
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

/// What the HD lookup came back with, and the account of how it went.
class _HdStreams {
  const _HdStreams({
    this.video,
    this.audio,
    this.headers = const {},
    required this.report,
  });

  final String? video;
  final String? audio;
  final Map<String, String> headers;
  final String report;
}
