import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/model/tv_channel.dart';
import 'package:do_x/screen/tv/tv_channel_card.dart';
import 'package:do_x/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

TvChannel _channel(String name) =>
    TvChannel(id: name, name: name, urls: ['https://example.com/$name.m3u8']);

/// Two cards side by side, the size the grid gives them.
Future<void> _pumpCards(WidgetTester tester, List<String> names) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('vi'),
      theme: AppTheme.lightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Row(
          children: [
            for (final name in names)
              SizedBox(
                width: 150,
                height: 150 / 0.85,
                child: TvChannelCard(channel: _channel(name), onTap: () {}),
              ),
          ],
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('the logo plate is the same height whatever the name is', (
    tester,
  ) async {
    // A name that wraps onto a second line used to take the room out of the
    // logo above it, so a row of cards had its plates at half a dozen
    // heights — which is what the eye reads across a grid, not the names.
    await _pumpCards(tester, ['VTV1', 'Truyền hình Vĩnh Long 1 HD']);

    // The card's own plate, told apart from the scaffold's backdrop by the
    // near-white it keeps in both themes.
    final plates = find.byWidgetPredicate(
      (widget) => widget is ColoredBox && widget.color.a == 1,
    );
    expect(plates, findsNWidgets(2));
    expect(
      tester.getSize(plates.at(0)).height,
      tester.getSize(plates.at(1)).height,
    );
  });

  testWidgets('a longer name is cut rather than given a third line', (
    tester,
  ) async {
    await _pumpCards(tester, ['Truyền hình Vĩnh Long 1 HD chất lượng cao']);

    final name = tester.widget<Text>(
      find.text('Truyền hình Vĩnh Long 1 HD chất lượng cao'),
    );
    expect(name.maxLines, 2);
    expect(name.overflow, TextOverflow.ellipsis);
  });
}
