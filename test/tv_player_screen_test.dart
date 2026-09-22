import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/model/tv_channel.dart';
import 'package:do_x/screen/tv/tv_player_screen.dart';
import 'package:do_x/theme/app_theme.dart';
import 'package:do_x/utils/device_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'fake_video_player_platform.dart';

const _channel = TvChannel(
  id: 'VTV1.vn',
  name: 'VTV1',
  urls: ['https://example.com/vtv1/index.m3u8'],
);

/// Three channels in the order the grid showed them, which is the order the
/// remote walks through.
const _playlist = [
  _channel,
  TvChannel(
    id: 'VTV3.vn',
    name: 'VTV3',
    urls: ['https://example.com/vtv3/index.m3u8'],
  ),
  TvChannel(
    id: 'HTV7.vn',
    name: 'HTV7',
    urls: ['https://example.com/htv7/index.m3u8'],
  ),
];

/// Whether the channel page lets the system pop it — which is what decides
/// that a phone's swipe-back gesture works at all.
bool _canPopOf(WidgetTester tester) {
  final scope = tester
      .widgetList(find.byWidgetPredicate((widget) => widget is PopScope))
      .whereType<PopScope<dynamic>>()
      .single;
  return scope.canPop;
}

/// How far up the overlay over the picture is.
double _controlsOpacity(WidgetTester tester) {
  return tester
      .widgetList<AnimatedOpacity>(find.byType(AnimatedOpacity))
      .first
      .opacity;
}

void main() {
  // Every one of these is about a channel that is still trying to come up —
  // the state the page is in for its first seconds, and the one the remote
  // has to keep working in. Without a stand-in player the page would drop
  // straight into the error state instead.
  final original = VideoPlayerPlatform.instance;
  setUp(
    () => VideoPlayerPlatform.instance = FakeVideoPlayerPlatform(stalls: true),
  );
  tearDown(() => VideoPlayerPlatform.instance = original);

  testWidgets(
    'a channel that has not come up yet keeps its way out on screen',
    (tester) async {
      // There is no platform player in a test, so the stream never comes up —
      // which is the state worth pinning: the controls do not fade out from
      // under a channel that is still trying, leaving a black screen with no
      // back button on a device whose only input is a remote.
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: TvPlayerScreen(channel: _channel),
        ),
      );
      await tester.pump();
      // Past the controls' own timeout, which a loading channel must not obey.
      await tester.pump(const Duration(seconds: 10));

      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
      expect(find.text(_channel.name), findsOneWidget);
    },
  );

  testWidgets('a phone can still swipe the channel away', (tester) async {
    // `canPop: false` takes the swipe-back gesture with it, and on a phone
    // that gesture is the way out of a full-screen page. Nothing is being
    // held back here: no list is open and the channel is the one the page
    // was opened on.
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: TvPlayerScreen(channel: _channel, playlist: _playlist),
      ),
    );
    await tester.pump();

    expect(_canPopOf(tester), isTrue);
  });

  group('The remote, on the picture', () {
    setUp(() => deviceType.isTv = true);
    tearDown(() => deviceType.isTv = false);

    Future<void> pumpPlayer(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const TvPlayerScreen(channel: _channel, playlist: _playlist),
        ),
      );
      await tester.pump();
    }

    testWidgets('an arrow brings the overlay down, not the channel grid', (
      tester,
    ) async {
      // A channel that comes up, because the controls of one still trying
      // stay put on purpose — they are its only way out.
      VideoPlayerPlatform.instance = FakeVideoPlayerPlatform(
        playing: {_channel.urls.first},
      );
      await pumpPlayer(tester);
      // Past the timeout the controls start on, so what is on screen is
      // what the key brought back rather than what was already there.
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      expect(_controlsOpacity(tester), 0);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();

      // OK is already the way to the grid, so the arrows are spent on the
      // one thing the page otherwise has no key for.
      expect(_controlsOpacity(tester), 1);
      expect(find.byType(GridView), findsNothing);
    });

    testWidgets('a second arrow hands the overlay the remote', (tester) async {
      VideoPlayerPlatform.instance = FakeVideoPlayerPlatform(
        playing: {_channel.urls.first},
      );
      await pumpPlayer(tester);
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      // The first press is for looking: the picture keeps the keys, so the
      // grid, the channel pair and the keypad all still answer.
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'tv-video');

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'tv-back');

      // And the overlay still goes away on its own, taking the remote back
      // to the picture with it — a button resting under the focus is no
      // reason to leave the bar over the programme for ever.
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      expect(_controlsOpacity(tester), 0);
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'tv-video');
    });

    testWidgets('CH- from the first channel wraps to the last', (tester) async {
      await pumpPlayer(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.channelDown);
      await tester.pump();

      // A remote has no end of the list, and stopping dead at the first
      // channel is the one thing no television does.
      expect(find.text('HTV7'), findsWidgets);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('the skip pair changes channel as well', (tester) async {
      await pumpPlayer(tester);

      // What a recorder's remote is printed with. There is no track to skip
      // on a live channel, and the buttons sit where a thumb expects to
      // change channel from.
      await tester.sendKeyEvent(LogicalKeyboardKey.mediaTrackNext);
      await tester.pump();
      expect(find.text('VTV3'), findsWidgets);

      await tester.sendKeyEvent(LogicalKeyboardKey.mediaTrackPrevious);
      await tester.pump();
      expect(find.text('VTV1'), findsWidgets);
    });

    testWidgets('OK brings the channel list over the picture', (tester) async {
      await pumpPlayer(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();

      // Every channel is listed, and the picture is still behind it.
      for (final channel in _playlist) {
        expect(find.text(channel.name), findsWidgets);
      }

      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      expect(find.text('HTV7'), findsNothing);
    });

    testWidgets('the remote’s own channel buttons move channel', (
      tester,
    ) async {
      await pumpPlayer(tester);

      // What a television remote sends, and what the arrows on a game-pad
      // style remote do not: `CH+` is the next channel *number*, so it goes
      // the opposite way from the arrow that walks up the list.
      await tester.sendKeyEvent(LogicalKeyboardKey.channelUp);
      await tester.pump();
      expect(find.text('VTV3'), findsWidgets);

      await tester.sendKeyEvent(LogicalKeyboardKey.channelDown);
      await tester.pump();
      expect(find.text('VTV1'), findsWidgets);
    });

    testWidgets('typing a number on the keypad opens that channel', (
      tester,
    ) async {
      await pumpPlayer(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
      await tester.pump();

      // Three channels, so one digit is the whole number and there is
      // nothing to wait for.
      expect(find.text('HTV7'), findsWidgets);
    });

    testWidgets('two digits are one channel number, not two channels', (
      tester,
    ) async {
      final long = [
        for (var i = 1; i <= 20; i++)
          TvChannel(
            id: 'ch$i',
            name: 'Channel $i',
            urls: ['https://example.com/$i/index.m3u8'],
          ),
      ];
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: TvPlayerScreen(channel: long.first, playlist: long),
        ),
      );
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
      await tester.pump();
      // Still waiting: `1` could be the start of `12`, so nothing has moved
      // and what has been typed is on screen instead.
      expect(find.text('1'), findsOneWidget);
      expect(find.text('Channel 1'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
      await tester.pump();

      // Twenty channels, so two digits is as long as a number gets and
      // there is nothing left to wait for.
      expect(find.text('Channel 12'), findsWidgets);
    });

    testWidgets('a single digit is acted on once the viewer stops typing', (
      tester,
    ) async {
      final long = [
        for (var i = 1; i <= 20; i++)
          TvChannel(
            id: 'ch$i',
            name: 'Channel $i',
            urls: ['https://example.com/$i/index.m3u8'],
          ),
      ];
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: TvPlayerScreen(channel: long.first, playlist: long),
        ),
      );
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.digit7);
      await tester.pump();
      expect(find.text('Channel 7'), findsNothing);

      // The pause every television keypad has.
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Channel 7'), findsWidgets);
    });

    testWidgets('a number no channel has is forgotten', (tester) async {
      await pumpPlayer(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.digit9);
      await tester.pump();

      // A television does not explain that channel 9 is not a channel; it
      // goes back to what was on.
      expect(find.text('VTV1'), findsWidgets);
      expect(find.text('9'), findsNothing);
    });

    testWidgets('the back button is not a stop for the remote', (tester) async {
      await pumpPlayer(tester);

      // It is there to say what the remote's own Back key does. Taking the
      // focus into it would take the channel buttons and the keypad away
      // with it, which are the whole point of the page.
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.channelUp);
      await tester.pump();
      expect(find.text('VTV3'), findsWidgets);
    });

    /// A playlist long enough to have three-digit channel numbers and to put
    /// the channel playing well below the first screenful of the list.
    List<TvChannel> longPlaylist() => [
      for (var i = 1; i <= 150; i++)
        TvChannel(
          id: 'ch$i',
          name: 'Channel $i',
          urls: ['https://example.com/$i/index.m3u8'],
        ),
    ];

    Future<List<TvChannel>> pumpLongPlayer(WidgetTester tester) async {
      final playlist = longPlaylist();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: TvPlayerScreen(channel: playlist[99], playlist: playlist),
        ),
      );
      await tester.pump();
      return playlist;
    }

    testWidgets('the list opens on the channel playing', (tester) async {
      await pumpLongPlayer(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();

      // Opening at the top of a 150-channel list would leave the viewer
      // scrolling to find out where they already are.
      expect(find.text('Channel 100'), findsWidgets);
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'tv-current-channel',
      );
    });

    testWidgets('every channel is a card with its number on it', (
      tester,
    ) async {
      await pumpLongPlayer(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();

      // The number is the one the keypad dials, so it is on the card the
      // viewer is looking at rather than only in the banner.
      expect(find.text('100'), findsOneWidget);
      expect(
        tester.widget<GridView>(find.byType(GridView)).semanticChildCount,
        150,
      );
    });

    testWidgets('the grid is laid over the picture, not on top of it', (
      tester,
    ) async {
      const withQuality = [
        TvChannel(
          id: 'VTV1.vn',
          name: 'VTV1',
          urls: ['https://example.com/vtv1/index.m3u8'],
          quality: '1080p',
        ),
        TvChannel(
          id: 'VTV3.vn',
          name: 'VTV3',
          urls: ['https://example.com/vtv3/index.m3u8'],
          quality: '720p',
        ),
      ];
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: TvPlayerScreen(
            channel: withQuality.first,
            playlist: withQuality,
          ),
        ),
      );
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();

      // Nothing opaque between the viewer and the programme: they are still
      // watching it while they choose.
      final opaque = find.descendant(
        of: find.byType(GridView),
        matching: find.byWidgetPredicate(
          (widget) => widget is ColoredBox && widget.color.a == 1,
        ),
      );
      expect(opaque, findsNothing);
      expect(
        tester
            .widgetList<ColoredBox>(find.byType(ColoredBox))
            .every((box) => box.color.a < 1),
        isTrue,
      );
      // And no resolution on the cards: this is a channel being picked, not
      // two streams being compared.
      expect(find.text('1080p'), findsNothing);
      expect(find.text('720p'), findsNothing);
    });

    testWidgets('an open grid holds the page back so Back can close it', (
      tester,
    ) async {
      await pumpPlayer(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();

      expect(_canPopOf(tester), isFalse);
    });

    testWidgets('Back closes the list instead of leaving the channel', (
      tester,
    ) async {
      await pumpLongPlayer(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      expect(find.byType(GridView), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      // The grid is gone and the channel is still on: Back was pointed at
      // the grid while it was open.
      expect(find.byType(GridView), findsNothing);
      expect(find.byType(TvPlayerScreen), findsOneWidget);
    });

    testWidgets('a single channel still answers the arrows', (tester) async {
      // Opened from a link, there is no grid to open and nothing to change
      // channel to — the arrows still bring the overlay down.
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: TvPlayerScreen(channel: _channel),
        ),
      );
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();

      expect(find.text('VTV1'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    });
  });
}
