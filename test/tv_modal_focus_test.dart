import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/theme/app_theme.dart';
import 'package:do_x/utils/device_type.dart';
import 'package:do_x/widgets/dialog/app_modal.dart';
import 'package:do_x/widgets/dialog/dialog_action_button.dart';
import 'package:do_x/widgets/tv_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every dialog and sheet in the app opens on a television with the remote
/// already inside it. Without that the focus sits on the modal's own route
/// scope: nothing is outlined, OK presses nothing, and a dialog built around a
/// text field cannot be typed into at all.
void main() {
  setUp(() {
    deviceType.isTv = true;
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
  });

  tearDown(() {
    deviceType.isTv = false;
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
  });

  /// The remote is on a control when the focus is a node rather than the
  /// scope every modal route opens with.
  bool onAControl() {
    final node = FocusManager.instance.primaryFocus;
    return node != null && node is! FocusScopeNode;
  }

  String? focusedLabel(WidgetTester tester) {
    final context = FocusManager.instance.primaryFocus?.context;
    if (context == null) return null;
    final labels = find
        .descendant(
          of: find.byWidget(context.widget),
          matching: find.byType(Text),
        )
        .evaluate()
        .map((e) => (e.widget as Text).data)
        .whereType<String>();
    return labels.isEmpty ? null : labels.first;
  }

  /// `TvShell` goes in `builder`, where the app puts it: a modal is pushed on
  /// the navigator, so a shell wrapped around `home` would leave it outside.
  /// The modal is opened without anything on the page holding the focus first,
  /// which is the state that used to leave the remote with nowhere to be.
  Future<void> pumpAndOpen(
    WidgetTester tester,
    Future<void> Function(BuildContext context) open,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => TvShell(child: child!),
        home: Builder(
          builder: (context) {
            WidgetsBinding.instance.addPostFrameCallback((_) => open(context));
            return const Scaffold(body: SizedBox.shrink());
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a dialog opens with the remote on its first button', (
    tester,
  ) async {
    await pumpAndOpen(
      tester,
      (context) => showAppModal<void>(
        context,
        builder: (_) => AppDialog(
          title: 'Title',
          message: 'Message',
          actions: [
            DialogActionButton(
              text: 'Cancel',
              kind: DialogActionKind.cancel,
              onPressed: () {},
            ),
            DialogActionButton(text: 'OK', onPressed: () {}),
          ],
        ),
      ),
    );

    expect(onAControl(), isTrue);
    expect(focusedLabel(tester), 'Cancel');
  });

  testWidgets('a field that asks for the remote itself keeps it', (
    tester,
  ) async {
    await pumpAndOpen(
      tester,
      (context) => showAppModal<void>(
        context,
        builder: (_) => AppDialog(
          title: 'Title',
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(onPressed: () {}, child: const Text('Before')),
              const TextField(autofocus: true),
            ],
          ),
          actions: [DialogActionButton(text: 'OK', onPressed: () {})],
        ),
      ),
    );

    // The field comes second, so handing the remote to the first control
    // would take it off the one the dialog asked for.
    final field = tester.widget<EditableText>(find.byType(EditableText));
    expect(field.focusNode.hasFocus, isTrue);
  });

  testWidgets('a bottom sheet opens with the remote inside it', (tester) async {
    await pumpAndOpen(
      tester,
      (context) => showAppBottomSheet<void>(
        context,
        title: 'Pick',
        builder: (_) => Column(
          children: [
            ListTile(title: const Text('First'), onTap: () {}),
            ListTile(title: const Text('Second'), onTap: () {}),
          ],
        ),
      ),
    );

    // The sheet's own close button comes first in the header, so that is
    // where the remote lands — outlined, and one press away from the rows.
    expect(onAControl(), isTrue);
    expect(
      find.descendant(
        of: find.byType(AppBottomSheet),
        matching: find.byWidget(
          FocusManager.instance.primaryFocus!.context!.widget,
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a phone is left exactly as it was', (tester) async {
    deviceType.isTv = false;
    await pumpAndOpen(
      tester,
      (context) => showAppModal<void>(
        context,
        builder: (_) => AppDialog(
          title: 'Title',
          message: 'Message',
          actions: [DialogActionButton(text: 'OK', onPressed: () {})],
        ),
      ),
    );

    // Nothing is focused until a finger lands on it, so no dialog on a phone
    // opens with a button already outlined.
    expect(onAControl(), isFalse);
  });
}
