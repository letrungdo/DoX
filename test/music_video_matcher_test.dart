import 'package:do_x/model/music_track.dart';
import 'package:do_x/model/music_video.dart';
import 'package:do_x/services/music_video_matcher.dart';
import 'package:do_x/services/youtube_music_service.dart';
import 'package:flutter_test/flutter_test.dart';

MusicTrack _track(String title, Duration duration, {String artist = ''}) =>
    MusicTrack(
      id: '1',
      title: title,
      artist: artist,
      artworkUrl: '',
      streamUrl: '',
      duration: duration,
    );

YoutubeVideo _video(
  String id,
  String title,
  Duration duration, {
  String author = '',
  bool official = false,
}) => YoutubeVideo(
  id: id,
  title: title,
  author: author,
  duration: duration,
  isOfficial: official,
);

/// One search result, shaped the way YouTube Music sends it.
Map<String, dynamic> _item(
  String id,
  String title,
  List<String> details,
  String type,
) => {
  'musicResponsiveListItemRenderer': {
    'flexColumns': [
      {
        'musicResponsiveListItemFlexColumnRenderer': {
          'text': {
            'runs': [
              {'text': title},
            ],
          },
        },
      },
      {
        'musicResponsiveListItemFlexColumnRenderer': {
          'text': {
            'runs': [
              for (final d in details) {'text': d},
            ],
          },
        },
      },
    ],
    'overlay': {
      'musicItemThumbnailOverlayRenderer': {
        'content': {
          'musicPlayButtonRenderer': {
            'playNavigationEndpoint': {
              'watchEndpoint': {
                'videoId': id,
                'watchEndpointMusicSupportedConfigs': {
                  'watchEndpointMusicConfig': {'musicVideoType': type},
                },
              },
            },
          },
        },
      },
    },
  },
};

void main() {
  const song = Duration(minutes: 4, seconds: 37);

  test('reads the videos out of a YouTube Music search answer', () {
    final videos = YoutubeMusicService.parseSearch({
      'contents': {
        'tabbedSearchResultsRenderer': {
          'tabs': [
            {
              'tabRenderer': {
                'content': {
                  'sectionListRenderer': {
                    'contents': [
                      {
                        'musicShelfRenderer': {
                          'contents': [
                            _item(
                              'omv',
                              'Chúng Ta Của Tương Lai',
                              [
                                'Sơn Tùng M-TP',
                                ' • ',
                                '91M views',
                                ' • ',
                                '4:37',
                              ],
                              'MUSIC_VIDEO_TYPE_OMV',
                            ),
                            _item('ugc', 'Long mix', [
                              'Someone',
                              ' • ',
                              '1:02:03',
                            ], 'MUSIC_VIDEO_TYPE_UGC'),
                          ],
                        },
                      },
                    ],
                  },
                },
              },
            },
          ],
        },
      },
    });

    expect(videos, hasLength(2));
    expect(videos[0].id, 'omv');
    expect(videos[0].author, 'Sơn Tùng M-TP');
    expect(videos[0].duration, song);
    expect(videos[0].isOfficial, isTrue);
    expect(
      videos[1].duration,
      const Duration(hours: 1, minutes: 2, seconds: 3),
    );
    expect(videos[1].isOfficial, isFalse);
  });

  test('an official video of the same song brings its sound', () {
    final pick = MusicVideoMatcher.pick(
      _track('Sơn Tùng M-TP - Chúng Ta Của Tương Lai', song),
      [
        _video(
          'omv',
          'CHÚNG TA CỦA TƯƠNG LAI | OFFICIAL MUSIC VIDEO',
          song + const Duration(seconds: 12),
          author: 'Sơn Tùng M-TP',
          official: true,
        ),
      ],
    );

    expect(pick?.video.id, 'omv');
    expect(pick?.useAudio, isTrue);
  });

  test('a remix never gets the original, nor the original a karaoke', () {
    final remix = MusicVideoMatcher.pick(
      _track('Chúng Ta Của Tương Lai (Remix)', song),
      [_video('omv', 'Chúng Ta Của Tương Lai', song, official: true)],
    );
    final original = MusicVideoMatcher.pick(
      _track('Chúng Ta Của Tương Lai', song),
      [_video('k', 'Chúng Ta Của Tương Lai - Karaoke', song)],
    );

    expect(remix, isNull);
    expect(original, isNull);
  });

  test('an official remix of another length is not taken for this one', () {
    final pick = MusicVideoMatcher.pick(
      _track('See Tình (Remix)', const Duration(seconds: 190)),
      [
        _video(
          'omv',
          'Hoàng Thuỳ Linh - See Tình | Remix Version',
          const Duration(seconds: 171),
          official: true,
        ),
      ],
    );

    expect(pick, isNull);
  });

  test('a fan video has to last as long as the track to be laid over it', () {
    final track = _track('Chúng Ta Của Tương Lai', song);
    final close = MusicVideoMatcher.pick(track, [
      _video(
        'near',
        'Chúng Ta Của Tương Lai',
        song + const Duration(seconds: 3),
      ),
    ]);
    final far = MusicVideoMatcher.pick(track, [
      _video(
        'far',
        'Chúng Ta Của Tương Lai',
        song + const Duration(seconds: 20),
      ),
    ]);

    expect(close?.video.id, 'near');
    expect(close?.useAudio, isFalse);
    expect(far, isNull);
  });

  test('an official video far longer than the song is turned down', () {
    final pick = MusicVideoMatcher.pick(
      _track('Chúng Ta Của Hiện Tại', const Duration(minutes: 5, seconds: 1)),
      [
        _video(
          'film',
          'Chúng Ta Của Hiện Tại',
          const Duration(minutes: 14, seconds: 51),
          official: true,
        ),
      ],
    );

    expect(pick, isNull);
  });

  test('a video about some other song is turned down', () {
    final pick = MusicVideoMatcher.pick(_track('Chúng Ta Của Hiện Tại', song), [
      _video('other', 'Hãy Trao Cho Anh', song, official: true),
    ]);

    expect(pick, isNull);
  });

  test('the official video wins over a fan upload of the same song', () {
    final pick = MusicVideoMatcher.pick(_track('Nơi Này Có Anh', song), [
      _video('fan', 'Nơi Này Có Anh (Lyrics)', song),
      _video(
        'omv',
        'Nơi Này Có Anh | Official MV',
        song + const Duration(seconds: 8),
        official: true,
      ),
    ]);

    expect(pick?.video.id, 'omv');
  });

  test('the uploader joins the query only when the title lacks the artist', () {
    expect(
      MusicVideoMatcher.searchQuery(
        _track('Sơn Tùng M-TP - Nơi Này Có Anh', song, artist: 'reposter'),
      ),
      'Sơn Tùng M-TP - Nơi Này Có Anh',
    );
    expect(
      MusicVideoMatcher.searchQuery(
        _track('Nơi Này Có Anh', song, artist: 'Sơn Tùng M-TP'),
      ),
      'Sơn Tùng M-TP Nơi Này Có Anh',
    );
  });

  test('marks and punctuation do not keep two titles apart', () {
    expect(MusicVideoMatcher.tokens('CHÚNG TA | Của Tương-Lai (Official MV)'), {
      'chung',
      'ta',
      'cua',
      'tuong',
      'lai',
    });
    // The same words, typed with separate combining marks.
    expect(MusicVideoMatcher.tokens('Chúng Ta'), {'chung', 'ta'});
  });
}
