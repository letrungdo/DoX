import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/model/tv_country.dart';
import 'package:do_x/theme/app_theme.dart';
import 'package:do_x/utils/device_type.dart';
import 'package:do_x/widgets/dialog/app_modal.dart';
import 'package:do_x/widgets/tv_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _countries = [
  TvCountry(code: 'VN', name: 'Vietnam', flag: '🇻🇳'),
  TvCountry(code: 'JP', name: 'Japan', flag: '🇯🇵'),
  TvCountry(code: 'KR', name: 'South Korea', flag: '🇰🇷'),
];

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

  /// Opens the country picker the TV page opens. The box it returns is filled
  /// in when the sheet closes, which is after the caller has pressed OK.
  Future<ValueNotifier<TvCountry?>> openPicker(WidgetTester tester) async {
    final picked = ValueNotifier<TvCountry?>(null);
    addTearDown(picked.dispose);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('vi'),
        theme: AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        // As the app installs it: above the navigator, so a route pushed over
        // the page — every dialog and sheet — is inside it too.
        builder: (context, child) => TvShell(child: child!),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  picked.value = await showAppSearchSheet<TvCountry>(
                    context,
                    title: 'Quốc gia',
                    options: _countries,
                    selected: _countries.first,
                    labelBuilder: (country) => country.label,
                    searchIndex: (country) => '${country.name} ${country.code}',
                    searchHint: 'Tìm quốc gia',
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return picked;
  }

  testWidgets('the remote walks out of the search box onto a country', (
    tester,
  ) async {
    await openPicker(tester);

    expect(find.text('🇯🇵 Japan'), findsOneWidget);

    // The search field takes the remote as the sheet opens. On a television
    // that is a trap unless the arrows are freed from the field, which is
    // `TvShell`'s job — and it only reaches the sheet because the shell sits
    // above the navigator.
    expect(_editing(tester), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    expect(_editing(tester), isFalse);
  });

  testWidgets('OK on a country closes the picker with it', (tester) async {
    final picked = await openPicker(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    // The OK button of a remote that sends `select` rather than `enter`.
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();

    expect(find.byType(ListTile), findsNothing);
    expect(picked.value, isNotNull);
  });
}

/// Whether the remote is sitting in the search box. The primary focus is the
/// `Focus` the field installs rather than the [EditableText] itself, so the
/// field's own node is what has to be asked.
bool _editing(WidgetTester tester) {
  return find
      .byType(EditableText)
      .evaluate()
      .any((element) => (element.widget as EditableText).focusNode.hasFocus);
}
