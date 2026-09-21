import 'dart:convert';

import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/screen/tv/tv_screen.dart';
import 'package:do_x/services/storage_service.dart';
import 'package:do_x/theme/app_theme.dart';
import 'package:do_x/utils/device_type.dart';
import 'package:do_x/view_model/tv/tv_view_model.dart';
import 'package:do_x/widgets/tv_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  bool inSearchField(WidgetTester tester) {
    return find
        .byType(EditableText)
        .evaluate()
        .map((e) => (e.widget as EditableText).focusNode)
        .any((node) => node.hasFocus && node.debugLabel == 'tv-search');
  }

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('vi'),
        theme: AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => TvShell(child: child!),
        home: ChangeNotifierProvider(
          create: (_) => TvViewModel(),
          child: const TvScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Presses the bar at the top of the page, which is what OK on it does.
  Future<void> openSearch(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.search_rounded));
    await tester.pumpAndSettle();
  }

  testWidgets('the page opens with the remote on the first channel', (
    tester,
  ) async {
    await pumpPage(tester);

    // Not on the country flag up in the app bar, which is what an arrow key
    // finds first if nobody aims the remote.
    final focused = FocusManager.instance.primaryFocus;
    expect(
      focused?.debugLabel,
      'tv-channel-https://example.com/VTV1/index.m3u8',
    );
  });

  testWidgets('the page carries a bar rather than a box', (tester) async {
    await pumpPage(tester);

    // A field on the page is a field the television's full-screen keyboard
    // covers the moment it is used.
    expect(find.byType(TextField), findsNothing);
    expect(find.byIcon(Icons.search_rounded), findsOneWidget);
  });

  testWidgets('OK on the bar opens the search with the remote in it', (
    tester,
  ) async {
    await pumpPage(tester);
    await openSearch(tester);

    expect(find.byType(TextField), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    expect(inSearchField(tester), isTrue);
  });

  testWidgets('what is typed filters the results', (tester) async {
    await pumpPage(tester);
    await openSearch(tester);

    await tester.enterText(find.byType(TextField), 'htv');
    await tester.pumpAndSettle();

    // The page behind is the same list, so the match shows there too — it is
    // simply covered by the layer.
    expect(find.text('HTV7'), findsWidgets);
    expect(find.text('VTV1'), findsNothing);
  });

  testWidgets('Back closes the search and brings the whole list back', (
    tester,
  ) async {
    await pumpPage(tester);
    await openSearch(tester);
    await tester.enterText(find.byType(TextField), 'htv');
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    // The query goes with the layer: a filter left on a page with no search
    // box on it is one the viewer can neither see nor undo.
    expect(find.byType(TextField), findsNothing);
    expect(find.text('VTV1'), findsOneWidget);
    expect(find.text('HTV7'), findsOneWidget);
  });

  testWidgets('the back button closes it too', (tester) async {
    await pumpPage(tester);
    await openSearch(tester);

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
    expect(find.text('VTV1'), findsOneWidget);
  });

  testWidgets('the remote’s own search key opens it', (tester) async {
    await pumpPage(tester);

    // A key is read from whatever holds the focus upwards, so the remote has
    // to be on the page first — which on a television it always is.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.browserSearch);
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    expect(inSearchField(tester), isTrue);
  });

  testWidgets('a phone keeps the box on the page', (tester) async {
    deviceType.isTv = false;
    await pumpPage(tester);

    expect(find.byType(TextField), findsOneWidget);
  });
}
