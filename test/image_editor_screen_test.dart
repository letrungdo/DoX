import 'dart:typed_data';

import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/screen/image_editor/image_editor_screen.dart';
import 'package:do_x/theme/app_theme.dart';
import 'package:do_x/view_model/image_editor_view_model.dart';
import 'package:do_x/widgets/neu/neu_button.dart';
import 'package:do_x/widgets/neu/neu_card.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:provider/provider.dart';

Future<void> _pump(WidgetTester tester, {double textScale = 1}) {
  return tester.pumpWidget(
    MaterialApp(
      locale: const Locale('vi'),
      theme: AppTheme.lightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        minScaleFactor: textScale,
        maxScaleFactor: textScale,
        child: child!,
      ),
      // The router normally calls `wrappedRoute`, which is what installs the
      // view model the screen reads.
      home: Builder(
        builder: (context) => const ImageEditorScreen().wrappedRoute(context),
      ),
    ),
  );
}

/// A plain 40x30 picture, opaque so a stroke over it is unmistakable.
Uint8List _picture() {
  final image = img.Image(width: 40, height: 30);
  img.fill(image, color: img.ColorRgb8(200, 200, 200));
  return img.encodePng(image);
}

/// Seeds the editor with a picture, the way a crop result would.
Future<ImageEditorViewModel> _withPicture(
  WidgetTester tester, {
  double textScale = 1,
}) async {
  await _pump(tester, textScale: textScale);
  final vm = tester
      .element(find.byType(ImageEditorScreen))
      .read<ImageEditorViewModel>();
  vm.applyCrop(_picture());
  await tester.pumpAndSettle();
  return vm;
}

void main() {
  testWidgets('with no picture yet, the page is the two ways of picking one', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.text('Chọn từ thư viện'), findsOneWidget);
    expect(find.text('Chụp ảnh'), findsOneWidget);
  });

  testWidgets('the editing actions stay disabled until there is a picture', (
    tester,
  ) async {
    await _pump(tester);

    NeuIconButton button(IconData icon) =>
        tester.widget<NeuIconButton>(find.widgetWithIcon(NeuIconButton, icon));

    // Sharing nothing, and undoing an edit that was never made, are the two
    // taps an empty editor has to refuse.
    expect(button(Icons.ios_share_rounded).onPressed, isNull);
    expect(button(Icons.undo_rounded).onPressed, isNull);
    // Picking a picture is still on offer from the app bar.
    expect(button(Icons.more_vert_rounded).onPressed, isNotNull);
  });

  testWidgets('a picture brings up the tools, sharing included', (
    tester,
  ) async {
    await _withPicture(tester);

    for (final tool in ['Cắt', 'Xoay', 'Màu', 'Bộ lọc', 'Vẽ']) {
      expect(find.text(tool), findsWidgets, reason: 'missing the $tool tool');
    }
    expect(
      tester
          .widget<NeuIconButton>(
            find.widgetWithIcon(NeuIconButton, Icons.ios_share_rounded),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('drawing a stroke is what arms the apply action', (tester) async {
    await _withPicture(tester);

    await tester.tap(find.text('Vẽ'));
    await tester.pumpAndSettle();

    // Nothing drawn yet, so there is nothing to apply.
    NeuButton applyButton() => tester.widget<NeuButton>(
      find.ancestor(of: find.text('Áp dụng'), matching: find.byType(NeuButton)),
    );
    expect(applyButton().onPressed, isNull);

    // The drawing surface is the one box laid out at the picture's own shape.
    await tester.drag(find.byType(AspectRatio), const Offset(20, 20));
    await tester.pumpAndSettle();
    expect(applyButton().onPressed, isNotNull);

    // Applying it is left to the device: flattening captures the preview
    // through `RepaintBoundary.toImage`, which needs a real rasteriser rather
    // than the test one.
  });

  testWidgets('the filter row still fits when the text is scaled up', (
    tester,
  ) async {
    await _withPicture(tester, textScale: 2);

    await tester.tap(find.text('Bộ lọc'));
    await tester.pumpAndSettle();

    // The thumbnails give way to the taller labels rather than the row
    // overflowing, which a RenderFlex reports as an exception.
    expect(find.text('Trắng đen'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('in portrait the panel scrolls instead of running off the page', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    // The sliders' labels are the tallest thing in the panel once the system
    // font is scaled up — the case that used to overflow the page.
    await _withPicture(tester, textScale: 2);

    expect(find.text('Độ sáng'), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(
      find.descendant(
        of: find.byType(NeuCard),
        matching: find.byType(Scrollable),
      ),
      findsWidgets,
    );
  });

  testWidgets('leaving the draw tool asks before dropping the strokes', (
    tester,
  ) async {
    await _withPicture(tester);
    await tester.tap(find.text('Vẽ'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(AspectRatio), const Offset(20, 20));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Xoay'));
    await tester.pumpAndSettle();
    expect(find.text('Bỏ nét vẽ?'), findsOneWidget);

    // Backing out of the question leaves the drawing — and the tool — alone.
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    expect(find.text('Áp dụng'), findsOneWidget);

    await tester.tap(find.text('Xoay'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bỏ'));
    await tester.pumpAndSettle();
    expect(find.text('Áp dụng'), findsNothing);
    expect(find.text('Xoay trái'), findsOneWidget);
  });

  testWidgets('every tool panel fits the page at a large text size', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1125, 2436);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await _withPicture(tester, textScale: 1.6);

    for (final tool in ['Xoay', 'Màu', 'Bộ lọc', 'Vẽ', 'Cắt']) {
      await tester.tap(find.text(tool));
      // pump, not pumpAndSettle: the crop widget keeps an image-stream frame
      // callback alive, so settling never returns once that tool is open.
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        tester.takeException(),
        isNull,
        reason: 'the $tool panel overflows',
      );
    }
  });

  testWidgets('the last brush swatch opens the app colour picker', (
    tester,
  ) async {
    await _withPicture(tester);
    await tester.tap(find.text('Vẽ'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Màu tuỳ chỉnh'));
    await tester.pumpAndSettle();
    expect(find.byType(ColorPicker), findsOneWidget);
    expect(find.text('Chọn màu'), findsOneWidget);

    // Backing out leaves the brush on the preset it was already holding.
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    expect(find.byType(ColorPicker), findsNothing);
  });
}
