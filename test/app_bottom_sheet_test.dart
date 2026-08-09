import 'package:do_x/constants/dimens.dart';
import 'package:do_x/theme/app_theme.dart';
import 'package:do_x/widgets/dialog/app_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Opens a sheet holding [child] and settles the entrance animation.
Future<void> _openSheet(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      // The sheet's close button is a neu control, which reads the app theme's
      // colour extensions — a bare ThemeData has none of them.
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showAppBottomSheet<void>(
              context,
              title: 'Thể loại',
              builder: (_) => child,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

/// Distance from the sheet's left edge to the body's, which is what reads as
/// the sheet's padding.
double _bodyInset(WidgetTester tester) {
  final sheetLeft = tester.getTopLeft(find.byType(AppBottomSheet)).dx;
  return tester.getTopLeft(find.byType(Wrap)).dx - sheetLeft;
}

void main() {
  testWidgets('a body narrower than the sheet still spans it', (tester) async {
    await _openSheet(
      tester,
      const Wrap(children: [SizedBox(width: 40, height: 30)]),
    );

    // The sheet lays its content out against its own width, not against the
    // width the content happened to want.
    final sheetWidth = tester.getSize(find.byType(AppBottomSheet)).width;
    final bodyWidth = tester.getSize(find.byType(Wrap)).width;

    expect(bodyWidth, sheetWidth - Dimens.sheetPadding.horizontal);
  });

  testWidgets('a nearly empty sheet is padded like any other', (tester) async {
    await _openSheet(
      tester,
      const Wrap(children: [SizedBox(width: 10, height: 30)]),
    );

    expect(_bodyInset(tester), Dimens.sheetPadding.left);
  });

  testWidgets('a full sheet is padded the same', (tester) async {
    await _openSheet(
      tester,
      const Wrap(children: [SizedBox(width: 4000, height: 30)]),
    );

    expect(_bodyInset(tester), Dimens.sheetPadding.left);
  });

  testWidgets('an option list scrolls through the bottom safe area', (
    tester,
  ) async {
    const bottomInset = 34.0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(padding: const EdgeInsets.only(bottom: bottomInset)),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showAppOptionSheet<int>(
                context,
                title: 'Speed',
                options: List.generate(20, (index) => index),
                selected: 1,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final list = tester.widget<ListView>(find.byType(ListView));
    expect(list.padding, const EdgeInsets.only(bottom: 8 + bottomInset));
    expect(
      tester.getBottomLeft(find.byType(ListView)).dy,
      tester.getBottomLeft(find.byType(AppBottomSheet)).dy,
    );
  });
}
