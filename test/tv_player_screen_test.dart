import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/model/tv_channel.dart';
import 'package:do_x/screen/tv/tv_player_screen.dart';
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

  group('The remote, on the picture', () {
    setUp(() => deviceType.isTv = true);
    tearDown(() => deviceType.isTv = false);

    Future<void> pumpPlayer(WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: TvPlayerScreen(channel: _channel, playlist: _playlist),
        ),
      );
      await tester.pump();
    }

    testWidgets('down brings the channel list up, without changing channel', (
      tester,
    ) async {
      await pumpPlayer(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();

      // The remote already has a pair of keys that change channel, so the
      // arrows are better spent on the list, where the viewer can see what
      // they are moving to instead of hopping blind.
      expect(find.byType(ListView), findsOneWidget);
      expect(find.text('VTV3'), findsWidgets);
      expect(find.text('VTV1'), findsWidgets);
    });

    testWidgets('up brings it up too, and a second press leaves it up', (
      tester,
    ) async {
      await pumpPlayer(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(find.byType(ListView), findsOneWidget);

      // The list holds the arrows once it is open, so a second press walks
      // through it rather than closing it under the viewer.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(find.byType(ListView), findsOneWidget);
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

    testWidgets('a three-digit channel number stays on one line', (
      tester,
    ) async {
      await pumpLongPlayer(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();

      final number = tester.widget<Text>(
        find.descendant(of: find.byType(ListView), matching: find.text('100')),
      );
      expect(number.maxLines, 1);
      expect(number.softWrap, isFalse);
    });

    testWidgets('the list keeps going past the end of the playlist', (
      tester,
    ) async {
      await pumpLongPlayer(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();

      // Past the last channel the list starts the playlist again, the way the
      // channel keys wrap rather than stopping dead.
      expect(
        tester.widget<ListView>(find.byType(ListView)).semanticChildCount,
        greaterThan(150),
      );

      // Well past channel 150 from channel 100, and there is still list left.
      await tester.drag(find.byType(ListView), const Offset(0, -4000));
      await tester.pumpAndSettle();
      expect(find.textContaining('Channel '), findsWidgets);
    });

    testWidgets('Back closes the list instead of leaving the channel', (
      tester,
    ) async {
      await pumpLongPlayer(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      expect(find.byType(ListView), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      // The list is gone and the channel is still on: Back was pointed at the
      // list while it was open.
      expect(find.byType(ListView), findsNothing);
      expect(find.byType(TvPlayerScreen), findsOneWidget);
    });

    testWidgets('a single channel leaves the arrows to the controls', (
      tester,
    ) async {
      // Opened from a link, there are no neighbouring channels to move to,
      // so up and down go back to being the way to reach the controls.
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
