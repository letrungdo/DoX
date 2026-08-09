import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/widgets/input/password_field.dart';
import 'package:do_x/widgets/text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  testWidgets('revealing the password keeps what was typed', (tester) async {
    await _pump(tester, const PasswordField(labelText: 'Mật khẩu'));

    await tester.enterText(find.byType(TextFormField), 'secret123');
    await tester.pump();

    // The eye rebuilds the field from its own setState — which used to hand
    // DoTextField a null `value` and let it blank the controller.
    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();

    expect(find.text('secret123'), findsOneWidget);
  });

  testWidgets('a rebuild without a value leaves the text alone', (
    tester,
  ) async {
    final rebuild = ValueNotifier(0);
    addTearDown(rebuild.dispose);

    await _pump(
      tester,
      ValueListenableBuilder<int>(
        valueListenable: rebuild,
        builder: (context, value, _) =>
            DoTextField(labelText: 'Ghi chú $value'),
      ),
    );

    await tester.enterText(find.byType(TextFormField), 'đang gõ dở');
    rebuild.value++;
    await tester.pumpAndSettle();

    expect(find.text('đang gõ dở'), findsOneWidget);
  });

  testWidgets('a new value from the view model still lands', (tester) async {
    final email = ValueNotifier('');
    addTearDown(email.dispose);

    await _pump(
      tester,
      ValueListenableBuilder<String>(
        valueListenable: email,
        builder: (context, value, _) => DoTextField(value: value),
      ),
    );

    // What the login form does once the saved account has been read back.
    email.value = 'do@dox.vn';
    await tester.pumpAndSettle();

    expect(find.text('do@dox.vn'), findsOneWidget);
  });
}
