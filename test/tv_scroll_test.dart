import 'package:do_x/utils/device_type.dart';
import 'package:do_x/widgets/app_scaffold.dart';
import 'package:do_x/widgets/tv_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// A page shaped like the ones that could not be read to the end: one control
/// at the top, and everything below it printed rather than pressable.
Widget _page(ScrollController controller, FocusNode top) {
  return SingleChildScrollView(
    controller: controller,
    child: Column(
      children: [
        TextButton(
          focusNode: top,
          onPressed: () {},
          child: const Text('the only control'),
        ),
        for (var i = 0; i < 40; i++)
          SizedBox(height: 60, child: Text('line $i')),
      ],
    ),
  );
}

void main() {
  setUp(() => deviceType.isTv = true);
  tearDown(() => deviceType.isTv = false);

  testWidgets('the page scrolls on when the remote has nowhere left to go', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    final top = FocusNode(debugLabel: 'top');
    addTearDown(top.dispose);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => TvShell(child: child!),
        home: Scaffold(body: _page(controller, top)),
      ),
    );
    await tester.pumpAndSettle();

    top.requestFocus();
    await tester.pumpAndSettle();
    expect(controller.offset, 0);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    // Nothing below the button can take the focus, so the arrow moved the
    // page instead — without which everything under it is unreachable.
    expect(controller.offset, greaterThan(0));
    final afterOnePress = controller.offset;

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(controller.offset, lessThan(afterOnePress));
  });

  testWidgets('it stops at the end rather than running past it', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    final top = FocusNode(debugLabel: 'top');
    addTearDown(top.dispose);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => TvShell(child: child!),
        home: Scaffold(body: _page(controller, top)),
      ),
    );
    await tester.pumpAndSettle();
    top.requestFocus();
    await tester.pumpAndSettle();

    for (var i = 0; i < 20; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
    }

    expect(controller.offset, controller.position.maxScrollExtent);
  });

  testWidgets('down stays on the page instead of jumping to the rail', (
    tester,
  ) async {
    // The shape of the tab host: a rail beside a page, both inside the same
    // focus tree, with the rail's lower items sitting below the page's only
    // control. Without a rule the arrow finds them and leaves.
    final controller = ScrollController();
    addTearDown(controller.dispose);
    final onPage = FocusNode(debugLabel: 'on page');
    final railBottom = FocusNode(debugLabel: 'rail bottom');
    addTearDown(onPage.dispose);
    addTearDown(railBottom.dispose);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => TvShell(child: child!),
        home: AppScaffold(
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 100,
                child: Column(
                  children: [
                    const SizedBox(height: 400),
                    TextButton(
                      focusNode: railBottom,
                      onPressed: () {},
                      child: const Text('rail bottom'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: AppScaffold(
                  body: SingleChildScrollView(
                    controller: controller,
                    child: Column(
                      children: [
                        TextButton(
                          focusNode: onPage,
                          onPressed: () {},
                          child: const Text('on page'),
                        ),
                        for (var i = 0; i < 40; i++)
                          SizedBox(height: 60, child: Text('line $i')),
                      ],
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

    onPage.requestFocus();
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    expect(railBottom.hasFocus, isFalse);
    expect(onPage.hasFocus, isTrue);
    expect(controller.offset, greaterThan(0));
  });

  testWidgets('a page keeps the same identity across a rebuild', (
    tester,
  ) async {
    // What the rule above compares. A widget is a new object on every build,
    // so identifying a page by its widget makes every control look like it
    // moved to another page the moment anything redraws — and the arrow gets
    // sent back from wherever it legitimately went.
    final key = GlobalKey();
    Widget tree(Color colour) => MaterialApp(
      home: AppScaffold(
        backgroundColor: colour,
        body: SizedBox(key: key),
      ),
    );

    await tester.pumpWidget(tree(const Color(0xFF000000)));
    await tester.pumpAndSettle();
    final before = TvPageArea.of(key.currentContext);
    expect(before, isNotNull);

    await tester.pumpWidget(tree(const Color(0xFF010101)));
    await tester.pumpAndSettle();

    expect(TvPageArea.of(key.currentContext), same(before));
  });

  testWidgets('a control to move to is still preferred over scrolling', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    final first = FocusNode(debugLabel: 'first');
    final second = FocusNode(debugLabel: 'second');
    addTearDown(first.dispose);
    addTearDown(second.dispose);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => TvShell(child: child!),
        home: Scaffold(
          body: SingleChildScrollView(
            controller: controller,
            child: Column(
              children: [
                TextButton(
                  focusNode: first,
                  onPressed: () {},
                  child: const Text('first'),
                ),
                TextButton(
                  focusNode: second,
                  onPressed: () {},
                  child: const Text('second'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    first.requestFocus();
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    // Going to the next control is what the viewer meant; the page must not
    // slide out from under them as well.
    expect(second.hasFocus, isTrue);
    expect(controller.offset, 0);
  });
}
