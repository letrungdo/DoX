import 'dart:convert';

import 'package:do_x/services/tv_channel_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// The shape `refresh-tv-channels` writes and the app reads back.
final _rows = jsonEncode([
  {
    'country_code': 'VN',
    'slug': 'vinhlong1',
    'name': 'Vinh Long TV 1',
    'url': 'https://example.com/thvl1/index.m3u8',
    'urls': [
      'https://example.com/thvl1/index.m3u8',
      'https://spare.example.com/thvl1/index.m3u8',
    ],
    'logo': 'https://example.com/thvl1.png',
    'categories': ['General', 'News'],
    'quality': '1080p',
    'is_geo_blocked': false,
    'is_intermittent': false,
    'headers': {'Referer': 'https://example.com/'},
    'sort_order': 0,
  },
  {
    'country_code': 'VN',
    'slug': 'htv7',
    'name': 'HTV7',
    'url': 'https://example.com/htv7/index.m3u8',
    'logo': null,
    'categories': <String>[],
    'quality': null,
    'is_geo_blocked': true,
    'is_intermittent': true,
    'headers': <String, String>{},
    'sort_order': 1,
  },
]);

void main() {
  group('Channels from the table', () {
    test('reads the fields the grid and the player need', () {
      final channels = tvChannelService.parseChannels(_rows);
      final thvl1 = channels.first;

      expect(thvl1.id, 'vinhlong1');
      expect(thvl1.name, 'Vinh Long TV 1');
      expect(thvl1.url, 'https://example.com/thvl1/index.m3u8');
      expect(thvl1.logo, 'https://example.com/thvl1.png');
      expect(thvl1.groups, ['General', 'News']);
      expect(thvl1.quality, '1080p');
      expect(thvl1.headers, {'Referer': 'https://example.com/'});
    });

    test('carries the spare links behind the one that played', () {
      final thvl1 = tvChannelService.parseChannels(_rows).first;

      expect(thvl1.urls, [
        'https://example.com/thvl1/index.m3u8',
        'https://spare.example.com/thvl1/index.m3u8',
      ]);
    });

    test('a row written before there were spares still has one link', () {
      // The column was added after the table; a row from the run before it
      // carries `url` alone and must not come back with nothing to play.
      final htv7 = tvChannelService.parseChannels(_rows).last;

      expect(htv7.urls, ['https://example.com/htv7/index.m3u8']);
    });

    test('the link that played leads, wherever the column lists it', () {
      final channels = tvChannelService.parseChannels(
        jsonEncode([
          {
            'slug': 'vtv1',
            'name': 'VTV1',
            'url': 'https://b.example.com/vtv1.m3u8',
            'urls': [
              'https://a.example.com/vtv1.m3u8',
              'https://b.example.com/vtv1.m3u8',
            ],
            'sort_order': 0,
          },
        ]),
      );

      expect(channels.single.urls, [
        'https://b.example.com/vtv1.m3u8',
        'https://a.example.com/vtv1.m3u8',
      ]);
    });

    test('keeps the order the rows arrive in', () {
      // The list is sorted where it is built, so the page draws it as it
      // comes rather than working the order out again on every rebuild.
      expect(tvChannelService.parseChannels(_rows).map((c) => c.name), [
        'Vinh Long TV 1',
        'HTV7',
      ]);
    });

    test('a channel with nothing filled in still reads', () {
      final htv7 = tvChannelService.parseChannels(_rows).last;

      expect(htv7.logo, isNull);
      expect(htv7.groups, isEmpty);
      expect(htv7.quality, isNull);
      expect(htv7.isGeoBlocked, isTrue);
      expect(htv7.isIntermittent, isTrue);
      expect(htv7.headers, isEmpty);
    });
  });

  group('Telling the two shapes apart', () {
    test('a playlist is still read as a playlist', () {
      // Every other country is an M3U file, and the stored copy of one has
      // to keep working after Vietnam moved to the table.
      final channels = tvChannelService.parseChannels('''
#EXTM3U
#EXTINF:-1 tvg-id="HTV7.vn@SD" group-title="Entertainment",HTV7 (720p)
https://example.com/htv7/index.m3u8
''');

      expect(channels, hasLength(1));
      expect(channels.single.name, 'HTV7');
      expect(channels.single.quality, '720p');
    });

    test('a stored body that makes no sense leaves the page empty', () {
      // Empty rather than thrown: the caller reads this as "nothing stored"
      // and goes to the network, which is the right answer for a copy that
      // cannot be read.
      expect(tvChannelService.parseChannels('[not json'), isEmpty);
      expect(tvChannelService.parseChannels('[]'), isEmpty);
    });
  });
}
