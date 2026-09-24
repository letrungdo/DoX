import 'dart:convert';

import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/screen/tv/tv_screen.dart';
import 'package:do_x/screen/tv/tv_search_screen.dart';
import 'package:do_x/services/storage_service.dart';
import 'package:do_x/theme/app_theme.dart';
import 'package:do_x/utils/device_type.dart';
import 'package:do_x/view_model/tv/tv_view_model.dart';
import 'package:do_x/widgets/tv_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A handful of channels whose names tell two searches apart.
String _storedChannels() => jsonEncode([
  for (final name in ['VTV1', 'VTV3', 'HTV7', 'THVL1'])
    {
      'country_code': 'VN',
      'slug': name.toLowerCase(),
      'name': name,
      'url': 'https://example.com/$name/index.m3u8',
      'logo': null,
      'categories': <String>[],
      'quality': null,
      'is_geo_blocked': false,
      'is_intermittent': false,
      'headers': <String, String>{},
      'sort_order': 0,
    },
]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await storageService.init();
    // In the preferences: file I/O never finishes on a widget test's clock.
    storageService.debugSetTvPlaylistDirectory(null);
  });

  setUp(() async {
    await storageService.setTvPlaylist('vn', _storedChannels());
    deviceType.isTv = true;
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
  });

  tearDown(() {
    deviceType.isTv = false;
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
  });

  Widget wrap(Widget child) => MaterialApp(
    locale: const Locale('vi'),
    theme: AppTheme.lightTheme,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, widget) => TvShell(child: widget!),
    home: child,
  );

  group('the channel page', () {
    Future<void> pumpPage(WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          ChangeNotifierProvider(
            create: (_) => TvViewModel(),
            child: const TvScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('opens with the remote on the first channel', (tester) async {
      await pumpPage(tester);

      // Not on the country flag up in the app bar, which is what an arrow key
      // finds first if nobody aims the remote.
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'tv-channel-https://example.com/VTV1/index.m3u8',
      );
    });

    testWidgets('searches from the app bar, not from a box on the page', (
      tester,
    ) async {
      await pumpPage(tester);

      // A field on the page is a field the television's full-screen keyboard
      // covers the moment it is used, so the search is a page of its own —
      // reached from this button.
      expect(find.byType(TextField), findsNothing);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byIcon(Icons.search_rounded),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a phone keeps the box on the page', (tester) async {
      deviceType.isTv = false;
      await pumpPage(tester);

      expect(find.byType(TextField), findsOneWidget);
    });
  });

  group('the search page', () {
    late TvViewModel vm;

    Future<void> pumpSearch(WidgetTester tester) async {
      vm = TvViewModel()..initData();
      await tester.pumpWidget(
        wrap(
          ChangeNotifierProvider.value(
            value: vm,
            child: TvSearchScreen(tvVm: vm),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('opens with the remote in the box', (tester) async {
      await pumpSearch(tester);

      // The keyboard is what the page is for, so nobody has to find the box
      // with the D-pad first.
      final field = tester.widget<EditableText>(find.byType(EditableText));
      expect(field.focusNode.hasFocus, isTrue);
      expect(field.focusNode.debugLabel, 'tv-search');
    });

    testWidgets('what is typed filters the results', (tester) async {
      await pumpSearch(tester);
      expect(find.text('VTV1'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'htv');
      await tester.pumpAndSettle();

      expect(find.text('HTV7'), findsOneWidget);
      expect(find.text('VTV1'), findsNothing);
    });

    testWidgets('a channel opened from the results carries the whole list', (
      tester,
    ) async {
      await pumpSearch(tester);
      await tester.enterText(find.byType(TextField), 'htv');
      await tester.pumpAndSettle();

      // What the player is handed. A search usually comes down to one match,
      // and a player given a list of one has no channel list to open and
      // nowhere to move to — OK on the remote does nothing. The query was
      // how the viewer found the channel, not what the remote is shut inside
      // once it is playing.
      expect(vm.channels.length, 1);
      expect(vm.allChannels.length, 4);
    });

    testWidgets('leaving the page puts the whole list back', (tester) async {
      await pumpSearch(tester);
      await tester.enterText(find.byType(TextField), 'htv');
      await tester.pumpAndSettle();
      expect(vm.channels.length, 1);

      // The query belongs to the page, so it goes when the page does: the
      // channel page is the whole country's list again without the viewer
      // having to empty a box that is no longer on screen.
      await tester.pumpWidget(wrap(const SizedBox.shrink()));
      await tester.pumpAndSettle();

      expect(vm.query, isEmpty);
      expect(vm.channels.length, 4);
    });
  });
}
