import 'dart:convert';

import 'package:do_x/constants/storage.dart';
import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/screen/account/app_login_screen.dart';
import 'package:do_x/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('vi'),
      theme: AppTheme.lightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => const AppLoginScreen().wrappedRoute(context),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      StorageKey.supabaseAccount: jsonEncode([
        {'email': 'one@dox.vn', 'password': 'password-one'},
        {'email': 'two@dox.vn', 'password': 'password-two'},
      ]),
    });
  });

  testWidgets('shows every previously successful Do X login', (tester) async {
    await _pump(tester);

    expect(find.text('Tài khoản đã lưu'), findsOneWidget);
    expect(find.text('one@dox.vn'), findsOneWidget);
    expect(find.text('two@dox.vn'), findsOneWidget);
    expect(find.text('password-one'), findsNothing);
    expect(find.text('password-two'), findsNothing);
  });

  testWidgets('can forget one saved login without removing the other', (
    tester,
  ) async {
    await _pump(tester);

    await tester.tap(find.byKey(const ValueKey('forget-one@dox.vn')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xóa'));
    await tester.pumpAndSettle();

    expect(find.text('one@dox.vn'), findsNothing);
    expect(find.text('two@dox.vn'), findsOneWidget);
  });
}
