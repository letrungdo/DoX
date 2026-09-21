import 'dart:convert';

import 'package:do_x/constants/dimens.dart';
import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/screen/tv/tv_screen.dart';
import 'package:do_x/services/storage_service.dart';
import 'package:do_x/theme/app_theme.dart';
import 'package:do_x/utils/device_type.dart';
import 'package:do_x/view_model/tv/tv_view_model.dart';
import 'package:do_x/widgets/neu/neu_chip.dart';
import 'package:do_x/widgets/tv_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What a 1080p television reports: 1920x1080 pixels at a device pixel ratio
/// of 2, which is 960x540 of the units everything in the app is written in.
const _tvSize = Size(1920, 1080);
const _tvPixelRatio = 2.0;

String _storedChannels() => jsonEncode([
  for (var i = 1; i <= 40; i++)
    {
      'country_code': 'VN',
      'slug': 'channel$i',
      'name': 'Kênh Truyền Hình Số $i',
      'url': 'https://example.com/$i/index.m3u8',
      'logo': null,
      'categories': [if (i.isEven) 'General' else 'Sports'],
      'quality': '1080p',
      'is_geo_blocked': i % 5 == 0,
      'is_intermittent': false,
      'headers': <String, String>{},
      'sort_order': i - 1,
    },
]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await storageService.init();
  });

  setUp(() async {
    deviceType.isTv = true;
    await storageService.setTvPlaylist('vn', _storedChannels());
  });

  tearDown(() => deviceType.isTv = false);

  Future<void> pumpTv(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = _tvSize;
    tester.view.devicePixelRatio = _tvPixelRatio;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('vi'),
        theme: AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => TvShell(child: child!),
        home: home,
      ),
    );
    await tester.pumpAndSettle();
  }

  group('The TV page at television size', () {
    testWidgets('lays out with nothing overflowing', (tester) async {
      await pumpTv(
        tester,
        ChangeNotifierProvider(
          create: (_) => TvViewModel(),
          child: const TvScreen(),
        ),
      );

      expect(find.byType(TvScreen), findsOneWidget);
      expect(find.text('Kênh Truyền Hình Số 1'), findsOneWidget);
    });

    testWidgets('a channel name is large enough to read from a sofa', (
      tester,
    ) async {
      await pumpTv(
        tester,
        ChangeNotifierProvider(
          create: (_) => TvViewModel(),
          child: const TvScreen(),
        ),
      );

      final name = find.text('Kênh Truyền Hình Số 1');
      final context = tester.element(name);
      final style = tester.widget<Text>(name).style;
      final drawnAt = MediaQuery.textScalerOf(
        context,
      ).scale(style?.fontSize ?? 14);

      // Google's leanback guidance puts the floor for television body text at
      // 18sp. The card asks for 12, which is a phone size — the whole point
      // of the scale is that nobody has to remember to write a second one.
      expect(drawnAt, greaterThanOrEqualTo(18));
    });

    testWidgets('the category chips still fit the row they sit in', (
      tester,
    ) async {
      await pumpTv(
        tester,
        ChangeNotifierProvider(
          create: (_) => TvViewModel(),
          child: const TvScreen(),
        ),
      );

      final row = find.byType(ListView);
      final chip = find
          .descendant(of: row, matching: find.byType(NeuChip))
          .first;

      // Measured, not laid out. A horizontal list hands its children the
      // row's height as their limit, so a chip that wanted more is silently
      // squeezed into it — and so is the label inside it. Both then measure
      // as fitting however small the row is. The intrinsic height is the one
      // number the constraint does not touch: what the chip would be if the
      // row let it.
      final natural = tester
          .renderObject<RenderBox>(chip)
          .getMaxIntrinsicHeight(double.infinity);

      expect(natural, lessThanOrEqualTo(tester.getSize(row).height));
    });

    testWidgets('still lays out with the largest text a viewer can ask for', (
      tester,
    ) async {
      await pumpTv(
        tester,
        MediaQuery(
          // On top of the television's own floor, which is what a viewer who
          // has turned their TV's text up gets.
          data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
          child: ChangeNotifierProvider(
            create: (_) => TvViewModel(),
            child: const TvScreen(),
          ),
        ),
      );

      expect(find.byType(TvScreen), findsOneWidget);
    });
  });

  group('Television sizing', () {
    test('text is scaled up, but only as far as the layouts allow', () {
      expect(Dimens.tvTextScale, greaterThan(1));

      // Not the 18sp the leanback guidance asks for, and deliberately so:
      // the app's body size is 14, so reaching 18 everywhere means scaling by
      // half again — which on a television emulator broke row after row whose
      // height was chosen once against phone-sized text. Screens that need
      // the full size ask for it themselves, as the channel card does.
      expect(Dimens.tvTextScale, lessThanOrEqualTo(1.25));
    });

    test('the page is allowed more width than a phone', () {
      expect(Dimens.contentMaxWidth, greaterThan(700));

      deviceType.isTv = false;
      expect(Dimens.contentMaxWidth, 700);
    });
  });
}
