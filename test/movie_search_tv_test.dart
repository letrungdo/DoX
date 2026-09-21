import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/screen/movie/movie_search_screen.dart';
import 'package:do_x/services/storage_service.dart';
import 'package:do_x/theme/app_theme.dart';
import 'package:do_x/utils/device_type.dart';
import 'package:do_x/view_model/movie/movie_view_model.dart';
import 'package:do_x/widgets/tv_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The movie search page: the box, the results and the way out on a page of
/// their own, which is what a television's full-screen keyboard leaves room
/// for. The view model is handed in idle here, so nothing is fetched.
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

  Future<MovieViewModel> pumpSearch(WidgetTester tester) async {
    final vm = MovieViewModel();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('vi'),
        theme: AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => TvShell(child: child!),
        home: Builder(
          builder: (context) {
            // What `ScreenState` does for a screen's own view model: the
            // loading and error plumbing reaches the page through it, and in
            // the app the browser behind has already handed it over.
            vm.setCurrentContext(context);
            return ChangeNotifierProvider.value(
              value: vm,
              child: MovieSearchScreen(movieVm: vm),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    return vm;
  }

  testWidgets('the page opens with the remote in the box', (tester) async {
    await pumpSearch(tester);

    // The keyboard is what the page is for, so nobody has to find the box with
    // the D-pad first.
    final field = tester.widget<EditableText>(find.byType(EditableText));
    expect(field.focusNode.hasFocus, isTrue);
    expect(field.focusNode.debugLabel, 'movie-search');
  });

  testWidgets('typing asks the library for that title', (tester) async {
    final vm = await pumpSearch(tester);

    await tester.enterText(find.byType(TextField), 'ma');
    // Past the box's own pause, which is what keeps typing a title to one
    // request instead of one per letter.
    await tester.pump(const Duration(milliseconds: 600));

    expect(vm.searchQuery, 'ma');

    // The request itself fails in a test — there is no network — and the view
    // model says so in a dialog, which is dismissed so the page can be torn
    // down cleanly.
    await tester.pumpAndSettle();
    while (find.byType(AlertDialog).evaluate().isNotEmpty) {
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
    }
  });
}
