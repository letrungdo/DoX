import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/model/tv_channel.dart';
import 'package:do_x/screen/tv/tv_player_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = TvChannel(
  id: 'VTV1.vn',
  name: 'VTV1',
  url: 'https://example.com/vtv1/index.m3u8',
);

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
}
