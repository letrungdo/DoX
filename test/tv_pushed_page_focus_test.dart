import 'package:do_x/screen/core/screen_state.dart';
import 'package:do_x/utils/device_type.dart';
import 'package:do_x/view_model/core/core_view_model.dart';
import 'package:do_x/widgets/app_bar/app_bar_base.dart';
import 'package:do_x/widgets/app_scaffold.dart';
import 'package:do_x/widgets/tv_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _Vm extends CoreViewModel {}

/// A page shaped like the ones reached from inside a tab: one row of controls
/// near the top and everything below it printed rather than pressable.
class _DetailScreen extends StatefulScreen {
  const _DetailScreen({required this.controller});

  final ScrollController controller;

  @override
  State<_DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends ScreenState<_DetailScreen, _Vm> {
  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: const DoAppBar(title: 'detail'),
      body: SingleChildScrollView(
        controller: widget.controller,
        child: Column(
          children: [
            Row(
              children: [
                for (var i = 0; i < 4; i++)
                  Expanded(
                    child: TextButton(onPressed: () {}, child: Text('chip $i')),
                  ),
              ],
            ),
            for (var i = 0; i < 20; i++)
              SizedBox(height: 60, child: Text('line $i')),
          ],
        ),
      ),
    );
  }
}

Widget _wrap(Widget child) =>
    ChangeNotifierProvider(create: (_) => _Vm(), child: child);

void main() {
  setUp(() => deviceType.isTv = true);
  tearDown(() => deviceType.isTv = false);

  testWidgets('a page pushed inside a tab takes the remote and scrolls', (
    tester,
  ) async {
    final nested = GlobalKey<NavigatorState>();
    final controller = ScrollController();
    addTearDown(controller.dispose);
    final card = FocusNode(debugLabel: 'market card');
    addTearDown(card.dispose);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => TvShell(child: child!),
        // The tab host: a rail beside the tab's own navigator.
        home: AppScaffold(
          bodyHorizontal: false,
          body: Row(
            children: [
              SizedBox(
                width: 120,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < 6; i++)
                      TextButton(onPressed: () {}, child: Text('tab $i')),
                  ],
                ),
              ),
              Expanded(
                child: Navigator(
                  key: nested,
                  onGenerateRoute: (_) => MaterialPageRoute(
                    builder: (_) => AppScaffold(
                      appBar: const DoAppBar(title: 'news'),
                      body: TextButton(
                        focusNode: card,
                        onPressed: () {},
                        child: const Text('a market card'),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    card.requestFocus();
    await tester.pumpAndSettle();

    nested.currentState!.push(
      MaterialPageRoute(
        builder: (_) => _wrap(_DetailScreen(controller: controller)),
      ),
    );
    await tester.pumpAndSettle();

    // The card it was pressed from has gone with its page. Without the page
    // claiming the remote, focus is left on a scope nobody can move out of.
    final landed = FocusManager.instance.primaryFocus;
    expect(landed, isNot(isA<FocusScopeNode>()));
    expect(
      find.descendant(
        of: find.byType(_DetailScreen),
        matching: find.byWidget(landed!.context!.widget),
      ),
      findsOne,
    );

    for (var i = 0; i < 20; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
    }
    expect(controller.offset, controller.position.maxScrollExtent);
    expect(controller.offset, greaterThan(0));
  });

  testWidgets('a page built under a covering one leaves the remote alone', (
    tester,
  ) async {
    final root = GlobalKey<NavigatorState>();
    final nested = GlobalKey<NavigatorState>();
    final controller = ScrollController();
    addTearDown(controller.dispose);
    final onTop = FocusNode(debugLabel: 'on the covering page');
    addTearDown(onTop.dispose);

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: root,
        builder: (context, child) => TvShell(child: child!),
        home: AppScaffold(
          bodyHorizontal: false,
          body: Navigator(
            key: nested,
            onGenerateRoute: (_) => MaterialPageRoute(
              builder: (_) => const AppScaffold(body: Text('news')),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The login screen, over the whole app.
    root.currentState!.push(
      MaterialPageRoute(
        builder: (_) => AppScaffold(
          body: TextButton(
            focusNode: onTop,
            onPressed: () {},
            child: const Text('sign in'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    onTop.requestFocus();
    await tester.pumpAndSettle();

    // A page appearing inside the tab underneath — it is "current" in its own
    // navigator, but the viewer is looking at the login screen.
    nested.currentState!.push(
      MaterialPageRoute(
        builder: (_) => _wrap(_DetailScreen(controller: controller)),
      ),
    );
    await tester.pumpAndSettle();

    // Nothing on the page underneath has the remote: claiming it there is
    // what leaves every press walking a page the viewer cannot see.
    final landed = FocusManager.instance.primaryFocus;
    expect(
      landed?.context?.findAncestorWidgetOfExactType<_DetailScreen>(),
      isNull,
    );
    expect(find.byType(_DetailScreen, skipOffstage: false), findsOne);
  });
}
