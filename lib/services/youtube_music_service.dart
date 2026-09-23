import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:do_x/model/music_track.dart';
import 'package:do_x/model/music_video.dart';
import 'package:do_x/services/local_hls_server.dart';
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
/// Two kinds of stream, the second only when the first is not to be had:
///
/// - **HD** — the adaptive streams, picture and sound apart, up to 1080p. The
///   app's default client gets them too, but without a proof-of-origin token
///   YouTube serves only their first few hundred kilobytes and answers `403`
///   to every range after that, so a player stalls within seconds. The
///   clients that need no such token are asked instead — see [_hdStreams].
///   Every HD stream is also tried from the middle before it is handed over,
///   because a link that only opens is not yet one that plays.
/// - **Muxed** — picture and sound together at 360p, which plays to the end
///   with no challenge at all. It is what is left when HD is not, and is
///   asked for only then: a request for a stream nobody watches is one more
///   for YouTube to count against the network.
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

  /// The Apple Vision Pro client, as SmartTube asks as. Its adaptive links
  /// come plain — no signature, no `n` challenge, no proof-of-origin token —
  /// and play through to the end. `ANDROID_VR`, which also needs no token,
  /// hands over links that YouTube now refuses past their first few hundred
  /// kilobytes.
  static const _visionOsUserAgent =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 15_7_3) AppleWebKit/605.1.15 '
      '(KHTML, like Gecko) Version/26.0 Safari/605.1.15';

  /// The visitor id `VISIONOS` is introduced as, fetched once and kept
  /// until YouTube stops taking it.
  Future<String>? _visitorData;

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
  YoutubeExplode? get _hd =>
      _solver == null ? null : _hdExplode ??= YoutubeExplode(jsSolver: _solver);

  /// The challenge solver, shared by every client that needs one.
  WebViewJsSolver? _solverInstance;
  WebViewJsSolver? get _solver => WebViewJsSolver.isSupported
      ? _solverInstance ??= WebViewJsSolver()
      : null;

  /// The pick made for each track, including "none", so a track played again
  /// is not searched for again. Only an answer is kept; a search that failed
  /// is tried afresh next time.
  final _picks = <String, MusicVideoPick?>{};

  /// The video for [track], or null when there is no video worth showing —
  /// as yet with no stream: those follow from [withHd], whose lookup starts
  /// here. Never throws: a missing video leaves the track playing as it
  /// always has.
  Future<MusicVideo?> findVideo(MusicTrack track) async {
    // Wanted by the HD lookup that follows; fetched while the search runs.
    _visitorId().ignore();
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
      // Started now rather than when [withHd] is asked, so it is in as soon
      // as it can be.
      _hdStarted = _startLookup(id);
      return MusicVideo(
        videoId: id,
        duration: pick.video.duration,
        useAudio: pick.useAudio,
        loops: pick.loops,
      );
    } on Object catch (e) {
      logger.d('[MusicVideo] no video for ${track.id}: $e');
      return null;
    }
  }

  /// [video] with its streams: HD where there is HD, the muxed 360p one
  /// otherwise. Bounded in time: the first one also fetches
  /// the solver and the player script. Never throws.
  Future<MusicVideo> withHd(MusicVideo video) async {
    final started = _hdStarted;
    _hdStarted = null;
    final lookup = started != null && started.videoId == video.videoId
        ? started
        : _startLookup(video.videoId);
    var hd = const _HdStreams();
    try {
      hd = await lookup.hd.timeout(_hdWait);
    } on TimeoutException {
      logger.d('[MusicVideo] ${video.videoId} HD timed out');
    } on Object catch (e) {
      logger.d('[MusicVideo] ${video.videoId} HD: $e');
    }
    return video.withHd(
      videoUrl: hd.video,
      audioUrl: hd.audio,
      headers: hd.headers,
      muxedUrl: hd.video == null ? await lookup.muxed() : null,
    );
  }

  /// The lookup [findVideo] started for the video it found, waiting for
  /// [withHd] to pick it up. Only the latest: a track skipped past leaves
  /// its lookup to finish unread.
  _StreamLookup? _hdStarted;

  /// HD for [videoId], with the muxed stream asked for the moment the first
  /// client comes back without HD — alongside the next, which can take a
  /// while, rather than after it.
  _StreamLookup _startLookup(String videoId) {
    Future<String?>? muxed;
    Future<String?> fallback() =>
        muxed ??= _muxedStream(videoId).catchError((Object e) {
          logger.d('[MusicVideo] no muxed stream for $videoId: $e');
          return null;
        });
    final hd = _hdStreams(videoId, onMiss: () => unawaited(fallback()))
      ..ignore();
    return (videoId: videoId, hd: hd, muxed: fallback);
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

  /// [videoId]'s HD picture and sound, each only if it plays through.
  ///
  /// Asked of the clients that hand adaptive streams over without a
  /// proof-of-origin token, one after the other until one of them plays:
  ///
  /// - `VISIONOS`, which needs only a visitor id — no watch page, no
  ///   challenge. See [_visionOsHd].
  /// - `TV`, whose links carry signature and `n` challenges for
  ///   [WebViewJsSolver] to solve, and which needs the watch page for the
  ///   player script those challenges are written in.
  ///
  /// [onMiss] is called when a client has come back without HD and the next
  /// is about to be asked.
  Future<_HdStreams> _hdStreams(
    String videoId, {
    void Function()? onMiss,
  }) async {
    final hd = _hd;
    final attempts = <(String, Future<_FoundHd> Function()?)>[
      ('VISIONOS', () => _visionOsHd(videoId)),
      ('TV', hd == null ? null : () => _tvHd(hd, videoId)),
    ];
    void note(String line) => logger.d('[MusicVideo] $videoId $line');

    for (final (index, (name, attempt)) in attempts.indexed) {
      if (index > 0) onMiss?.call();
      if (attempt == null) {
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
        final found = await attempt();
        note('$name: ${found.note}');
        if (found.video != null) {
          return _HdStreams(
            video: found.video,
            audio: found.audio,
            headers: found.headers,
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
          // A visitor id YouTube has stopped taking is not asked with again.
          _visitorData = null;
        }
      }
    }
    return const _HdStreams();
  }

  /// Where AVPlayer plays: it opens YouTube's adaptive mp4 only after reading
  /// through much of the file — half a minute and more for a 720p picture —
  /// but an HLS playlist in a couple of seconds.
  static bool get _prefersHls =>
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;

  /// HD from the `VISIONOS` client, asked directly rather than through the
  /// package, which reads the answer's HLS playlist but does not hand its
  /// link over.
  ///
  /// Where AVPlayer plays ([_prefersHls]) the picture is that playlist, cut
  /// down by [trimHlsMaster] and served by [LocalHlsServer]; elsewhere it is
  /// the adaptive mp4. The sound is the adaptive mp4 either way.
  Future<_FoundHd> _visionOsHd(String videoId) async {
    final visitorData = await _visitorId();
    final headers = {'User-Agent': _visionOsUserAgent};
    final response = await _probe.post<Map<String, dynamic>>(
      _playerUrl,
      data: _visionOsRequest(videoId, visitorData),
      options: Options(
        responseType: ResponseType.json,
        headers: {
          ...headers,
          'Content-Type': 'application/json',
          'Origin': 'https://www.youtube.com',
          'X-Goog-Visitor-Id': visitorData,
          'X-Youtube-Client-Name': '101',
          'X-Youtube-Client-Version': _visionOsVersion,
        },
      ),
    );
    final json = response.data;
    if (response.statusCode != 200 || json == null) {
      throw Exception('player answered HTTP ${response.statusCode}');
    }
    final playability = json['playabilityStatus'];
    final status = playability?['status'];
    if (status != 'OK') {
      throw Exception('$status Reason: ${playability?['reason'] ?? ''}');
    }

    final pictures = <_AdaptiveStream>[];
    final sounds = <_AdaptiveStream>[];
    final formats = json['streamingData']?['adaptiveFormats'];
    for (final format in formats is List ? formats : const []) {
      final stream = _AdaptiveStream.parse(format);
      if (stream == null) continue;
      if (stream.isH264) pictures.add(stream);
      if (stream.isAac) sounds.add(stream);
    }

    final hlsUrl = json['streamingData']?['hlsManifestUrl'];
    if (_prefersHls && hlsUrl is String) {
      final (master, audio) = await (
        _probe.get<String>(
          hlsUrl,
          options: Options(responseType: ResponseType.plain, headers: headers),
        ),
        _playableSound(sounds, headers),
      ).wait;
      final trimmed = master.statusCode == 200 && master.data != null
          ? trimHlsMaster(master.data!, maxPixels: _maxPixels)
          : null;
      if (trimmed != null) {
        return (
          video: await _hlsServer.serve(trimmed.playlist),
          audio: audio,
          headers: headers,
          note: 'plays ${trimmed.size} over HLS',
        );
      }
    }
    return _playableHd(pictures, sounds, headers);
  }

  static const _playerUrl =
      'https://www.youtube.com/youtubei/v1/player?prettyPrint=false';

  static const _visionOsVersion = '1.02';

  static Map<String, dynamic> _visionOsRequest(
    String videoId,
    String visitorData,
  ) => {
    'context': {
      'client': {
        'clientName': 'VISIONOS',
        'clientVersion': _visionOsVersion,
        'deviceMake': 'Apple',
        'deviceModel': 'RealityDevice17,1',
        'osName': 'visionOS',
        'osVersion': '26.5.23O471',
        'userAgent': _visionOsUserAgent,
        'visitorData': visitorData,
        'hl': 'en',
      },
    },
    'videoId': videoId,
    'contentCheckOk': true,
    'racyCheckOk': true,
  };

  /// Serves the HLS playlists [trimHlsMaster] rewrites.
  final _hlsServer = LocalHlsServer();

  /// HD from the `TV` client, through the package and [WebViewJsSolver].
  Future<_FoundHd> _tvHd(YoutubeExplode explode, String videoId) async {
    final client = YoutubeApiClient.tv;
    final manifest = await explode.videos.streams.getManifest(
      videoId,
      ytClients: [client],
      requireWatchPage: true,
    );
    final userAgent = client.payload['context']?['client']?['userAgent'];
    final headers = {if (userAgent is String) 'User-Agent': userAgent};
    return _playableHd(
      [
        for (final s in manifest.videoOnly)
          if (s.container == StreamContainer.mp4 &&
              s.videoCodec.startsWith('avc1'))
            _AdaptiveStream(
              url: s.url,
              bytes: s.size.totalBytes,
              bitrate: s.bitrate.bitsPerSecond,
              width: s.videoResolution.width,
              height: s.videoResolution.height,
            ),
      ],
      [
        for (final s in manifest.audioOnly)
          if (s.container == StreamContainer.mp4)
            _AdaptiveStream(
              url: s.url,
              bytes: s.size.totalBytes,
              bitrate: s.bitrate.bitsPerSecond,
            ),
      ],
      headers,
    );
  }

  /// [master] with only the H.264 variants no larger than [maxPixels], the
  /// largest first, and the size of that one — or null when it has none.
  ///
  /// AVPlayer starts on the first variant listed and climbs from there only
  /// slowly; YouTube lists its smallest first. VP9 goes too: AVPlayer would
  /// pick it, and not every iPhone decodes it in hardware. Everything else —
  /// the audio and subtitle groups the variants name — is kept as it is.
  @visibleForTesting
  static ({String playlist, String size})? trimHlsMaster(
    String master, {
    required int maxPixels,
  }) {
    final lines = const LineSplitter().convert(master);
    final head = <String>[];
    final variants = <({int pixels, int bandwidth, String info, String uri})>[];
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (!line.startsWith('#EXT-X-STREAM-INF:')) {
        // A variant's link is taken with its tag below.
        if (line.isNotEmpty && !line.startsWith('#')) continue;
        if (line.isNotEmpty) head.add(line);
        continue;
      }
      final uri = i + 1 < lines.length ? lines[i + 1] : '';
      final codecs = _hlsAttribute(line, 'CODECS') ?? '';
      final resolution = _hlsAttribute(line, 'RESOLUTION')?.split('x');
      final width = int.tryParse(resolution?.first ?? '');
      final height = int.tryParse(resolution?.last ?? '');
      if (!codecs.startsWith('avc1') ||
          width == null ||
          height == null ||
          width * height > maxPixels ||
          uri.isEmpty ||
          uri.startsWith('#')) {
        continue;
      }
      variants.add((
        pixels: width * height,
        bandwidth: int.tryParse(_hlsAttribute(line, 'BANDWIDTH') ?? '') ?? 0,
        info: line,
        uri: uri,
      ));
    }
    if (variants.isEmpty) return null;
    variants.sort(
      (a, b) => a.pixels != b.pixels
          ? b.pixels.compareTo(a.pixels)
          : b.bandwidth.compareTo(a.bandwidth),
    );
    return (
      playlist: [
        ...head,
        for (final v in variants) ...[v.info, v.uri],
      ].join('\n'),
      size: _hlsAttribute(variants.first.info, 'RESOLUTION') ?? '',
    );
  }

  /// The value of [name] in an HLS tag's attribute list, unquoted.
  static String? _hlsAttribute(String tag, String name) => RegExp(
    '[:,]$name=("[^"]*"|[^,]*)',
  ).firstMatch(tag)?.group(1)?.replaceAll('"', '');

  /// A visitor id from `sw.js_data`, the service worker's bootstrap data,
  /// where the package and SmartTube both find one.
  Future<String> _visitorId() =>
      _visitorData ??= _fetchVisitorId().catchError((Object e) {
        // Fetched afresh next time rather than failing every video after.
        _visitorData = null;
        throw e;
      });

  Future<String> _fetchVisitorId() async {
    final response = await _dio.get<String>(
      'https://www.youtube.com/sw.js_data',
      options: Options(
        responseType: ResponseType.plain,
        headers: {'User-Agent': _visionOsUserAgent},
      ),
    );
    var body = response.data ?? '';
    if (body.startsWith(")]}'")) body = body.substring(4);
    final value = (jsonDecode(body) as List)[0][2][0][0][13];
    if (value is! String || value.isEmpty) {
      throw const FormatException('sw.js_data carried no visitor id');
    }
    return value;
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

  /// The largest of [pictures] no larger than [_maxPixels] and the best of
  /// [sounds], each only if it plays from the middle, with a line saying
  /// what was found and what was not.
  ///
  /// H.264 only: every phone and television decodes it in hardware, which
  /// is not yet true of AV1, and VP9 comes in WebM, which iOS will not open.
  Future<_FoundHd> _playableHd(
    List<_AdaptiveStream> pictures,
    List<_AdaptiveStream> sounds,
    Map<String, String> headers,
  ) async {
    final fitting = pictures.where((s) => s.pixels <= _maxPixels).toList()
      ..sort((a, b) => b.pixels.compareTo(a.pixels));
    if (fitting.isEmpty) {
      return (
        video: null,
        audio: null,
        headers: headers,
        note: 'no H.264 picture among ${pictures.length} streams',
      );
    }
    final video = fitting.first;
    final (videoStatus, audio) = await (
      _middleStatus(video, headers),
      _playableSound(sounds, headers),
    ).wait;
    final size = '${video.width}x${video.height}';
    return (
      video: videoStatus == 206 ? video.url.toString() : null,
      audio: audio,
      headers: headers,
      note: videoStatus == 206
          ? 'plays $size'
          : '$size refused mid-file (HTTP $videoStatus)',
    );
  }

  /// The best of [sounds], if it plays from the middle.
  Future<String?> _playableSound(
    List<_AdaptiveStream> sounds,
    Map<String, String> headers,
  ) async {
    if (sounds.isEmpty) return null;
    final best = sounds.reduce((a, b) => b.bitrate > a.bitrate ? b : a);
    return await _middleStatus(best, headers) == 206
        ? best.url.toString()
        : null;
  }

  /// What [stream] answers to a range from its middle: `206` for one that
  /// plays through, `403` for one that would stall after its first few
  /// hundred kilobytes.
  Future<int> _middleStatus(
    _AdaptiveStream stream,
    Map<String, String> headers,
  ) => _statusFromMiddle(stream.url, stream.bytes, headers);

  Future<int> _statusFromMiddle(
    Uri url,
    int totalBytes,
    Map<String, String> headers,
  ) async {
    final middle = totalBytes ~/ 2;
    final response = await _probe.getUri<List<int>>(
      url,
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

/// What the HD lookup came back with.
class _HdStreams {
  const _HdStreams({this.video, this.audio, this.headers = const {}});

  final String? video;
  final String? audio;
  final Map<String, String> headers;
}

/// A video's streams on their way: HD, and the muxed stream asked for only
/// if HD does not come.
typedef _StreamLookup = ({
  String videoId,
  Future<_HdStreams> hd,
  Future<String?> Function() muxed,
});

/// What one client's HD lookup came back with.
typedef _FoundHd = ({
  String? video,
  String? audio,
  Map<String, String> headers,
  String note,
});

/// One adaptive stream — picture only or sound only — in an mp4.
class _AdaptiveStream {
  const _AdaptiveStream({
    required this.url,
    required this.bytes,
    required this.bitrate,
    this.width = 0,
    this.height = 0,
    this.mimeType = '',
  });

  /// An entry of the player answer's `adaptiveFormats`, or null for one
  /// without a plain link.
  static _AdaptiveStream? parse(dynamic format) {
    if (format is! Map) return null;
    final url = Uri.tryParse(format['url']?.toString() ?? '');
    final bytes = int.tryParse(format['contentLength']?.toString() ?? '');
    if (url == null || !url.hasScheme || bytes == null) return null;
    return _AdaptiveStream(
      url: url,
      bytes: bytes,
      bitrate: (format['bitrate'] as num?)?.toInt() ?? 0,
      width: (format['width'] as num?)?.toInt() ?? 0,
      height: (format['height'] as num?)?.toInt() ?? 0,
      mimeType: format['mimeType']?.toString() ?? '',
    );
  }

  final Uri url;
  final int bytes;
  final int bitrate;
  final int width;
  final int height;

  /// `video/mp4; codecs="avc1.4d401f"` and the like.
  final String mimeType;

  int get pixels => width * height;
  bool get isH264 => mimeType.startsWith('video/mp4; codecs="avc1');
  bool get isAac => mimeType.startsWith('audio/mp4');
}
