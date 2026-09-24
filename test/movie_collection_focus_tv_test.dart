import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/screen/movie/movie_screen.dart';
import 'package:do_x/services/storage_service.dart';
import 'package:do_x/theme/app_theme.dart';
import 'package:do_x/utils/device_type.dart';
import 'package:do_x/view_model/movie/movie_view_model.dart';
import 'package:do_x/widgets/tv_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The watch history and favourites buttons in the movie page's app bar. The
/// select button comes and goes with the history, and the remote has to stay
/// on the button it pressed while the bar around it changes shape.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({
      'movieServers': ['https://a.example'],
      'movieBaseUrl': 'https://a.example',
      'primaryMovieServer': 'https://a.example',
    });
    await storageService.init();
  });

  setUp(() {
    deviceType.isTv = true;
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
  });

  tearDown(() {
    deviceType.isTv = false;
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
  });

  /// There is no network in a test, so every load fails and the view model
  /// says so in a dialog — which covers the page and takes it out of the focus
  /// tree. Dismissed, so the remote is back on the page.
  Future<void> dismissErrors(WidgetTester tester) async {
    while (find.byType(Dialog).evaluate().isNotEmpty) {
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
    }
  }

  Future<void> pumpPage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('vi'),
        theme: AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => TvShell(child: child!),
        home: ChangeNotifierProvider(
          create: (_) => MovieViewModel(),
          child: const MovieScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await dismissErrors(tester);
  }

  /// The focus node of the app bar button whose tooltip is [tooltip].
  FocusNode buttonFocus(WidgetTester tester, String tooltip) => Focus.of(
    tester.element(
      find.descendant(of: find.byTooltip(tooltip), matching: find.byType(Icon)),
    ),
  );

  testWidgets('pressing history and favourites keeps the remote on them', (
    tester,
  ) async {
    await pumpPage(tester);
    final l10n = AppLocalizations.of(tester.element(find.byType(MovieScreen)));

    Future<void> press(String tooltip) async {
      final node = buttonFocus(tester, tooltip);
      node.requestFocus();
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, node);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      // Past the shell's own wait before it hands a lost focus to the first
      // control on the page.
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      // The load behind it fails without a network; the dialog saying so
      // hands the focus back to whatever held it when it goes.
      await dismissErrors(tester);
      // The very node that was pressed — rebuilt from scratch, a new button
      // would have a new one and the remote would have fallen to search.
      expect(buttonFocus(tester, tooltip), same(node));
      expect(
        buttonFocus(tester, tooltip).hasPrimaryFocus,
        isTrue,
        reason: 'focus left "$tooltip"',
      );
    }

    // Browse → history: the select button appears in front of it.
    await press(l10n.watchedMovies);
    expect(find.byTooltip(l10n.selectMovies), findsOneWidget);
    // History → favourites: the select button goes again.
    await press(l10n.favoriteMovies);
    expect(find.byTooltip(l10n.selectMovies), findsNothing);
    // Favourites → history → back to browsing, both ways across the change.
    await press(l10n.watchedMovies);
    await press(l10n.watchedMovies);
    expect(find.byTooltip(l10n.selectMovies), findsNothing);
  });
}
