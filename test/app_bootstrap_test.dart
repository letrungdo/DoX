import 'dart:async';

import 'package:do_x/main.dart';
import 'package:do_x/theme/app_theme.dart';
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

  testWidgets('the loading screen opens in the theme that was chosen', (
    tester,
  ) async {
    // The white flash this pins down: the loading screen is the first thing
    // on screen, and a light one in front of someone who chose dark is a
    // flash of the wrong colour on every single launch.
    await tester.pumpWidget(
      AppBootstrap(
        initialize: () => Completer<void>().future,
        themeMode: ThemeMode.dark,
        app: const SizedBox.shrink(),
      ),
    );

    final splash = tester.widget<ColoredBox>(find.byType(ColoredBox).first);
    expect(splash.color, AppTheme.darkTheme.scaffoldBackgroundColor);
  });

  testWidgets('and in the light one when that is the choice', (tester) async {
    await tester.pumpWidget(
      AppBootstrap(
        initialize: () => Completer<void>().future,
        themeMode: ThemeMode.light,
        app: const SizedBox.shrink(),
      ),
    );

    final splash = tester.widget<ColoredBox>(find.byType(ColoredBox).first);
    expect(splash.color, AppTheme.lightTheme.scaffoldBackgroundColor);
  });
}
