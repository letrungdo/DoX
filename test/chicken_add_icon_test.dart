import 'package:do_x/gen/assets.gen.dart';
import 'package:do_x/widgets/chicken_add_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('disabled chicken add icon is visibly dimmed', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ChickenAddIcon(icon: Assets.images.chickCute, enabled: false),
      ),
    );

    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 0.38);
  });
}
