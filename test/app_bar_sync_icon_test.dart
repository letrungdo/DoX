import 'package:do_x/theme/color_theme.dart';
import 'package:do_x/widgets/app_bar/app_bar_sync_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _Vm extends ChangeNotifier {
  bool loading = false;
  void set(bool v) {
    loading = v;
    notifyListeners();
  }
}

void main() {
  SyncRingPainter painterOf(WidgetTester tester) => tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .map((paint) => paint.painter)
      .whereType<SyncRingPainter>()
      .single;

  testWidgets('sweeps while loading, then closes and draws the check', (
    tester,
  ) async {
    final vm = _Vm();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [ColorTheme.light]),
        home: ChangeNotifierProvider.value(
          value: vm,
          child: Scaffold(
            appBar: AppBar(
              title: AppBarSyncIcon<_Vm>(selector: (vm) => vm.loading),
            ),
          ),
        ),
      ),
    );
    // Idle: closed ring, check fully drawn, nothing ticking.
    expect(painterOf(tester).settle, 1);
    expect(painterOf(tester).check, 1);
    expect(tester.hasRunningAnimations, isFalse);

    vm.set(true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(painterOf(tester).settle, 0);
    expect(painterOf(tester).check, 0);
    expect(tester.hasRunningAnimations, isTrue);

    vm.set(false);
    await tester.pump();
    // Mid-settle the check is only partly drawn — it must not pop in whole.
    await tester.pump(const Duration(milliseconds: 330));
    final check = painterOf(tester).check;
    expect(check, greaterThan(0));
    expect(check, lessThan(1));

    await tester.pumpAndSettle();
    expect(painterOf(tester).check, 1);
    // The sweep ticker has to stop once the ring closes, so an idle screen
    // isn't repainting forever.
    expect(tester.hasRunningAnimations, isFalse);
  });
}
