import 'package:do_x/constants/dimens.dart';
import 'package:do_x/constants/enum/app_page.dart';
import 'package:do_x/services/update_service.dart';
import 'package:do_x/theme/app_theme.dart';
import 'package:do_x/utils/device_type.dart';
import 'package:do_x/view_model/app_view_model.dart';
import 'package:do_x/widgets/app_scaffold.dart';
import 'package:do_x/widgets/neu/neu_card.dart';
import 'package:do_x/widgets/tv_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('defaults a new install starts with', () {
    test('Movies is a tab, right after the news', () {
      final layout = AppPage.sanitize(null, null);

      expect(layout.tabs.take(2), [AppPage.news, AppPage.movie]);
      expect(layout.menu, isNot(contains(AppPage.movie)));
    });

    test('a television is not offered the pages it cannot run', () {
      deviceType.isTv = true;
      final layout = AppPage.sanitize(
        // Even if a layout saved on a phone puts them front and centre.
        [AppPage.myLife.name, AppPage.imageEditor.name],
        [AppPage.fengShui.name],
      );

      final everywhere = [...layout.tabs, ...layout.menu];
      expect(everywhere, isNot(contains(AppPage.myLife)));
      expect(everywhere, isNot(contains(AppPage.fengShui)));
      expect(everywhere, isNot(contains(AppPage.imageEditor)));
      expect(everywhere, contains(AppPage.movie));
    });

    test('a phone keeps them', () {
      final everywhere = [
        ...AppPage.sanitize(null, null).tabs,
        ...AppPage.sanitize(null, null).menu,
      ];

      expect(everywhere, contains(AppPage.myLife));
      expect(everywhere, contains(AppPage.fengShui));
      expect(everywhere, contains(AppPage.imageEditor));
    });

    test('the app speaks Vietnamese', () {
      // `supportedLocales.first` is English only because the generator sorts
      // the locales by name, which is no reason to greet anyone in it.
      expect(AppViewModel.defaultLocale, const Locale('vi'));
    });
  });

  tearDown(() {
    deviceType.isTv = false;
    deviceType.supportedAbis = const [];
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
  });

  group('picking the APK to update with', () {
    final service = UpdateService();
    final release = <Map<String, dynamic>>[
      {'name': 'app-release.apk', 'browser_download_url': 'legacy'},
      {'name': 'app-release-arm64-v8a.apk', 'browser_download_url': 'arm64'},
      {'name': 'app-tv-armeabi-v7a.apk', 'browser_download_url': 'armv7'},
      {'name': 'do_x.ipa', 'browser_download_url': 'ios'},
    ];

    test('a 32-bit TV box takes the armeabi-v7a build', () {
      deviceType.supportedAbis = const ['armeabi-v7a', 'armeabi'];

      expect(
        service.pickApkForThisDevice(release)?['browser_download_url'],
        'armv7',
      );
    });

    test('a 64-bit phone takes arm64, never the 32-bit build it could run', () {
      // The phone lists armeabi-v7a too, so a naive "first ABI that matches
      // anything" would happily hand it the TV's build.
      deviceType.supportedAbis = const ['arm64-v8a', 'armeabi-v7a', 'armeabi'];

      expect(
        service.pickApkForThisDevice(release)?['browser_download_url'],
        'arm64',
      );
    });

    test('a release from before the split still updates', () {
      deviceType.supportedAbis = const ['arm64-v8a', 'armeabi-v7a'];
      final old = [
        {'name': 'app-release.apk', 'browser_download_url': 'legacy'},
        {'name': 'do_x.ipa', 'browser_download_url': 'ios'},
      ];

      expect(
        service.pickApkForThisDevice(old)?['browser_download_url'],
        'legacy',
      );
    });

    test('a version too old to know about ABIs still lands on arm64', () {
      // Copies of the app already in the wild take the first `.apk` asset the
      // GitHub API hands back, and that API orders assets by name — something
      // it promises nowhere. Handing one of those a 32-bit build would quietly
      // drop a phone onto it, so the names are picked to make that impossible:
      // every APK sorting before the TV build is an arm64 one.
      final byName = release.map((a) => a['name'] as String).toList()..sort();
      final firstApk = byName.firstWhere((name) => name.endsWith('.apk'));

      expect(firstApk, isNot(contains('armeabi-v7a')));
    });

    test('a release carrying no APK at all is not an update', () {
      deviceType.supportedAbis = const ['arm64-v8a'];

      expect(
        service.pickApkForThisDevice([
          {'name': 'do_x.ipa', 'browser_download_url': 'ios'},
        ]),
        isNull,
      );
    });
  });

  group('TvShell', () {
    Future<EdgeInsets> paddingSeenByPages(WidgetTester tester) async {
      late EdgeInsets seen;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(padding: EdgeInsets.only(top: 24)),
          child: TvShell(
            child: Builder(
              builder: (context) {
                seen = MediaQuery.paddingOf(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      return seen;
    }

    testWidgets('adds the overscan margin on a television', (tester) async {
      deviceType.isTv = true;

      expect(
        await paddingSeenByPages(tester),
        const EdgeInsets.fromLTRB(48, 24 + 27, 48, 27),
      );
    });

    testWidgets('leaves a phone exactly as it was', (tester) async {
      expect(await paddingSeenByPages(tester), const EdgeInsets.only(top: 24));
    });
  });

  group('seeing where the remote is', () {
    /// The rect of the outline `TvShell` paints, or null when it paints none.
    Rect? outline() {
      final found = find
          .byType(Positioned)
          .evaluate()
          .where(
            (element) => (element.widget as Positioned).child is IgnorePointer,
          );
      if (found.isEmpty) return null;
      final positioned = found.first.widget as Positioned;
      return Rect.fromLTWH(
        positioned.left!,
        positioned.top!,
        positioned.width!,
        positioned.height!,
      );
    }

    testWidgets('an outline follows the focus onto any widget, control or not', (
      tester,
    ) async {
      deviceType.isTv = true;
      final first = FocusNode(debugLabel: 'first');
      final second = FocusNode(debugLabel: 'second');
      addTearDown(first.dispose);
      addTearDown(second.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: TvShell(
            child: Scaffold(
              body: Column(
                children: [
                  // Deliberately not a button: a page made of plain rows has to
                  // show the remote's position too.
                  Focus(
                    focusNode: first,
                    child: const SizedBox(height: 50, width: 200),
                  ),
                  Focus(
                    focusNode: second,
                    child: const SizedBox(height: 50, width: 200),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(outline(), isNull, reason: 'nothing focused yet');

      first.requestFocus();
      await tester.pumpAndSettle();
      final onFirst = outline();
      expect(onFirst, isNotNull);
      expect(onFirst!.inflate(-Dimens.focusOutlineGap), first.rect);

      second.requestFocus();
      await tester.pumpAndSettle();
      expect(outline(), isNot(onFirst));
    });

    testWidgets('a phone is left without one', (tester) async {
      final node = FocusNode(debugLabel: 'only');
      addTearDown(node.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: TvShell(
            child: Scaffold(
              body: Focus(
                focusNode: node,
                child: const SizedBox(height: 50, width: 200),
              ),
            ),
          ),
        ),
      );
      node.requestFocus();
      await tester.pumpAndSettle();

      expect(node.hasPrimaryFocus, isTrue);
      expect(outline(), isNull);
    });
  });

  group('what the remote is allowed to stop on', () {
    testWidgets('a row that does nothing is skipped for the control inside it', (
      tester,
    ) async {
      deviceType.isTv = true;
      var opened = 0;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: TvShell(
            child: Scaffold(
              body: ListView(
                children: [
                  // The shape of every settings row: an untappable tile whose
                  // whole point is the control it carries.
                  ListTile(
                    title: const Text('Ngôn ngữ'),
                    trailing: TextButton(
                      onPressed: () => opened++,
                      child: const Text('Tiếng Việt'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();

      // `NavigationMode.directional` would have parked the remote on the tile,
      // which has no `onTap`, leaving OK to do nothing at all.
      expect(opened, 1);
    });
  });

  group('losing the control the remote was on', () {
    testWidgets('the remote is put back on the page, not left dead', (
      tester,
    ) async {
      deviceType.isTv = true;
      final going = FocusNode(debugLabel: 'going');
      final staying = FocusNode(debugLabel: 'staying');
      addTearDown(going.dispose);
      addTearDown(staying.dispose);
      var showGoing = true;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: TvShell(
            child: StatefulBuilder(
              builder: (context, setState) => Scaffold(
                body: Column(
                  children: [
                    Focus(
                      focusNode: staying,
                      child: const SizedBox(height: 40, width: 200),
                    ),
                    if (showGoing)
                      Focus(
                        focusNode: going,
                        child: TextButton(
                          onPressed: () => setState(() => showGoing = false),
                          child: const Text('log in'),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      going.requestFocus();
      await tester.pumpAndSettle();
      expect(going.hasFocus, isTrue);

      // Signing in replaces the page under the remote — the control it was
      // resting on is simply gone, and focus falls back to a scope no arrow
      // key can search from.
      await tester.tap(find.text('log in'));
      await tester.pumpAndSettle();

      expect(staying.hasFocus, isTrue);
    });

    testWidgets('even when the remote was in a text field', (tester) async {
      deviceType.isTv = true;
      final staying = FocusNode(debugLabel: 'staying');
      addTearDown(staying.dispose);
      var signedIn = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: TvShell(
            child: StatefulBuilder(
              builder: (context, setState) => Scaffold(
                body: Column(
                  children: [
                    Focus(
                      focusNode: staying,
                      child: const SizedBox(height: 40, width: 200),
                    ),
                    if (!signedIn)
                      TextField(
                        onSubmitted: (_) => setState(() => signedIn = true),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();

      // A field is a control the outline deliberately stays off, so "is an
      // outline being drawn" is the wrong question to ask about whether the
      // remote is somewhere. Signing in from the on-screen keyboard — the one
      // way a television signs in anywhere — happens from right here.
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsNothing);
      expect(staying.hasFocus, isTrue);
    });
  });

  group('reaching a control with a remote', () {
    testWidgets('one press of left reaches the tab rail from deep in a list', (
      tester,
    ) async {
      deviceType.isTv = true;
      var selected = -1;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: TvShell(
            child: AppScaffold(
              bodyHorizontal: false,
              body: Row(
                children: [
                  NavigationRail(
                    selectedIndex: 0,
                    onDestinationSelected: (index) => selected = index,
                    labelType: NavigationRailLabelType.all,
                    destinations: const [
                      NavigationRailDestination(
                        icon: Icon(Icons.home),
                        label: Text('Tin'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.list),
                        label: Text('Phim'),
                      ),
                    ],
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: 200,
                      itemBuilder: (_, index) =>
                          NeuCard(onTap: () {}, child: Text('row $index')),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Walk a little way into the feed — far enough that a bar *below* the
      // content would now be a couple of hundred presses away.
      for (var i = 0; i < 8; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
      }
      final inList = primaryFocus!.rect;

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();

      // Beside the content, so it is one press away whatever the scroll
      // position — that is the whole reason a television gets a rail.
      expect(primaryFocus!.rect.left, lessThan(inList.left));

      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      expect(selected, isNot(-1));
    });

    testWidgets('the D-pad can leave a text field it has walked into', (
      tester,
    ) async {
      deviceType.isTv = true;
      final below = FocusNode(debugLabel: 'below');
      addTearDown(below.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: TvShell(
            child: Scaffold(
              body: Column(
                children: [
                  const TextField(),
                  Focus(focusNode: below, child: const SizedBox(height: 40)),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText))
            .focusNode
            .hasFocus,
        isTrue,
      );

      // `EditableText` binds an action that drops every arrow key carrying
      // `ignoreTextFields`, which is how Flutter frees the arrows to move the
      // caret. On a remote that leaves no way out of the field at all.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();

      expect(below.hasFocus, isTrue);
    });

    testWidgets('the OK button presses a card the D-pad is resting on', (
      tester,
    ) async {
      deviceType.isTv = true;
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      var taps = 0;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: TvShell(
            child: Scaffold(
              body: Center(
                child: NeuCard(
                  onTap: () => taps++,
                  child: const Text('Chi phí chung'),
                ),
              ),
            ),
          ),
        ),
      );

      // The remote walks onto the card — the nearest focus node above the
      // label is the one `NeuPress` installs.
      Focus.of(tester.element(find.text('Chi phí chung'))).requestFocus();
      await tester.pumpAndSettle();

      // KEYCODE_DPAD_CENTER arrives as `select`, which nothing in Flutter's
      // default shortcut map turns into an activation.
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      expect(taps, 1);
    });
  });
}
