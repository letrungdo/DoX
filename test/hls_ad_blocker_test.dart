import 'dart:convert';
import 'dart:io';

import 'package:do_x/services/hls_ad_blocker.dart';
import 'package:do_x/services/local_hls_server.dart';
import 'package:flutter_test/flutter_test.dart';

final _base = Uri.parse('https://cdn.test/20260909/abc/3500kb/hls/index.m3u8');
const _dir = 'https://cdn.test/20260909/abc/3500kb/hls';

/// The layout the kkphim CDN serves: film segments beside the playlist, a
/// watermarked `convertv8/` clip that is part of the film, and a commercial
/// opened by `METHOD=NONE` under `/v8/<hash>/`.
const _playlist = '''
#EXTM3U
#EXT-X-VERSION:3
#EXT-X-TARGETDURATION:6
#EXT-X-MEDIA-SEQUENCE:0
#EXT-X-PLAYLIST-TYPE:VOD
#EXTINF:4.0,
a1.ts
#EXTINF:4.0,
a2.ts
#EXT-X-DISCONTINUITY
#EXTINF:4.0,
convertv8/c1.ts
#EXT-X-DISCONTINUITY
#EXTINF:4.0,
a3.ts
#EXTINF:4.0,
a4.ts
#EXT-X-DISCONTINUITY
#EXT-X-KEY:METHOD=NONE
#EXTINF:3.72,
/v8/d61a03b1dabe537cc05ffe5c9c280f56/segment_0001.ts
#EXTINF:2.36,
/v8/d61a03b1dabe537cc05ffe5c9c280f56/segment_0002.ts
#EXT-X-DISCONTINUITY
#EXTINF:4.0,
a5.ts
#EXTINF:4.0,
a6.ts
#EXT-X-ENDLIST
''';

List<String> _segments(String playlist) => const LineSplitter()
    .convert(playlist)
    .where((line) => line.isNotEmpty && !line.startsWith('#'))
    .toList();

void main() {
  group('stripHlsAds', () {
    test('cuts the commercial and keeps the film and its convertv clip', () {
      final result = stripHlsAds(_playlist, _base);

      expect(result.removedSegments, 2);
      expect(_segments(result.playlist), [
        '$_dir/a1.ts',
        '$_dir/a2.ts',
        '$_dir/convertv8/c1.ts',
        '$_dir/a3.ts',
        '$_dir/a4.ts',
        '$_dir/a5.ts',
        '$_dir/a6.ts',
      ]);
      expect(result.playlist, contains('#EXT-X-ENDLIST'));
      expect(result.playlist, contains('#EXT-X-TARGETDURATION:6'));
    });

    test('marks the splice with exactly one discontinuity', () {
      final lines = const LineSplitter().convert(
        stripHlsAds(_playlist, _base).playlist,
      );
      final a5 = lines.indexOf('$_dir/a5.ts');

      expect(lines.sublist(lines.indexOf('$_dir/a4.ts') + 1, a5), [
        '#EXT-X-DISCONTINUITY',
        '#EXT-X-KEY:METHOD=NONE',
        '#EXTINF:4.0,',
      ]);
    });

    test('catches a renamed ad path through the METHOD=NONE block', () {
      const source = '''
#EXTM3U
#EXTINF:4.0,
a1.ts
#EXT-X-DISCONTINUITY
#EXT-X-KEY:METHOD=NONE
#EXTINF:4.0,
https://other.test/brand-new/x1.ts
#EXT-X-DISCONTINUITY
#EXTINF:4.0,
a2.ts
#EXTINF:4.0,
a3.ts
''';
      final result = stripHlsAds(source, _base);

      expect(result.removedSegments, 1);
      expect(_segments(result.playlist), [
        '$_dir/a1.ts',
        '$_dir/a2.ts',
        '$_dir/a3.ts',
      ]);
    });

    test('never cuts a segment beside the playlist', () {
      // A film that happens to live under an ad-looking path.
      final base = Uri.parse('https://cdn.test/ads/film/index.m3u8');
      const source = '''
#EXTM3U
#EXT-X-KEY:METHOD=NONE
#EXTINF:4.0,
a1.ts
#EXTINF:4.0,
a2.ts
''';
      final result = stripHlsAds(source, base);

      expect(result.removedSegments, 0);
      expect(_segments(result.playlist), [
        'https://cdn.test/ads/film/a1.ts',
        'https://cdn.test/ads/film/a2.ts',
      ]);
    });

    test('resolves the key URI and declares it once', () {
      const source = '''
#EXTM3U
#EXT-X-KEY:METHOD=AES-128,URI="key.bin"
#EXTINF:4.0,
a1.ts
#EXTINF:4.0,
a2.ts
''';
      final lines = const LineSplitter().convert(
        stripHlsAds(source, _base).playlist,
      );

      expect(lines, contains('#EXT-X-KEY:METHOD=AES-128,URI="$_dir/key.bin"'));
      expect(lines.where((l) => l.startsWith('#EXT-X-KEY')), hasLength(1));
    });

    test('keeps everything when the guess would cut most of the film', () {
      const source = '''
#EXTM3U
#EXT-X-KEY:METHOD=NONE
#EXTINF:4.0,
https://elsewhere.test/film/a1.ts
#EXTINF:4.0,
https://elsewhere.test/film/a2.ts
''';
      final result = stripHlsAds(source, _base);

      expect(result.removedSegments, 0);
      expect(_segments(result.playlist), [
        'https://elsewhere.test/film/a1.ts',
        'https://elsewhere.test/film/a2.ts',
      ]);
    });
  });

  group('rewriteHlsMaster', () {
    const master = '''
#EXTM3U
#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="aud",NAME="vi",URI="audio/index.m3u8"
#EXT-X-STREAM-INF:BANDWIDTH=3500000,RESOLUTION=1920x1080,AUDIO="aud"
3500kb/hls/index.m3u8
''';
    final masterBase = Uri.parse('https://cdn.test/20260909/abc/index.m3u8');

    test('lists the variants and renditions', () {
      expect(hlsMasterMediaUris(master, masterBase).map((u) => '$u'), [
        'https://cdn.test/20260909/abc/audio/index.m3u8',
        'https://cdn.test/20260909/abc/3500kb/hls/index.m3u8',
      ]);
    });

    test('routes every media playlist and keeps the variant tags', () {
      final rewritten = rewriteHlsMaster(
        master,
        masterBase,
        (media) => 'local:${media.path}',
      );

      expect(rewritten, contains('URI="local:/20260909/abc/audio/index.m3u8"'));
      expect(rewritten, contains('local:/20260909/abc/3500kb/hls/index.m3u8'));
      expect(rewritten, contains('RESOLUTION=1920x1080'));
    });
  });

  group('LocalHlsServer.serveLazy', () {
    Future<(int, String)> get(String url) async {
      final client = HttpClient();
      try {
        final response = await (await client.getUrl(Uri.parse(url))).close();
        return (
          response.statusCode,
          await response.transform(utf8.decoder).join(),
        );
      } finally {
        client.close();
      }
    }

    test('serves the loaded playlist and a failed load as 502', () async {
      final server = LocalHlsServer();
      final ok = await server.serveLazy(() async => '#EXTM3U\n');
      final broken = await server.serveLazy(() async => throw 'offline');

      expect(await get(ok), (200, '#EXTM3U\n'));
      expect((await get(broken)).$1, HttpStatus.badGateway);
    });
  });
}
