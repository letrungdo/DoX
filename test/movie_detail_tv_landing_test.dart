import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/model/movie_model.dart';
import 'package:do_x/screen/movie/movie_detail_screen.dart';
import 'package:do_x/services/storage_service.dart';
import 'package:do_x/theme/app_theme.dart';
import 'package:do_x/utils/device_type.dart';
import 'package:do_x/view_model/movie/movie_detail_view_model.dart';
import 'package:do_x/widgets/loading.dart';
import 'package:do_x/widgets/tv_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'fake_video_player_platform.dart';

const _movie = Movie(
  id: 'phim-1',
  title: 'Phim Một',
  url: 'https://a.example/phim-1',
  poster: 'https://a.example/phim-1.jpg',
);

/// The detail page as the browse page opens it: inside the overlay, fully
/// expanded. It is the only way onto this page on a television, which is why
/// the landing has to work here and not only on the route of its own.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({
      'movieServers': ['https://a.example'],
      'movieBaseUrl': 'https://a.example',
      'primaryMovieServer': 'https://a.example',
    });
    await storageService.init();
  });

  final original = VideoPlayerPlatform.instance;
  late FakeVideoPlayerPlatform fakePlayer;

  setUp(() {
    // Stands in for the platform player so that a page which does reach for a
    // stream is seen doing it, rather than failing for want of a plugin.
    fakePlayer = FakeVideoPlayerPlatform(stalls: true);
    VideoPlayerPlatform.instance = fakePlayer;
  });

  tearDown(() {
    VideoPlayerPlatform.instance = original;
    deviceType.isTv = false;
  });

  Future<void> pumpDetail(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        theme: AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => TvShell(child: child!),
        home: ChangeNotifierProvider(
          create: (_) => MovieDetailViewModel(),
          child: MovieDetailScreen(
            movieUrl: _movie.url,
            movieId: _movie.id,
            initialMovie: _movie,
            embedded: true,
          ),
        ),
      ),
    );
    // The detail request has no server to answer it in a test; these pumps let
    // it fail and the page settle on whatever it decided to show.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets(
    'a television lands on the actions instead of a spinner that never ends',
    (tester) async {
      deviceType.isTv = true;
      await pumpDetail(tester);

      // The landing is the whole point of not autoplaying: without it the page
      // shows the player's loading state for ever, because nothing is ever
      // going to start.
      expect(find.text('Play from start'), findsOneWidget);
      // The state the bug left the page in: the player box on its own spinner,
      // waiting for a stream nothing was ever going to ask for.
      expect(find.byType(Loading), findsNothing);
      expect(fakePlayer.opened, isEmpty);
    },
  );

  testWidgets('a phone still has no landing in the way of its film', (
    tester,
  ) async {
    deviceType.isTv = false;
    await pumpDetail(tester);

    expect(find.text('Play from start'), findsNothing);
  });
}
