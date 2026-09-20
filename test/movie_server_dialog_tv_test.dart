import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/screen/movie/movie_server_dialog.dart';
import 'package:do_x/services/storage_service.dart';
import 'package:do_x/theme/app_theme.dart';
import 'package:do_x/utils/device_type.dart';
import 'package:do_x/widgets/tv_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({
      'movieServers': ['https://a.example', 'https://b.example'],
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

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('vi'),
        theme: AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: TvShell(
          child: Scaffold(body: MovieServerDialog(onServerChanged: () {})),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Whether the remote is sitting in the URL field. The primary focus is
  /// the `Focus` the field installs rather than the [EditableText] itself, so
  /// the field's own node is what has to be asked.
  bool editing(WidgetTester tester) {
    final fields = find.byType(EditableText).evaluate();
    return fields.any(
      (element) => (element.widget as EditableText).focusNode.hasFocus,
    );
  }

  testWidgets('opening the add row puts the remote in the URL field', (
    tester,
  ) async {
    await pump(tester);

    // Park the remote on a control first, which is the only state a TV is ever
    // in — and the state in which the field's own `autofocus` is ignored.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(editing(tester), isFalse);

    await tester.tap(find.byIcon(Icons.add_rounded).first);
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    expect(editing(tester), isTrue);
  });

  testWidgets('the remote can walk back out of the URL field', (tester) async {
    await pump(tester);
    await tester.tap(find.byIcon(Icons.add_rounded).first);
    await tester.pumpAndSettle();
    expect(editing(tester), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    expect(editing(tester), isFalse);
  });
}
