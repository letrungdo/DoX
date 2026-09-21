import 'dart:async';

import 'package:do_x/constants/dimens.dart';
import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/theme/app_theme.dart';
import 'package:do_x/utils/device_type.dart';
import 'package:do_x/widgets/app_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('A page with another one over it', () {
    testWidgets('is out of the remote’s reach until it is back on top', (
      tester,
    ) async {
      final navigator = GlobalKey<NavigatorState>();
      final under = FocusNode(debugLabel: 'under');
      addTearDown(under.dispose);

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          theme: AppTheme.lightTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AppScaffold(
            body: TextButton(
              focusNode: under,
              onPressed: () {},
              child: const Text('underneath'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // On top, the page is reachable as any page is.
      under.requestFocus();
      await tester.pump();
      expect(under.hasFocus, isTrue);

      // Not awaited: the future a push hands back completes when the route
      // is popped, so waiting on it here waits for the end of the test.
      unawaited(
        navigator.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => const AppScaffold(body: Text('on top')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Covered, it may not take the focus back — the remote resting outside
      // both pages would otherwise walk into a row nobody can see.
      expect(under.hasFocus, isFalse);
      under.requestFocus();
      await tester.pump();
      expect(under.hasFocus, isFalse);

      navigator.currentState!.pop();
      await tester.pumpAndSettle();

      under.requestFocus();
      await tester.pump();
      expect(under.hasFocus, isTrue);
    });
  });

  group('The lift under the remote', () {
    setUp(() => deviceType.isTv = true);
    tearDown(() => deviceType.isTv = false);

    /// How much wider [width] is drawn once the remote is on it.
    double grownBy(double width) {
      final scale = (1 + Dimens.tvFocusGrowth / width).clamp(
        1.0,
        Dimens.tvFocusScaleMax,
      );
      return width * scale - width;
    }

    test('is the same on a tile as on a row that spans the page', () {
      // The whole point of measuring it in pixels: a tenth of a menu row is
      // fifty pixels of lurch, and the row swings out past its neighbours.
      expect(grownBy(150), closeTo(Dimens.tvFocusGrowth, 0.01));
      expect(grownBy(870), closeTo(Dimens.tvFocusGrowth, 0.01));
    });

    test('is held back on a control too small to carry it', () {
      // Ten pixels on a 32dp app bar icon would be a third of it.
      expect(grownBy(32), lessThan(Dimens.tvFocusGrowth));
      expect(32 * Dimens.tvFocusScaleMax - 32, closeTo(grownBy(32), 0.01));
    });
  });
}
