import 'package:do_x/screen/core/tab_reselect.mixin.dart';
import 'package:do_x/view_model/main_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _Screen extends StatefulWidget {
  const _Screen(this.onRefresh, {this.scrollable = false});

  final VoidCallback onRefresh;

  /// Builds a list long enough to scroll, so the "already at the top?" branch
  /// can be exercised.
  final bool scrollable;

  @override
  State<_Screen> createState() => _ScreenState();
}

class _ScreenState extends State<_Screen> with TabReselect {
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  String get tabRouteName => 'TestRoute';

  @override
  ScrollController? get tabScrollController =>
      widget.scrollable ? _controller : null;

  @override
  Future<void> onTabRefresh() async => widget.onRefresh();

  @override
  Widget build(BuildContext context) {
    if (!widget.scrollable) return const Text('ok');
    return ListView.builder(
      controller: _controller,
      itemCount: 100,
      itemBuilder: (_, index) => SizedBox(height: 100, child: Text('$index')),
    );
  }
}

Future<void> _pump(WidgetTester tester, MainViewModel vm, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ChangeNotifierProvider.value(value: vm, child: child),
      ),
    ),
  );
}

void main() {
  testWidgets('registers with the bottom bar when there is one', (
    tester,
  ) async {
    var refreshed = 0;
    final mainVm = MainViewModel();

    await _pump(tester, mainVm, _Screen(() => refreshed++));
    await mainVm.handleTabReselect('TestRoute');

    expect(refreshed, 1);
  });

  testWidgets('re-tapping a page already at the top refreshes it', (
    tester,
  ) async {
    var refreshed = 0;
    final mainVm = MainViewModel();

    await _pump(tester, mainVm, _Screen(() => refreshed++, scrollable: true));
    await mainVm.handleTabReselect('TestRoute');

    expect(refreshed, 1);
  });

  testWidgets('re-tapping a scrolled page only rides back to the top', (
    tester,
  ) async {
    var refreshed = 0;
    final mainVm = MainViewModel();

    await _pump(tester, mainVm, _Screen(() => refreshed++, scrollable: true));

    final controller = tester
        .state<_ScreenState>(find.byType(_Screen))
        ._controller;
    controller.jumpTo(600);
    await tester.pump();

    final handled = mainVm.handleTabReselect('TestRoute');
    await tester.pumpAndSettle();
    await handled;

    expect(controller.offset, 0);
    // Fresh data mid-scroll would swap the list out under the user.
    expect(refreshed, 0);
  });

  testWidgets('switching into a tab refreshes wherever it was scrolled to', (
    tester,
  ) async {
    var refreshed = 0;
    final mainVm = MainViewModel();

    await _pump(tester, mainVm, _Screen(() => refreshed++, scrollable: true));

    final controller = tester
        .state<_ScreenState>(find.byType(_Screen))
        ._controller;
    controller.jumpTo(600);
    await tester.pump();

    await mainVm.handleTabSwitch('TestRoute');

    expect(refreshed, 1);
    expect(controller.offset, 600);
  });

  testWidgets('builds fine when pushed outside the bottom bar', (tester) async {
    // A menu page is pushed on the root stack, above MainViewModel's provider:
    // there is no tab to re-tap, and looking for one must not throw.
    await tester.pumpWidget(MaterialApp(home: _Screen(() {})));

    expect(tester.takeException(), isNull);
    expect(find.text('ok'), findsOneWidget);
  });
}
