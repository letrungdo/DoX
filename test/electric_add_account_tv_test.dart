import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/screen/electric_screen.dart';
import 'package:do_x/theme/app_theme.dart';
import 'package:do_x/utils/device_type.dart';
import 'package:do_x/view_model/electric_view_model.dart';
import 'package:do_x/widgets/setting_card.dart';
import 'package:do_x/widgets/tv_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

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

  /// The remote's own node, as the dialog names it. The primary focus is the
  /// `Focus` the field installs rather than the [EditableText] itself, so the
  /// node is what has to be asked.
  bool inUsernameField(WidgetTester tester) {
    return find
        .byType(EditableText)
        .evaluate()
        .map((e) => (e.widget as EditableText).focusNode)
        .any(
          (node) => node.hasFocus && node.debugLabel == 'electric-add-username',
        );
  }

  /// `TvShell` goes in `builder`, where the app puts it: a dialog is pushed on
  /// the navigator, so a shell wrapped around `home` instead would leave the
  /// dialog outside it — and outside the television's key bindings.
  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => TvShell(child: child!),
        home: ChangeNotifierProvider.value(
          value: ElectricViewModel(),
          child: Builder(
            builder: (context) => Scaffold(
              body: SettingCard(
                icon: Icons.person_add_alt_1_rounded,
                color: Colors.blue,
                title: const Text('add'),
                onTap: () => showElectricAddAccountDialog(context),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the add-account dialog opens with the remote in the field', (
    tester,
  ) async {
    await pump(tester);

    // The way a remote does it: walk onto the card, then press OK.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();

    // Without this the dialog opens with the focus on its own route scope and
    // nothing inside it: no outline, no keyboard, and no way to type the
    // second account's credentials.
    expect(find.byType(TextField), findsNWidgets(2));
    expect(inUsernameField(tester), isTrue);
  });

  testWidgets('the remote can walk from the field down to the buttons', (
    tester,
  ) async {
    await pump(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(inUsernameField(tester), isTrue);

    // A text field holds the arrow keys on every other platform; on a
    // television that would be a trap with the password field below it.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    expect(inUsernameField(tester), isFalse);
  });
}
