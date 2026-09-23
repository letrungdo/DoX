import 'package:do_x/services/youtube_music_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// A YouTube HLS master as the `VISIONOS` client gets it, cut down: smallest
/// first, VP9 beside H.264, and subtitle groups every variant names.
const _master = '''
#EXTM3U
#EXT-X-INDEPENDENT-SEGMENTS
#EXT-X-MEDIA:URI="https://m/audio/233",TYPE=AUDIO,GROUP-ID="233",NAME="Default",DEFAULT=YES,AUTOSELECT=YES
#EXT-X-MEDIA:URI="https://m/audio/234",TYPE=AUDIO,GROUP-ID="234",NAME="Default",DEFAULT=YES,AUTOSELECT=YES
#EXT-X-MEDIA:URI="https://m/subs/en",TYPE=SUBTITLES,GROUP-ID="vtt",NAME="English",LANGUAGE="en"
#EXT-X-STREAM-INF:BANDWIDTH=313238,CODECS="avc1.4D4015,mp4a.40.5",RESOLUTION=426x240,FRAME-RATE=24,AUDIO="233",SUBTITLES="vtt"
https://m/video/229
#EXT-X-STREAM-INF:BANDWIDTH=804467,CODECS="avc1.4D401E,mp4a.40.2",RESOLUTION=640x360,FRAME-RATE=24,AUDIO="234",SUBTITLES="vtt"
https://m/video/230
#EXT-X-STREAM-INF:BANDWIDTH=2569938,CODECS="avc1.4D401F,mp4a.40.2",RESOLUTION=1280x720,FRAME-RATE=24,AUDIO="234",SUBTITLES="vtt"
https://m/video/232
#EXT-X-STREAM-INF:BANDWIDTH=3116363,CODECS="avc1.640028,mp4a.40.2",RESOLUTION=1920x1080,FRAME-RATE=24,AUDIO="234",SUBTITLES="vtt"
https://m/video/270
#EXT-X-STREAM-INF:BANDWIDTH=1442076,CODECS="vp09.00.31.08,mp4a.40.2",RESOLUTION=1280x720,FRAME-RATE=24,AUDIO="234",SUBTITLES="vtt"
https://m/video/612
''';

void main() {
  test('puts the largest H.264 variant that fits first', () {
    final trimmed = YoutubeMusicService.trimHlsMaster(
      _master,
      maxPixels: 1280 * 720,
    )!;
    final lines = trimmed.playlist.split('\n');

    expect(trimmed.size, '1280x720');
    expect(lines.where((l) => l.startsWith('https://m/video/')).toList(), [
      'https://m/video/232',
      'https://m/video/230',
      'https://m/video/229',
    ]);
    // Each link still follows its own tag.
    final first = lines.indexWhere((l) => l.startsWith('#EXT-X-STREAM-INF'));
    expect(lines[first], contains('RESOLUTION=1280x720'));
    expect(lines[first + 1], 'https://m/video/232');
  });

  test('keeps every group the variants name, and the header', () {
    final playlist = YoutubeMusicService.trimHlsMaster(
      _master,
      maxPixels: 1280 * 720,
    )!.playlist;

    expect(playlist, startsWith('#EXTM3U\n#EXT-X-INDEPENDENT-SEGMENTS\n'));
    expect('#EXT-X-MEDIA:'.allMatches(playlist), hasLength(3));
    expect(playlist, isNot(contains('vp09')));
  });

  test('lets 1080p in where the cap allows it', () {
    final trimmed = YoutubeMusicService.trimHlsMaster(
      _master,
      maxPixels: 1920 * 1080,
    )!;
    expect(trimmed.size, '1920x1080');
  });

  test('is null for a master with no H.264 variant', () {
    expect(
      YoutubeMusicService.trimHlsMaster(
        '#EXTM3U\n'
        '#EXT-X-STREAM-INF:BANDWIDTH=1,CODECS="vp09.00.31.08",RESOLUTION=1280x720\n'
        'https://m/video/612\n',
        maxPixels: 1280 * 720,
      ),
      isNull,
    );
  });
}
