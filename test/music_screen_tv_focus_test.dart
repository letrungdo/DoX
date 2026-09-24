import 'dart:async';

import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/model/music_shelf.dart';
import 'package:do_x/model/music_track.dart';
import 'package:do_x/model/music_video.dart';
import 'package:do_x/screen/music/music_fullscreen_video_player.dart';
import 'package:do_x/screen/music/music_screen.dart';
import 'package:do_x/services/music_playback_session.dart';
import 'package:do_x/theme/app_theme.dart';
import 'package:do_x/utils/device_type.dart';
import 'package:do_x/view_model/music/music_view_model.dart';
import 'package:do_x/widgets/tv_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'fake_video_player_platform.dart';

/// Keeps the system's media service out of it: a test has none to start.
class _SilentPlayback extends MusicPlaybackSession {
  @override
  void attach(MusicPlaybackControls controls, {required String channelName}) {}

  @override
  void detach(MusicPlaybackControls controls) {}

  @override
  void updateTrack(MusicTrack track, Duration duration) {}

  @override
  void updateState({
    required bool playing,
    required Duration position,
    bool loading = false,
  }) {}
}

MusicTrack _track(String id) => MusicTrack(
  id: id,
  title: 'Track $id',
  artist: 'Artist',
  artworkUrl: '',
  streamUrl: 'transcoding-$id',
  duration: const Duration(minutes: 3),
);

final _results = [_track('a'), _track('b'), _track('c')];

String? _focused() => FocusManager.instance.primaryFocus?.debugLabel;

/// Where the remote lands on the music page of a television: after a search
/// sent from the on-screen keyboard, and after backing out of the full-screen
/// video.
void main() {
  late Completer<List<MusicTrack>> answer;
  late MusicViewModel vm;

  /// What Discover's rows come back as; a test sets its own.
  late Future<List<MusicShelf>> Function() shelves;

  setUp(() {
    shelves = () async => [];
    deviceType.isTv = true;
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    VideoPlayerPlatform.instance = FakeVideoPlayerPlatform(
      playing: {'https://cdn/a', 'https://cdn/b', 'https://yt/muxed'},
    );
    vm = MusicViewModel(
      resolveStream: (url) async => 'https://cdn/${url.split('-').last}',
      playback: _SilentPlayback(),
      findVideo: (_) async => const MusicVideo(
        videoId: 'v',
        duration: Duration(minutes: 5),
        useAudio: false,
        muxedUrl: 'https://yt/muxed',
      ),
      findHdVideo: (_) async => null,
      discoverShelves: () => shelves(),
      search: (_) => answer.future,
      videoEnabled: true,
    );
  });

  tearDown(() {
    deviceType.isTv = false;
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
  });

  Future<void> pumpPage(WidgetTester tester, {bool search = true}) async {
    // Made inside the test: completed from outside its zone, the answer
    // would be delivered to an event loop the fake clock never runs.
    answer = Completer<List<MusicTrack>>();
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => TvShell(child: child!),
        home: ChangeNotifierProvider.value(
          value: vm,
          child: const MusicScreen(),
        ),
      ),
    );
    await tester.pump();
    if (!search) return;
    vm.switchTab(MusicTab.search);
    await tester.pump();
  }

  FocusNode node(String label) => FocusManager.instance.rootScope.descendants
      .singleWhere((node) => node.debugLabel == label);

  /// OK on the row the remote is on, then the stream and the picture coming
  /// up full screen.
  Future<void> pick(WidgetTester tester) async {
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// Types [query] into the search box and presses the keyboard's search key.
  Future<void> search(WidgetTester tester, String query) async {
    await tester.showKeyboard(find.byType(TextField));
    await tester.enterText(find.byType(TextField), query);
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
  }

  /// A few frames: the answer lands mid-frame, its notice is delivered after
  /// it, and the remote is moved after the frame that shows the rows.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }
  }

  Future<void> tearDownPage(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 6));
    vm.dispose();
  }

  testWidgets('a search sent from the keyboard puts the remote on the first '
      'result once the answer is in', (tester) async {
    await pumpPage(tester);
    await search(tester, 'abc');

    // Waiting on the Search tab, not handed to Discover.
    expect(vm.isLoading, isTrue);
    expect(_focused(), 'tv-music-search-tab');

    answer.complete(_results);
    await settle(tester);
    expect(_focused(), 'tv-track-search-a');

    await tearDownPage(tester);
  });

  testWidgets('a remote moved on while the search is on its way is left '
      'where it was put', (tester) async {
    await pumpPage(tester);
    await search(tester, 'abc');
    expect(_focused(), 'tv-music-search-tab');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    final movedTo = _focused();
    expect(movedTo, isNot('tv-music-search-tab'));

    answer.complete(_results);
    await settle(tester);
    expect(_focused(), movedTo);

    await tearDownPage(tester);
  });

  testWidgets('backing out of the full-screen video puts the remote on the '
      'row of the track picked', (tester) async {
    await pumpPage(tester);
    await search(tester, 'abc');
    answer.complete(_results);
    await settle(tester);

    // Picked with the remote: OK on the second row.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(_focused(), 'tv-track-search-b');
    await pick(tester);
    expect(vm.currentTrack?.id, 'b');
    expect(find.byType(MusicFullscreenVideoPlayer), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(find.byType(MusicFullscreenVideoPlayer), findsNothing);
    expect(_focused(), 'tv-track-search-b');

    await tearDownPage(tester);
  });

  testWidgets('a track on two shelves is two rows, and backing out of full '
      'screen lands on the one it was picked from', (tester) async {
    shelves = () async => [
      MusicShelf(title: 'One', tracks: [_track('x'), _track('b')]),
      MusicShelf(title: 'Two', tracks: [_track('b'), _track('c')]),
    ];
    await pumpPage(tester, search: false);
    await vm.loadHomeData();
    await settle(tester);
    expect(node('tv-track-shelf-0-b'), isNot(node('tv-track-shelf-1-b')));

    node('tv-track-shelf-1-b').requestFocus();
    await tester.pump();
    await pick(tester);
    expect(vm.currentTrack?.id, 'b');
    expect(find.byType(MusicFullscreenVideoPlayer), findsOneWidget);

    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(find.byType(MusicFullscreenVideoPlayer), findsNothing);
    expect(_focused(), 'tv-track-shelf-1-b');

    await tearDownPage(tester);
  });

  testWidgets('a Discover refresh behind the Search tab leaves the results '
      'on screen', (tester) async {
    await pumpPage(tester);
    await search(tester, 'abc');
    answer.complete(_results);
    await settle(tester);
    expect(find.text('Track a'), findsOneWidget);

    final refresh = Completer<List<MusicShelf>>();
    shelves = () => refresh.future;
    unawaited(vm.loadHomeData());
    await settle(tester);
    expect(vm.isLoading, isTrue, reason: 'the sync badge still turns');
    expect(vm.isTabLoading(MusicTab.home), isTrue);
    expect(vm.isTabLoading(MusicTab.search), isFalse);
    expect(find.text('Track a'), findsOneWidget);

    // Not empty: an empty Discover falls back to a search of the network.
    refresh.complete([
      MusicShelf(title: 'One', tracks: [_track('x')]),
    ]);
    await settle(tester);
    expect(vm.isLoading, isFalse);

    await tearDownPage(tester);
  });
}
