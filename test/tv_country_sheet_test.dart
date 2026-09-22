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

  testWidgets('the sheet opens on a country, not in the search box', (
    tester,
  ) async {
    await openPicker(tester);

    expect(find.text('🇯🇵 Japan'), findsOneWidget);

    // A television opens the sheet on the country already chosen: the box
    // wants a keyboard over half the screen, and a remote that lands in it
    // has to be walked out before it can reach a single country.
    expect(_editing(tester), isFalse);
    expect(_focusedLabel(tester), '🇻🇳 Vietnam');
  });

  testWidgets('the remote walks into the search box and back out', (
    tester,
  ) async {
    await openPicker(tester);

    // UP off the first country reaches the box, which is the only way to
    // type on a television.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(_editing(tester), isTrue);

    // And DOWN comes back out of it. A text field swallows the arrows by
    // default, so this only works because `TvShell` frees them — and the
    // shell only reaches the sheet because it sits above the navigator.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(_editing(tester), isFalse);
  });

  testWidgets('typing a name in any case finds the country', (tester) async {
    await openPicker(tester);

    // The box lower-cases what is typed, so an index that kept its capitals
    // matched nothing at all — every country disappeared as the first letter
    // went in.
    await tester.enterText(find.byType(TextField), 'japan');
    await tester.pumpAndSettle();

    expect(find.text('🇯🇵 Japan'), findsOneWidget);
    expect(find.text('🇻🇳 Vietnam'), findsNothing);

    // The code is searchable too, and the case it is typed in is no more
    // important there.
    await tester.enterText(find.byType(TextField), 'kr');
    await tester.pumpAndSettle();

    expect(find.text('🇰🇷 South Korea'), findsOneWidget);
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

/// The label of the country the remote is on, or null when it is on none.
///
/// The node holding the focus is the one [ListTile] installs inside its own
/// ink well, so the tile it belongs to is found by walking back up from there.
String? _focusedLabel(WidgetTester tester) {
  final focused = FocusManager.instance.primaryFocus?.context;
  if (focused == null) return null;
  ListTile? tile;
  focused.visitAncestorElements((element) {
    final widget = element.widget;
    if (widget is ListTile) {
      tile = widget;
      return false;
    }
    return true;
  });
  final title = tile?.title;
  return title is Text ? title.data : null;
}
