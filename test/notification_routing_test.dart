import 'package:auto_route/auto_route.dart';
import 'package:do_x/constants/enum/app_page.dart';
import 'package:do_x/model/chicken/chicken_batch.dart';
import 'package:do_x/model/chicken/cock_sale.dart';
import 'package:do_x/model/chicken/expense.dart';
import 'package:do_x/repository/chicken_repository.dart';
import 'package:do_x/router/notification_routing.dart';
import 'package:do_x/services/notification_service.dart';
import 'package:do_x/services/push_notification_service.dart';
import 'package:do_x/services/storage_service.dart';
import 'package:do_x/view_model/app_view_model.dart';
import 'package:do_x/view_model/chicken_view_model.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Signed in as `user-1`, who can also read `shared-owner`'s data.
class _FakeAuth extends ChickenAuth {
  @override
  bool get isSignedIn => true;

  @override
  String? get userId => 'user-1';

  @override
  Stream<AuthState> get changes => const Stream.empty();
}

class _FakeRepository extends ChickenRepository {
  @override
  Future<List<ChickenDataSource>> getDataSources() async => const [
    ChickenDataSource(
      ownerId: 'user-1',
      email: 'owner@example.com',
      isOwner: true,
    ),
    ChickenDataSource(
      ownerId: 'shared-owner',
      email: 'shared@example.com',
      isOwner: false,
    ),
  ];

  @override
  Future<List<ChickenShareViewer>> getShareViewers() async => const [];

  @override
  Future<ChickenData> getChickenData({
    Set<ChickenSection>? sections,
    int? year,
    String? ownerId,
  }) async => (
    batches: <ChickenBatch>[],
    globalCockSales: <CockSale>[],
    globalExpenses: <Expense>[],
    years: <ChickenSection, Set<int>>{},
  );
}

/// Records where a notification asked to go instead of driving the real
/// router, which needs the whole app around it to say anything.
class _RecordingRouting extends NotificationRouting {
  _RecordingRouting({required super.appVm, required super.chickenVm});

  final opened = <AppPage>[];

  @override
  void showPage(AppPage page, PageRouteInfo route) => opened.add(page);
}

void main() {
  late AppViewModel appVm;
  late ChickenViewModel chickenVm;
  late _RecordingRouting routing;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await storageService.init();
  });

  setUp(() {
    notificationService.electricNotificationMonth.value = null;
    notificationService.sharedActivityOwnerId.value = null;
    notificationService.stormAlertRequested.value = false;
    appVm = AppViewModel();
    chickenVm = ChickenViewModel(
      repository: _FakeRepository(),
      auth: _FakeAuth(),
    );
    routing = _RecordingRouting(appVm: appVm, chickenVm: chickenVm);
  });

  tearDown(() {
    routing.dispose();
    appVm.dispose();
    chickenVm.dispose();
  });

  // What a tapped notification asks for, before anything listens: the routing
  // consumes a request the moment it is made, so these two cannot be observed
  // in the same test.
  group('notification payloads', () {
    test('the electricity reminder asks for last month', () {
      notificationService.handlePayload(
        NotificationService.electricNotificationPayload,
      );

      final now = DateTime.now();
      expect(
        notificationService.electricNotificationMonth.value,
        DateTime(now.year, now.month - 1),
      );
      expect(notificationService.sharedActivityOwnerId.value, isNull);
    });

    test('a shared-activity notification names its owner', () {
      notificationService.handlePayload(
        '${NotificationService.sharedActivityPayloadPrefix}shared-owner',
      );

      expect(notificationService.sharedActivityOwnerId.value, 'shared-owner');
      expect(notificationService.electricNotificationMonth.value, isNull);
    });

    test('a storm alert asks for the news page', () {
      notificationService.handlePayload(NotificationService.stormAlertPayload);

      expect(notificationService.stormAlertRequested.value, isTrue);
      expect(notificationService.sharedActivityOwnerId.value, isNull);
    });

    test('a storm push asks for the news page', () {
      pushNotificationService.handleTappedPush(
        const RemoteMessage(
          data: {'type': 'storm_news', 'severity': 'warning'},
        ),
      );

      expect(notificationService.stormAlertRequested.value, isTrue);
      expect(notificationService.sharedActivityOwnerId.value, isNull);
    });

    test('a vaccination reminder only opens the app', () {
      notificationService.handlePayload('batch-1');

      expect(notificationService.electricNotificationMonth.value, isNull);
      expect(notificationService.sharedActivityOwnerId.value, isNull);
    });

    test('a push carries the owner of the data it is about', () {
      pushNotificationService.handleTappedPush(
        const RemoteMessage(
          data: {
            'type': 'chicken_activity',
            'kind': 'cock_sale',
            'owner_id': 'shared-owner',
          },
        ),
      );

      expect(notificationService.sharedActivityOwnerId.value, 'shared-owner');
    });

    test('a push about anything else is left alone', () {
      pushNotificationService.handleTappedPush(
        const RemoteMessage(data: {'type': 'something_else'}),
      );
      pushNotificationService.handleTappedPush(
        const RemoteMessage(data: {'type': 'chicken_activity'}),
      );

      expect(notificationService.sharedActivityOwnerId.value, isNull);
    });
  });

  group('notification routing', () {
    setUp(() => routing.start());

    testWidgets('the electricity reminder opens its page on that month', (
      tester,
    ) async {
      notificationService.electricNotificationMonth.value = DateTime(2026, 7);
      await tester.pump();

      expect(routing.opened, [AppPage.electric]);
      expect(appVm.electricMonthToHighlight, DateTime(2026, 7));
      // Consumed: a rebuild must not send the app back there.
      expect(notificationService.electricNotificationMonth.value, isNull);
    });

    testWidgets('a shared-activity push opens the chicken page on its owner', (
      tester,
    ) async {
      notificationService.openSharedActivity('shared-owner');
      await tester.pump();
      // The view model debounces its cache write; leaving that timer pending
      // fails the test.
      await tester.pump(const Duration(seconds: 1));

      expect(routing.opened, [AppPage.chicken]);
      expect(chickenVm.activeOwnerId, 'shared-owner');
      expect(notificationService.sharedActivityOwnerId.value, isNull);
    });

    testWidgets('a second push about the same owner navigates again', (
      tester,
    ) async {
      notificationService.openSharedActivity('shared-owner');
      await tester.pump();
      notificationService.openSharedActivity('shared-owner');
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(routing.opened, [AppPage.chicken, AppPage.chicken]);
    });

    testWidgets('a storm alert opens the news page', (tester) async {
      notificationService.openStormAlert();
      await tester.pump();

      expect(routing.opened, [AppPage.news]);
      // Consumed: a rebuild must not send the app back there.
      expect(notificationService.stormAlertRequested.value, isFalse);
    });

    testWidgets('a second storm alert navigates again', (tester) async {
      notificationService.openStormAlert();
      await tester.pump();
      notificationService.openStormAlert();
      await tester.pump();

      expect(routing.opened, [AppPage.news, AppPage.news]);
    });

    testWidgets('an empty owner id is not a destination', (tester) async {
      notificationService.openSharedActivity('');
      await tester.pump();

      expect(routing.opened, isEmpty);
    });

    testWidgets('nothing is opened once the routing is disposed', (
      tester,
    ) async {
      routing.dispose();

      notificationService.electricNotificationMonth.value = DateTime(2026, 7);
      notificationService.openSharedActivity('shared-owner');
      await tester.pump();

      expect(routing.opened, isEmpty);
    });
  });
}
