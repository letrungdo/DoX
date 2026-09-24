import 'dart:convert';

import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/screen/tv/tv_screen.dart';
import 'package:do_x/services/storage_service.dart';
import 'package:do_x/theme/app_theme.dart';
import 'package:do_x/view_model/tv/tv_view_model.dart';
import 'package:do_x/widgets/tv_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Enough channels that the grid is taller than the viewport and can be
/// scrolled, in the shape the `tv_channels` table hands them over in.
String _storedChannels() => jsonEncode([
  for (var i = 1; i <= 60; i++)
    {
      'country_code': 'VN',
      'slug': 'channel$i',
      'name': 'Channel $i',
      'url': 'https://example.com/$i/index.m3u8',
      'logo': null,
      'categories': ['General'],
      'quality': null,
      'is_geo_blocked': false,
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
    // In the preferences: file I/O never finishes on a widget test's clock.
    storageService.debugSetTvPlaylistDirectory(null);
  });

  setUp(() async {
    // Seeded as a fresh copy so the page has its channels without a network
    // round trip, which is the state the test is about.
    await storageService.setTvPlaylist('vn', _storedChannels());
  });

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

  testWidgets('the search box stays put while the grid scrolls', (
    tester,
  ) async {
    await pumpPage(tester);

    final field = find.byType(TextField);
    expect(field, findsOneWidget);
    expect(find.text('Channel 1'), findsOneWidget);
    final restingAt = tester.getTopLeft(field);

    await tester.fling(
      find.byType(CustomScrollView),
      const Offset(0, -600),
      1000,
    );
    await tester.pumpAndSettle();

    // The grid moved on and the box did not: it is how anyone reaches a
    // channel in a list this long, so it cannot scroll away with the rows.
    expect(find.text('Channel 1'), findsNothing);
    expect(field, findsOneWidget);
    expect(tester.getTopLeft(field), restingAt);
  });

  testWidgets('typing in it filters the grid underneath', (tester) async {
    await pumpPage(tester);

    await tester.enterText(find.byType(TextField), 'Channel 42');
    await tester.pumpAndSettle();

    // Scoped to the grid: the words are in the box the user just typed them
    // into as well, and that match says nothing about the filter.
    Finder inGrid(String name) => find.descendant(
      of: find.byType(CustomScrollView),
      matching: find.text(name),
    );
    expect(inGrid('Channel 42'), findsOneWidget);
    expect(inGrid('Channel 1'), findsNothing);
  });
}
