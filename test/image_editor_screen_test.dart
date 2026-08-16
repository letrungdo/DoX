import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/screen/image_editor/image_editor_screen.dart';
import 'package:do_x/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester) {
  return tester.pumpWidget(
    MaterialApp(
      locale: const Locale('vi'),
      theme: AppTheme.lightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // The router normally calls `wrappedRoute`, which is what installs the
      // view model the screen reads.
      home: Builder(
        builder: (context) => const ImageEditorScreen().wrappedRoute(context),
      ),
    ),
  );
}

void main() {
  testWidgets('with no picture yet, the page is the two ways of picking one', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.text('Chọn từ thư viện'), findsOneWidget);
    expect(find.text('Chụp ảnh'), findsOneWidget);
  });

  testWidgets('the editing actions stay disabled until there is a picture', (
    tester,
  ) async {
    await _pump(tester);

    IconButton button(IconData icon) =>
        tester.widget<IconButton>(find.widgetWithIcon(IconButton, icon));

    // Sharing nothing, and undoing an edit that was never made, are the two
    // taps an empty editor has to refuse.
    expect(button(Icons.ios_share_rounded).onPressed, isNull);
    expect(button(Icons.undo_rounded).onPressed, isNull);
    // Picking a picture is still on offer from the app bar.
    expect(button(Icons.more_vert_rounded).onPressed, isNotNull);
  });
}
