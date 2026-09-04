import 'dart:async';

import 'package:do_x/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('paints loading UI before initialization completes', (
    tester,
  ) async {
    final initialization = Completer<void>();

    await tester.pumpWidget(
      AppBootstrap(
        initialize: () => initialization.future,
        app: const Text('app-ready', textDirection: TextDirection.ltr),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('app-ready'), findsNothing);

    initialization.complete();
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('app-ready'), findsOneWidget);
  });
}
