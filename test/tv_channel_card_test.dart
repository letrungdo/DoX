import 'package:do_x/constants/dimens.dart';
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
                // The size the grid gives a card, so the room the name has
                // to fit into here is the room it has there.
                width: Dimens.tvChannelTileMaxWidth,
                height:
                    Dimens.tvChannelTileMaxWidth / Dimens.tvChannelTileAspect,
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
    // The strip below the logo is sized for its one line whatever the name
    // is, so no card takes the room out of the logo above it — a row of
    // logos at half a dozen sizes is what the eye reads across a grid.
    await _pumpCards(tester, ['VTV1', 'Truyền hình Vĩnh Long 1 HD']);

    // The logo's own square, told apart from everything else in the card by
    // the inset it is drawn in.
    final logos = find.byWidgetPredicate(
      (widget) =>
          widget is Padding && widget.padding == const EdgeInsets.all(10),
    );
    expect(logos, findsNWidgets(2));
    expect(
      tester.getSize(logos.at(0)).height,
      tester.getSize(logos.at(1)).height,
    );
  });

  testWidgets('the card carries no plate of its own', (tester) async {
    await _pumpCards(tester, ['VTV1']);

    // The logo sits on the card's own surface, so the tile is the colour of
    // whichever theme is on rather than white in both.
    expect(
      find.descendant(
        of: find.byType(TvChannelCard),
        matching: find.byWidgetPredicate(
          (widget) => widget is ColoredBox && widget.color.a == 1,
        ),
      ),
      findsNothing,
    );
  });

  testWidgets('a longer name is cut rather than given a second line', (
    tester,
  ) async {
    await _pumpCards(tester, ['Truyền hình Vĩnh Long 1 HD chất lượng cao']);

    final name = tester.widget<Text>(
      find.text('Truyền hình Vĩnh Long 1 HD chất lượng cao'),
    );
    expect(name.maxLines, 1);
    expect(name.overflow, TextOverflow.ellipsis);
  });
}
