import 'package:do_x/constants/dimens.dart';
import 'package:do_x/widgets/dialog/app_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Opens a sheet holding [child] and settles the entrance animation.
Future<void> _openSheet(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
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
}
