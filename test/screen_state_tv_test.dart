import 'package:do_x/screen/core/screen_state.dart';
import 'package:do_x/utils/device_type.dart';
import 'package:do_x/view_model/core/core_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _Vm extends CoreViewModel {}

class _Screen extends StatefulScreen {
  const _Screen({super.key});

  @override
  State<_Screen> createState() => _ScreenState();
}

class _ScreenState extends ScreenState<_Screen, _Vm> {
  late final FocusScopeNode scope = FocusScope.of(context);

  @override
  Widget build(BuildContext context) => const Focus(child: Text('page'));
}

void main() {
  tearDown(() => deviceType.isTv = false);

  Future<_ScreenState> pump(WidgetTester tester) async {
    final key = GlobalKey<_ScreenState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider(
            create: (_) => _Vm(),
            child: _Screen(key: key),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return key.currentState!;
  }

  testWidgets('a screen on a TV lets the D-pad out of its own route', (
    tester,
  ) async {
    deviceType.isTv = true;

    final state = await pump(tester);

    // Left at the default `stop`, directional focus dies at the route's edge:
    // a tab's page could never reach the rail that sits outside its nested
    // navigator, so the tabs stay unreachable for the whole session.
    expect(
      state.scope.directionalTraversalEdgeBehavior,
      TraversalEdgeBehavior.parentScope,
    );
  });

  testWidgets('a phone is left alone', (tester) async {
    final state = await pump(tester);

    expect(
      state.scope.directionalTraversalEdgeBehavior,
      TraversalEdgeBehavior.stop,
    );
  });
}
