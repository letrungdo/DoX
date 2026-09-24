import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:do_x/services/local_hls_server.dart';
import 'package:do_x/utils/logger.dart';
import 'package:flutter/foundation.dart';

/// Paths the stream CDNs park standalone commercials under: `ads/`, `promo/`
/// and the hashed `/v8/<hash>/segment_0001.ts` clips.
///
/// `convertv8/` is deliberately absent: those are real scenes of the film with
/// a sponsor watermark burned in, and dropping them cuts dialogue.
final _adSegmentPath = RegExp(
  r'(^|/)ads?\d*/|(^|/)promo\d*/|(^|/)v\d+/[0-9a-f]+/segment_',
);

/// Tags that describe the whole playlist rather than the segment after them,
/// so they survive whatever is cut around them.
const _playlistTags = [
  '#EXTM3U',
  '#EXT-X-VERSION',
  '#EXT-X-TARGETDURATION',
  '#EXT-X-MEDIA-SEQUENCE',
  '#EXT-X-DISCONTINUITY-SEQUENCE',
  '#EXT-X-PLAYLIST-TYPE',
  '#EXT-X-INDEPENDENT-SEGMENTS',
  '#EXT-X-START',
  '#EXT-X-ALLOW-CACHE',
  '#EXT-X-ENDLIST',
];

const _discontinuity = '#EXT-X-DISCONTINUITY';

final _uriAttribute = RegExp(r'URI="([^"]*)"');

/// A media playlist with its commercials cut out.
class HlsAdStripResult {
  const HlsAdStripResult(this.playlist, {required this.removedSegments});

  final String playlist;
  final int removedSegments;
}

/// Cuts the commercials out of the media playlist [source], fetched from
/// [base], and resolves every URI against [base] so the result can be served
/// from anywhere.
///
/// A segment outside the playlist's own directory is a commercial when its
/// path matches [_adSegmentPath], or when it follows an
/// `#EXT-X-KEY:METHOD=NONE` with no film segment in between — the CDN opens
/// every inserted block that way, so a renamed ad path is still caught. A
/// segment inside the playlist's own directory is always the film.
///
/// Each splice is marked with a single `#EXT-X-DISCONTINUITY`, and the key and
/// init section in force are re-declared where they would otherwise be lost
/// with the block. When the cut would take as many segments as it keeps, the
/// guess is wrong for this CDN and nothing is removed.
HlsAdStripResult stripHlsAds(String source, Uri base) {
  final ownDirectory = base.resolve('.').toString();
  final out = <String>[];
  final pending = <String>[];
  String? key;
  String? emittedKey;
  String? map;
  String? emittedMap;
  var candidate = false;
  var afterAd = false;
  var kept = 0;
  var removed = 0;

  for (final raw in const LineSplitter().convert(source)) {
    final line = raw.trim();
    if (line.isEmpty) continue;

    if (!line.startsWith('#')) {
      final uri = base.resolve(line);
      final isOwn = uri.resolve('.').toString() == ownDirectory;
      if (!isOwn && (candidate || _adSegmentPath.hasMatch(uri.path))) {
        removed++;
        afterAd = true;
        pending.clear();
        continue;
      }
      candidate = false;
      if (afterAd && kept > 0) out.add(_discontinuity);
      if (key != emittedKey) out.add(emittedKey = key!);
      if (map != emittedMap) out.add(emittedMap = map!);
      out.addAll(
        afterAd ? pending.where((tag) => tag != _discontinuity) : pending,
      );
      pending.clear();
      afterAd = false;
      out.add(uri.toString());
      kept++;
      continue;
    }

    if (line.startsWith('#EXT-X-KEY')) {
      key = _resolveUriAttribute(line, base);
      if (line.contains('METHOD=NONE')) candidate = true;
    } else if (line.startsWith('#EXT-X-MAP')) {
      map = _resolveUriAttribute(line, base);
    } else if (_playlistTags.any(line.startsWith)) {
      if (line.startsWith('#EXT-X-ENDLIST')) pending.clear();
      out.add(line);
    } else {
      pending.add(line);
    }
  }
  out.addAll(pending);

  if (removed > 0 && removed >= kept) {
    logger.d(
      '[HlsAdBlocker] would cut $removed of ${removed + kept} segments '
      'from $base — keeping them all',
    );
    return HlsAdStripResult(_resolveAll(source, base), removedSegments: 0);
  }
  return HlsAdStripResult('${out.join('\n')}\n', removedSegments: removed);
}

/// Every media playlist a master playlist [source] points at — the variants
/// and the alternate audio and subtitle renditions — resolved against [base].
List<Uri> hlsMasterMediaUris(String source, Uri base) {
  final uris = <Uri>[];
  var nextIsVariant = false;
  for (final raw in const LineSplitter().convert(source)) {
    final line = raw.trim();
    if (line.isEmpty) continue;
    if (line.startsWith('#EXT-X-STREAM-INF')) {
      nextIsVariant = true;
    } else if (!line.startsWith('#')) {
      if (nextIsVariant) uris.add(base.resolve(line));
      nextIsVariant = false;
    } else if (line.startsWith('#EXT-X-MEDIA')) {
      final uri = _uriAttribute.firstMatch(line)?.group(1);
      if (uri != null && uri.isNotEmpty) uris.add(base.resolve(uri));
    }
  }
  return uris;
}

/// The master playlist [source] with each media playlist it points at swapped
/// for [route] of it, and every other URI resolved against [base].
String rewriteHlsMaster(
  String source,
  Uri base,
  String Function(Uri media) route,
) {
  final out = <String>[];
  var nextIsVariant = false;
  for (final raw in const LineSplitter().convert(source)) {
    final line = raw.trim();
    if (line.isEmpty) continue;
    if (line.startsWith('#EXT-X-STREAM-INF')) {
      nextIsVariant = true;
      out.add(line);
    } else if (!line.startsWith('#')) {
      final uri = base.resolve(line);
      out.add(nextIsVariant ? route(uri) : uri.toString());
      nextIsVariant = false;
    } else if (line.startsWith('#EXT-X-MEDIA')) {
      out.add(
        line.replaceFirstMapped(_uriAttribute, (match) {
          final uri = match.group(1)!;
          return uri.isEmpty
              ? match.group(0)!
              : 'URI="${route(base.resolve(uri))}"';
        }),
      );
    } else {
      out.add(_resolveUriAttribute(line, base));
    }
  }
  return '${out.join('\n')}\n';
}

String _resolveUriAttribute(String line, Uri base) =>
    line.replaceFirstMapped(_uriAttribute, (match) {
      final uri = match.group(1)!;
      return uri.isEmpty ? match.group(0)! : 'URI="${base.resolve(uri)}"';
    });

String _resolveAll(String source, Uri base) {
  final out = <String>[];
  for (final raw in const LineSplitter().convert(source)) {
    final line = raw.trim();
    if (line.isEmpty) continue;
    out.add(
      line.startsWith('#')
          ? _resolveUriAttribute(line, base)
          : base.resolve(line).toString(),
    );
  }
  return '${out.join('\n')}\n';
}

/// Plays a film's HLS stream with the commercials the CDN splices into it cut
/// out.
///
/// The master playlist is rewritten so every media playlist it lists is
/// served, filtered, from [LocalHlsServer]; each is fetched only when the
/// player first asks for it. The segments themselves still come straight from
/// the CDN.
class HlsAdBlocker {
  HlsAdBlocker({Dio? dio, LocalHlsServer? server})
    : _dio = dio ?? Dio(),
      // A film's variants are read as the player switches to them, which can
      // be long after the master, so far more of them stay reachable.
      _server = server ?? LocalHlsServer(kept: 64);

  final Dio _dio;
  final LocalHlsServer _server;

  /// A loopback link to [url] with its commercials removed, or [url] itself
  /// when it cannot be filtered — playback must never break over an ad.
  Future<String> clean(
    String url, {
    Map<String, String> headers = const {},
  }) async {
    if (kIsWeb) return url;
    try {
      final (source, base) = await _fetch(Uri.parse(url), headers);
      if (!source.contains('#EXT-X-STREAM-INF')) {
        return await _server.serve(_strip(source, base));
      }

      final routes = <String, String>{};
      for (final media in hlsMasterMediaUris(source, base)) {
        routes[media.toString()] ??= await _server.serveLazy(
          _mediaLoader(media, headers),
        );
      }
      return await _server.serve(
        rewriteHlsMaster(
          source,
          base,
          (media) => routes[media.toString()] ?? media.toString(),
        ),
      );
    } on Object catch (error) {
      logger.d('[HlsAdBlocker] playing $url unfiltered', error: error);
      return url;
    }
  }

  /// Fetches [media] once and keeps the answer; a failed fetch is forgotten,
  /// so the player's retry asks the CDN again.
  Future<String> Function() _mediaLoader(
    Uri media,
    Map<String, String> headers,
  ) {
    Future<String>? loaded;
    return () async {
      try {
        return await (loaded ??= _fetch(
          media,
          headers,
        ).then((fetched) => _strip(fetched.$1, fetched.$2)));
      } on Object {
        loaded = null;
        rethrow;
      }
    };
  }

  String _strip(String source, Uri base) {
    final result = stripHlsAds(source, base);
    if (result.removedSegments > 0) {
      logger.d(
        '[HlsAdBlocker] cut ${result.removedSegments} ad segments from $base',
      );
    }
    return result.playlist;
  }

  /// The playlist at [uri] and the address it finally came from, which its
  /// relative URIs resolve against.
  Future<(String, Uri)> _fetch(Uri uri, Map<String, String> headers) async {
    final response = await _dio.getUri<String>(
      uri,
      options: Options(responseType: ResponseType.plain, headers: headers),
    );
    return (response.data ?? '', response.realUri);
  }
}

final hlsAdBlocker = HlsAdBlocker();
