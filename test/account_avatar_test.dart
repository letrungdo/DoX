import 'package:do_x/widgets/account_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester, Widget avatar) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: Center(child: avatar)),
    ),
  );
}

void main() {
  testWidgets('an account with no picture shows its initial', (tester) async {
    await _pump(tester, const AccountAvatar(email: 'do@dox.vn'));

    expect(find.text('D'), findsOneWidget);
  });

  testWidgets('an empty address does not crash on the initial', (tester) async {
    await _pump(tester, const AccountAvatar(email: ''));

    expect(find.text('?'), findsOneWidget);
  });

  testWidgets('only a tappable avatar carries the camera badge', (
    tester,
  ) async {
    await _pump(tester, const AccountAvatar(email: 'do@dox.vn'));
    expect(find.byIcon(Icons.photo_camera_rounded), findsNothing);

    await _pump(tester, AccountAvatar(email: 'do@dox.vn', onTap: () {}));
    expect(find.byIcon(Icons.photo_camera_rounded), findsOneWidget);
  });
}
