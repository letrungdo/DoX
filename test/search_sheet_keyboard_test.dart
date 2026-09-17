import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/theme/app_theme.dart';
import 'package:do_x/widgets/dialog/app_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _screen = Size(400, 800);
const _keyboardHeight = 320.0;

/// Every bank in the picker, near enough: the point is that the filtered list
/// gets short while the keyboard is up.
final _options = List.generate(60, (i) => 'Ngân hàng số $i');

Future<void> _openSheet(WidgetTester tester) async {
  tester.view.physicalSize = _screen;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      locale: const Locale('vi'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showAppSearchSheet<String>(
                context,
                title: 'Chọn ngân hàng',
                options: _options,
                selected: null,
                labelBuilder: (v) => v,
                searchIndex: (v) => v.toLowerCase(),
                searchHint: 'Tìm',
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

/// Stands in for the keyboard coming up.
void _raiseKeyboard(WidgetTester tester) {
  tester.view.viewInsets = FakeViewPadding(
    bottom: _keyboardHeight * tester.view.devicePixelRatio,
  );
}

/// Whether the search field still holds focus — which is what decides whether
/// the keyboard is up.
bool _fieldHasFocus(WidgetTester tester) {
  return tester
      .widget<EditableText>(find.byType(EditableText))
      .focusNode
      .hasFocus;
}

void main() {
  testWidgets('the search field stays above the keyboard', (tester) async {
    await _openSheet(tester);

    _raiseKeyboard(tester);
    await tester.pumpAndSettle();

    final field = tester.getRect(find.byType(TextField));
    expect(
      field.bottom,
      lessThanOrEqualTo(_screen.height - _keyboardHeight),
      reason: 'the field a user is typing into cannot sit under the keyboard',
    );
  });

  testWidgets('a filtered-down list stays above the keyboard too', (
    tester,
  ) async {
    await _openSheet(tester);
    _raiseKeyboard(tester);
    await tester.pumpAndSettle();

    // Narrow it to a single row — the case that used to leave the whole sheet
    // shrink-wrapped behind the keyboard.
    await tester.enterText(find.byType(TextField), 'số 42');
    await tester.pumpAndSettle();

    expect(find.text('Ngân hàng số 42'), findsOneWidget);
    expect(
      tester.getRect(find.text('Ngân hàng số 42')).bottom,
      lessThanOrEqualTo(_screen.height - _keyboardHeight),
    );
  });

  testWidgets('with no keyboard the sheet still reaches the bottom edge', (
    tester,
  ) async {
    await _openSheet(tester);

    expect(tester.getRect(find.byType(TextField)).bottom, lessThan(800));
    expect(find.text('Ngân hàng số 0'), findsOneWidget);
  });

  testWidgets('tapping a result dismisses the keyboard with the sheet', (
    tester,
  ) async {
    await _openSheet(tester);
    _raiseKeyboard(tester);
    await tester.pumpAndSettle();

    expect(_fieldHasFocus(tester), isTrue);

    await tester.tap(find.text('Ngân hàng số 3'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('tapping away from the field closes the keyboard', (
    tester,
  ) async {
    await _openSheet(tester);
    _raiseKeyboard(tester);
    await tester.pumpAndSettle();

    expect(_fieldHasFocus(tester), isTrue);

    // The sheet's own title, which is not a control.
    await tester.tapAt(tester.getCenter(find.text('Chọn ngân hàng')));
    await tester.pumpAndSettle();

    expect(
      _fieldHasFocus(tester),
      isFalse,
      reason: 'a tap on the sheet outside the field should close the keyboard',
    );
  });

  testWidgets('a query that matches nothing says so', (tester) async {
    await _openSheet(tester);

    await tester.enterText(find.byType(TextField), 'không có');
    await tester.pumpAndSettle();

    expect(find.text('Ngân hàng số 0'), findsNothing);
    expect(find.textContaining('Không tìm thấy'), findsOneWidget);
  });
}
