import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/screen/electric_screen.dart';
import 'package:do_x/services/storage_service.dart';
import 'package:do_x/theme/app_theme.dart';
import 'package:do_x/view_model/electric_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Opens the add-account dialog the way the page does.
Future<void> _openDialog(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('vi'),
      theme: AppTheme.lightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ChangeNotifierProvider(
        create: (_) => ElectricViewModel(),
        child: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showElectricAddAccountDialog(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await storageService.init();
  });

  testWidgets('the username field asks the keyboard to carry on', (
    tester,
  ) async {
    await _openDialog(tester);

    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(2));

    // This is what the fix is: the field it is *sent* moves the focus on its
    // own, so what decides whether the form can be filled in is which action
    // the field asks the keyboard for. Left unset, the button only closes the
    // keyboard — which on a television, where it covers the whole screen,
    // drops the user back on a form with no idea where the remote is.
    expect(
      tester.widget<TextField>(fields.first).textInputAction,
      TextInputAction.next,
    );
    expect(
      tester.widget<TextField>(fields.last).textInputAction,
      TextInputAction.done,
    );
  });

  testWidgets('Next from the username lands on the password', (tester) async {
    await _openDialog(tester);

    await tester.tap(find.byType(TextField).first);
    await tester.pumpAndSettle();
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pumpAndSettle();

    // Nothing focusable may come between the two fields: "next" walks the
    // traversal order, not the pair.
    final editables = tester
        .widgetList<EditableText>(find.byType(EditableText))
        .toList();
    expect(editables.length, 2);
    expect(editables.first.focusNode.hasFocus, isFalse);
    expect(editables.last.focusNode.hasFocus, isTrue);
  });
}
