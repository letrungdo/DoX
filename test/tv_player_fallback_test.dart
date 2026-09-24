import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/model/tv_channel.dart';
import 'package:do_x/screen/tv/tv_player_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'fake_video_player_platform.dart';

const _dead = 'https://dead.example.com/vtv1/index.m3u8';
const _alsoDead = 'https://also-dead.example.com/vtv1/index.m3u8';
const _live = 'https://live.example.com/vtv1/index.m3u8';

const _channel = TvChannel(
  id: 'VTV1.vn',
  name: 'VTV1',
  urls: [_dead, _alsoDead, _live],
);

void main() {
  late FakeVideoPlayerPlatform platform;
  final original = VideoPlayerPlatform.instance;

  setUp(() {
    platform = FakeVideoPlayerPlatform(playing: {_live});
    VideoPlayerPlatform.instance = platform;
  });

  tearDown(() => VideoPlayerPlatform.instance = original);

  Future<void> pumpPlayer(WidgetTester tester, TvChannel channel) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: TvPlayerScreen(channel: channel),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('works down the mirrors until one comes up', (tester) async {
    await pumpPlayer(tester, _channel);

    // A link that will not open is not a channel that is off the air: the
    // page tries the ones behind it before it says so.
    expect(platform.opened, [_dead, _alsoDead, _live]);
  });

  testWidgets('a mirror that plays is not an error the viewer sees', (
    tester,
  ) async {
    await pumpPlayer(tester, _channel);

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.retry), findsNothing);
  });

  testWidgets('a channel with no mirror left says so once', (tester) async {
    await pumpPlayer(
      tester,
      const TvChannel(id: 'VTV1.vn', name: 'VTV1', urls: [_dead, _alsoDead]),
    );

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(platform.opened, [_dead, _alsoDead]);
    expect(find.text(l10n.retry), findsOneWidget);
  });

  testWidgets('retry starts again from the best mirror', (tester) async {
    await pumpPlayer(
      tester,
      const TvChannel(id: 'VTV1.vn', name: 'VTV1', urls: [_dead, _alsoDead]),
    );

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.tap(find.text(l10n.retry));
    await tester.pumpAndSettle();

    // Not on from where the last attempt gave up: minutes have passed, and
    // the best link is the one most likely to have come back.
    expect(platform.opened, [_dead, _alsoDead, _dead, _alsoDead]);
  });
  testWidgets('a mirror that never comes up is given up on', (tester) async {
    VideoPlayerPlatform.instance = platform = FakeVideoPlayerPlatform(
      stalls: true,
    );
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: TvPlayerScreen(channel: _channel),
      ),
    );
    await tester.pump();
    expect(platform.opened, [_dead]);

    // A dead link rarely fails outright; it simply never answers, and the
    // viewer would sit on the spinner for as long as the network stack does.
    await tester.pump(const Duration(seconds: 9));
    expect(platform.opened, [_dead, _alsoDead]);
  });

  testWidgets('zapping past channels opens only the one landed on', (
    tester,
  ) async {
    const playlist = [
      TvChannel(id: 'a', name: 'A', urls: ['https://example.com/a.m3u8']),
      TvChannel(id: 'b', name: 'B', urls: ['https://example.com/b.m3u8']),
      TvChannel(id: 'c', name: 'C', urls: ['https://example.com/c.m3u8']),
      TvChannel(id: 'd', name: 'D', urls: ['https://example.com/d.m3u8']),
    ];
    VideoPlayerPlatform.instance = platform = FakeVideoPlayerPlatform(
      playing: {for (final channel in playlist) channel.url},
    );
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: TvPlayerScreen(channel: playlist.first, playlist: playlist),
      ),
    );
    await tester.pumpAndSettle();

    for (var i = 0; i < 3; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.channelUp);
      await tester.pump(const Duration(milliseconds: 50));
    }
    // The banner follows every press at once; the picture waits for the
    // remote to rest.
    expect(find.text('D'), findsWidgets);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    // B and C were walked past, not watched: no player was started for them.
    expect(platform.opened, [playlist.first.url, playlist.last.url]);
  });
}
