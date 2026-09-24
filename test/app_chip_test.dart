import 'package:do_x/theme/app_theme.dart';
import 'package:do_x/widgets/surface/app_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a selected chip labels itself in onPrimary in dark mode', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: Center(
            child: AppChip(label: 'Tất cả', isSelected: true, onTap: () {}),
          ),
        ),
      ),
    );

    // White on the dark primary is 1.86:1; onPrimary is what reads on it.
    final text = tester.widget<Text>(find.text('Tất cả'));
    expect(text.style?.color, AppTheme.darkTheme.colorScheme.onPrimary);
  });
}
