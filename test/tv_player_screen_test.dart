import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/model/tv_channel.dart';
import 'package:do_x/screen/tv/tv_player_screen.dart';
import 'package:do_x/utils/device_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = TvChannel(
  id: 'VTV1.vn',
  name: 'VTV1',
  url: 'https://example.com/vtv1/index.m3u8',
);

/// Three channels in the order the grid showed them, which is the order the
/// remote walks through.
const _playlist = [
  _channel,
  TvChannel(
    id: 'VTV3.vn',
    name: 'VTV3',
    url: 'https://example.com/vtv3/index.m3u8',
  ),
  TvChannel(
    id: 'HTV7.vn',
    name: 'HTV7',
    url: 'https://example.com/htv7/index.m3u8',
  ),
];

void main() {
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

    testWidgets('down moves to the next channel and names it', (tester) async {
      await pumpPlayer(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();

      // Named over the picture: without it, two quick presses leave the
      // viewer with no idea where they have landed until the stream comes up.
      expect(find.text('VTV3'), findsWidgets);
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('up from the first channel wraps to the last', (tester) async {
      await pumpPlayer(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();

      // A remote has no end of the list, and stopping dead at the first
      // channel is the one thing no television does.
      expect(find.text('HTV7'), findsWidgets);
      expect(find.text('3'), findsOneWidget);
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
