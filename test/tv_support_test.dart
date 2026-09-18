import 'package:do_x/services/update_service.dart';
import 'package:do_x/theme/app_theme.dart';
import 'package:do_x/utils/device_type.dart';
import 'package:do_x/widgets/focus_ring.dart';
import 'package:do_x/widgets/neu/neu_card.dart';
import 'package:do_x/widgets/tv_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    deviceType.isTv = false;
    deviceType.supportedAbis = const [];
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
  });

  group('picking the APK to update with', () {
    final service = UpdateService();
    final release = <Map<String, dynamic>>[
      {'name': 'app-release.apk', 'browser_download_url': 'legacy'},
      {'name': 'app-release-arm64-v8a.apk', 'browser_download_url': 'arm64'},
      {'name': 'app-tv-armeabi-v7a.apk', 'browser_download_url': 'armv7'},
      {'name': 'do_x.ipa', 'browser_download_url': 'ios'},
    ];

    test('a 32-bit TV box takes the armeabi-v7a build', () {
      deviceType.supportedAbis = const ['armeabi-v7a', 'armeabi'];

      expect(
        service.pickApkForThisDevice(release)?['browser_download_url'],
        'armv7',
      );
    });

    test('a 64-bit phone takes arm64, never the 32-bit build it could run', () {
      // The phone lists armeabi-v7a too, so a naive "first ABI that matches
      // anything" would happily hand it the TV's build.
      deviceType.supportedAbis = const ['arm64-v8a', 'armeabi-v7a', 'armeabi'];

      expect(
        service.pickApkForThisDevice(release)?['browser_download_url'],
        'arm64',
      );
    });

    test('a release from before the split still updates', () {
      deviceType.supportedAbis = const ['arm64-v8a', 'armeabi-v7a'];
      final old = [
        {'name': 'app-release.apk', 'browser_download_url': 'legacy'},
        {'name': 'do_x.ipa', 'browser_download_url': 'ios'},
      ];

      expect(
        service.pickApkForThisDevice(old)?['browser_download_url'],
        'legacy',
      );
    });

    test('a version too old to know about ABIs still lands on arm64', () {
      // Copies of the app already in the wild take the first `.apk` asset the
      // GitHub API hands back, and that API orders assets by name — something
      // it promises nowhere. Handing one of those a 32-bit build would quietly
      // drop a phone onto it, so the names are picked to make that impossible:
      // every APK sorting before the TV build is an arm64 one.
      final byName = release.map((a) => a['name'] as String).toList()..sort();
      final firstApk = byName.firstWhere((name) => name.endsWith('.apk'));

      expect(firstApk, isNot(contains('armeabi-v7a')));
    });

    test('a release carrying no APK at all is not an update', () {
      deviceType.supportedAbis = const ['arm64-v8a'];

      expect(
        service.pickApkForThisDevice([
          {'name': 'do_x.ipa', 'browser_download_url': 'ios'},
        ]),
        isNull,
      );
    });
  });

  group('TvShell', () {
    Future<EdgeInsets> paddingSeenByPages(WidgetTester tester) async {
      late EdgeInsets seen;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(padding: EdgeInsets.only(top: 24)),
          child: TvShell(
            child: Builder(
              builder: (context) {
                seen = MediaQuery.paddingOf(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      return seen;
    }

    testWidgets('adds the overscan margin on a television', (tester) async {
      deviceType.isTv = true;

      expect(
        await paddingSeenByPages(tester),
        const EdgeInsets.fromLTRB(48, 24 + 27, 48, 27),
      );
    });

    testWidgets('leaves a phone exactly as it was', (tester) async {
      expect(await paddingSeenByPages(tester), const EdgeInsets.only(top: 24));
    });
  });

  group('reaching a control with a remote', () {
    testWidgets('the OK button presses a card the D-pad is resting on', (
      tester,
    ) async {
      deviceType.isTv = true;
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      var taps = 0;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: TvShell(
            child: Scaffold(
              body: Center(
                child: NeuCard(
                  onTap: () => taps++,
                  child: const Text('Chi phí chung'),
                ),
              ),
            ),
          ),
        ),
      );

      // The remote walks onto the card — the nearest focus node above the
      // label is the one `NeuPress` installs.
      Focus.of(tester.element(find.text('Chi phí chung'))).requestFocus();
      await tester.pumpAndSettle();

      // …which says so, because a TV has no pointer to show it any other way.
      final ring = tester.widget<FocusRing>(find.byType(FocusRing));
      expect(ring.focused, isTrue);
      // Follows the card's own corner rather than cutting across it.
      expect(ring.radius, 18);

      // KEYCODE_DPAD_CENTER arrives as `select`, which nothing in Flutter's
      // default shortcut map turns into an activation.
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      expect(taps, 1);
    });
  });
}
