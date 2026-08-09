import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/screen/account/verify_otp_screen.dart';
import 'package:do_x/view_model/verify_otp_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester) {
  return tester.pumpWidget(
    MaterialApp(
      locale: const Locale('vi'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // The router normally calls `wrappedRoute`, which is what installs the
      // view model the screen reads.
      home: Builder(
        builder: (context) => const VerifyOtpScreen(
          email: 'do@dox.vn',
          purpose: OtpPurpose.recovery,
        ).wrappedRoute(context),
      ),
    ),
  );
}

void main() {
  testWidgets('the code screen names the address the code went to', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.textContaining('do@dox.vn'), findsOneWidget);
  });

  testWidgets('a short code is rejected before anything is sent', (
    tester,
  ) async {
    await _pump(tester);

    await tester.enterText(find.byType(TextFormField), '123');
    await tester.tap(find.text('Xác nhận'));
    await tester.pumpAndSettle();

    // Still on the form, with the complaint shown — no network call was made,
    // which is the point: an unauthenticated Supabase call would have thrown.
    expect(find.text('Vui lòng nhập mã trong email.'), findsOneWidget);
  });
}
