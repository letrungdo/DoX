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

  group('Channel ordering', () {
    test('counts the digits in a name as a number', () {
      final playlist = ['VTV10', 'VTV2', 'VTV1', 'VTV9', 'HTV07', 'HTV7 HD']
          .map((name) => '#EXTINF:-1,$name\nhttps://example.com/$name.m3u8')
          .join('\n');

      final channels = tvChannelService.parsePlaylist('#EXTM3U\n$playlist');

      // Plain text ordering would file VTV10 straight after VTV1, which is
      // how nobody reads a remote control.
      expect(channels.map((channel) => channel.name), [
        'HTV07',
        'HTV7 HD',
        'VTV1',
        'VTV2',
        'VTV9',
        'VTV10',
      ]);
    });

    test('reads a name the way it is said, not the way it is spelled', () {
      // Accents sort after `z` in code unit order, and a name carrying `TV`
      // sorts after every number — so spelled as a playlist spells them,
      // these three came out at the far end of the list rather than beside
      // one another.
      expect(compareChannelNames('Vinh Long TV 4', 'Vĩnh Long 5'), lessThan(0));
      expect(compareChannelNames('Đà Nẵng', 'Da Nang TV 1'), lessThan(0));
      expect(compareChannelNames('Đà Nẵng', 'VTV1'), lessThan(0));
    });

    test('reads a leading zero as the same number', () {
      // `07` and `7` are the same channel number, so neither jumps the queue.
      expect(compareChannelNames('VTV07', 'VTV7'), 0);
      expect(compareChannelNames('VTV3', 'VTV20'), lessThan(0));
      expect(compareChannelNames('VTV3 HD', 'VTV3'), greaterThan(0));
    });
  });

  group('Mirrors of one channel', () {
    /// The way `iptv-org` lists a channel several CDNs carry: one entry per
    /// server, all under the same `tvg-id`.
    const mirrors = '''
#EXTM3U
#EXTINF:-1 tvg-id="VTV1.vn" group-title="General",VTV1 (1080p)
https://dethich.pw/vtv1/index.m3u8
#EXTINF:-1 tvg-id="VTV1.vn" tvg-logo="https://example.com/vtv1.png" group-title="General",VTV1
https://live.fptplay53.net/live/media/vtv1/live247-hls-avc/index.m3u8
#EXTINF:-1 tvg-id="VTV1.vn" group-title="General",VTV1
https://vips-livecdn.fptplay.net/live/media/vtv1/live247-hls-avc/index.m3u8
''';

    test('one row, with the other servers behind it', () {
      final channels = tvChannelService.parsePlaylist(mirrors);

      // Three entries, one station: the grid used to show it three times and
      // a viewer who picked the dead one had no way of knowing there were
      // two more.
      expect(channels, hasLength(1));
      expect(channels.single.urls, hasLength(3));
      expect(channels.single.url, channels.single.urls.first);
    });

    test('a later entry fills in the logo the first one was missing', () {
      final channels = tvChannelService.parsePlaylist(mirrors);

      expect(channels.single.logo, 'https://example.com/vtv1.png');
    });

    test('folds entries with no tvg-id by name', () {
      final channels = tvChannelService.parsePlaylist(
        '#EXTM3U\n'
        '#EXTINF:-1,Vĩnh Long 1 (1080p)\n'
        'https://example.com/a/index.m3u8\n'
        '#EXTINF:-1,Vinh Long 1\n'
        'https://example.com/b/index.m3u8\n',
      );

      expect(channels, hasLength(1));
      expect(channels.single.urls, [
        'https://example.com/a/index.m3u8',
        'https://example.com/b/index.m3u8',
      ]);
    });
  });

  group('Ordering the mirrors', () {
    test('a plain CDN link goes before a proxy or a repository copy', () {
      expect(
        rankStreamUrls([
          'https://iptv-org.github.io/vtv1.m3u8',
          'https://example.com/play.m3u8?vid=51',
          'https://cdn.example.com/vtv1/index.m3u8',
        ]),
        [
          'https://cdn.example.com/vtv1/index.m3u8',
          'https://example.com/play.m3u8?vid=51',
          'https://iptv-org.github.io/vtv1.m3u8',
        ],
      );
    });

    test('a link that names 1080p goes before one that names 480p', () {
      // Some CDNs publish one link per rendition beside the adaptive master.
      // They all play, so nothing else tells them apart, and the channel
      // used to open on whichever the playlist wrote first — TVB Vietnam
      // opened on 480p.
      expect(
        rankStreamUrls([
          'https://cdn.example.com/playlist480p.m3u8',
          'https://cdn.example.com/playlist.m3u8',
          'https://cdn.example.com/playlist1080p.m3u8',
        ]),
        [
          'https://cdn.example.com/playlist1080p.m3u8',
          // The master in the middle: the player can climb and fall with the
          // line, but it starts on the smallest rendition, which is the
          // first one a master lists.
          'https://cdn.example.com/playlist.m3u8',
          'https://cdn.example.com/playlist480p.m3u8',
        ],
      );
    });

    test('a number in the host is not a rendition', () {
      // `…-us-4491.playouts…` is a hostname, not a 4491p picture.
      expect(
        rankStreamUrls([
          'https://amg-us-4491.playouts.example.com/playlist.m3u8',
          'https://cdn.example.com/playlist720p.m3u8',
        ]).first,
        'https://cdn.example.com/playlist720p.m3u8',
      );
    });

    test('drops repeats and stops at the number worth trying', () {
      final ranked = rankStreamUrls([
        for (var i = 0; i < 8; i++) 'https://cdn$i.example.com/index.m3u8',
        'https://cdn0.example.com/index.m3u8',
      ]);

      expect(ranked, hasLength(maxStreamUrls));
      // Ties keep the order the playlist listed them in.
      expect(ranked.first, 'https://cdn0.example.com/index.m3u8');
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
