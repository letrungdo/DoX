import 'package:do_x/services/tv_channel_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Entries in the exact shape `iptv-org/iptv` publishes them for Vietnam, so a
/// change in that playlist's format shows up here rather than as an empty page.
const _playlist = '''
#EXTM3U
#EXTINF:-1 tvg-id="AnNinhTV.vn@HD" tvg-logo="https://example.com/antv.png" group-title="Undefined",An Ninh TV HD (1080p)
https://example.com/anninhtv/index.m3u8
#EXTINF:-1 tvg-id="AnGiangTV1.vn@SD" tvg-logo="https://example.com/ag.png" group-title="General;News",An Giang TV 1 (1080p) [Geo-blocked]
https://example.com/angiang/kgtv.m3u8
#EXTINF:-1 tvg-id="" tvg-logo="" group-title="Sports",Some Sport TV (720p) [Not 24/7]
#EXTVLCOPT:http-referrer=https://example.com/
#EXTVLCOPT:http-user-agent=Mozilla/5.0 (Windows NT 10.0; Win64; x64), Chrome
https://example.com/sport/playlist.m3u8
''';

void main() {
  group('TV playlist parsing', () {
    test('reads the fields the channel grid shows', () {
      final channels = tvChannelService.parsePlaylist(_playlist);
      final antv = channels.firstWhere((c) => c.id == 'AnNinhTV.vn@HD');

      // The name loses the quality and the flags, which become fields of
      // their own — the card shows them as badges, not as part of the title.
      expect(antv.name, 'An Ninh TV HD');
      expect(antv.quality, '1080p');
      expect(antv.logo, 'https://example.com/antv.png');
      expect(antv.url, 'https://example.com/anninhtv/index.m3u8');
      expect(antv.groups, ['Undefined']);
      expect(antv.isGeoBlocked, isFalse);
    });

    test('splits multi-category channels and keeps the flags', () {
      final channels = tvChannelService.parsePlaylist(_playlist);
      final angiang = channels.firstWhere((c) => c.id == 'AnGiangTV1.vn@SD');

      expect(angiang.groups, ['General', 'News']);
      expect(angiang.isGeoBlocked, isTrue);
      expect(angiang.isIntermittent, isFalse);
    });

    test('turns playback options into request headers', () {
      final channels = tvChannelService.parsePlaylist(_playlist);
      final sport = channels.firstWhere((c) => c.name == 'Some Sport TV');

      expect(sport.isIntermittent, isTrue);
      expect(sport.headers['Referer'], 'https://example.com/');
      // The user agent itself contains commas, so the name has to be taken
      // from the last one on the line and the option read whole.
      expect(
        sport.headers['User-Agent'],
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64), Chrome',
      );
      // An entry with no tvg-id still needs a stable key of its own.
      expect(sport.id, sport.url);
    });

    test('drops duplicates and sorts by name', () {
      final channels = tvChannelService.parsePlaylist('$_playlist\n$_playlist');

      expect(channels.length, 3);
      expect(channels.map((c) => c.name).toList(), [
        'An Giang TV 1',
        'An Ninh TV HD',
        'Some Sport TV',
      ]);
    });

    test('ignores anything that is not a stream entry', () {
      final channels = tvChannelService.parsePlaylist(
        '#EXTM3U\n#EXTINF:-1,Broken entry with no URL\n',
      );

      expect(channels, isEmpty);
    });
  });

  group('TvChannel.matches', () {
    test('finds a Vietnamese name typed without accents', () {
      final channels = tvChannelService.parsePlaylist(
        '#EXTINF:-1 tvg-id="VL.vn" group-title="General",Vĩnh Long 1 (1080p)\n'
        'https://example.com/vl/index.m3u8\n',
      );

      expect(channels.single.matches('vinh long'), isTrue);
      expect(channels.single.matches('ĩnh LO'), isTrue);
      expect(channels.single.matches('hanoi'), isFalse);
    });
  });
}
