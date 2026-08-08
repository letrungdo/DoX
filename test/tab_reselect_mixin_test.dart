import 'package:do_x/screen/core/tab_reselect.mixin.dart';
import 'package:do_x/view_model/main_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _Screen extends StatefulWidget {
  const _Screen(this.onReselect);

  final VoidCallback onReselect;

  @override
  State<_Screen> createState() => _ScreenState();
}

class _ScreenState extends State<_Screen> with TabReselect {
  @override
  String get tabRouteName => 'TestRoute';

  @override
  Future<void> onTabReselect() async => widget.onReselect();

  @override
  Widget build(BuildContext context) => const Text('ok');
}

void main() {
  testWidgets('registers with the bottom bar when there is one', (
    tester,
  ) async {
    var reselected = 0;
    final mainVm = MainViewModel();

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider.value(
          value: mainVm,
          child: _Screen(() => reselected++),
        ),
      ),
    );
    await mainVm.handleTabReselect('TestRoute');

    expect(reselected, 1);
  });

  testWidgets('builds fine when pushed outside the bottom bar', (tester) async {
    // A menu page is pushed on the root stack, above MainViewModel's provider:
    // there is no tab to re-tap, and looking for one must not throw.
    await tester.pumpWidget(MaterialApp(home: _Screen(() {})));

    expect(tester.takeException(), isNull);
    expect(find.text('ok'), findsOneWidget);
  });
}
