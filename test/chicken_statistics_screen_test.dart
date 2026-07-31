import 'dart:async';

import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/model/chicken/batch_sale.dart';
import 'package:do_x/model/chicken/chicken_batch.dart';
import 'package:do_x/model/chicken/cock_sale.dart';
import 'package:do_x/model/chicken/expense.dart';
import 'package:do_x/model/chicken/pending_op.dart';
import 'package:do_x/repository/chicken_repository.dart';
import 'package:do_x/screen/chicken/chicken_statistics_screen.dart';
import 'package:do_x/services/storage_service.dart';
import 'package:do_x/theme/app_theme.dart';
import 'package:do_x/view_model/chicken_view_model.dart';
import 'package:do_x/widgets/chart/cute_bar_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeAuth extends ChickenAuth {
  final _changes = StreamController<AuthState>.broadcast();

  @override
  bool get isSignedIn => true;

  @override
  String? get userId => 'user-1';

  @override
  Stream<AuthState> get changes => _changes.stream;
}

class _FakeRepository extends ChickenRepository {
  _FakeRepository({
    this.batches = const [],
    this.cockSales = const [],
    this.expenses = const [],
  });

  final List<ChickenBatch> batches;
  final List<CockSale> cockSales;
  final List<Expense> expenses;

  @override
  Future<ChickenData> getChickenData({
    Set<ChickenSection>? sections,
    int? year,
  }) async => (
    batches: batches,
    globalCockSales: cockSales,
    globalExpenses: expenses,
    years: const <ChickenSection, Set<int>>{},
  );

  @override
  Future<void> apply(PendingOp op) async {}
}

/// Solar dates, as stored. The screen is pumped in solar mode so a date lands
/// in the month it is written as; the lunar display mode only changes which
/// month/year a date is bucketed under, which is covered in the view model
/// tests instead.
ChickenBatch _batch({
  required int month,
  required double revenue,
  required double expense,
  List<CockSale> cockSales = const [],
}) {
  return ChickenBatch(
    id: 'batch-$month',
    name: 'Bầy $month',
    incubationDate: DateTime(2026, month, 2),
    quantity: 30,
    sales: [
      BatchSale(
        id: 'sale-$month',
        date: DateTime(2026, month, 20),
        quantity: 25,
        amount: revenue,
      ),
    ],
    expenses: [
      Expense(
        id: 'exp-$month',
        type: ExpenseType.feed,
        amount: expense,
        date: DateTime(2026, month, 10),
      ),
    ],
    cockSales: cockSales,
  );
}

CockSale _cockSale({
  required String id,
  required int month,
  required double amount,
  required SaleCategory category,
}) => CockSale(
  id: id,
  note: 'note',
  amount: amount,
  date: DateTime(2026, month, 15),
  category: category,
);

/// The screen under a real theme and the Vietnamese locale, which is what the
/// number and month labels are formatted for.
Future<ChickenViewModel> _pumpScreen(
  WidgetTester tester,
  _FakeRepository repository,
) async {
  await storageService.clearChickenCache();
  await storageService.clearChickenSyncQueue();
  await storageService.setChickenLunarDisplay(false);

  final vm = ChickenViewModel(repository: repository, auth: _FakeAuth());
  addTearDown(vm.dispose);

  // Tall viewport so the whole list is laid out: a ListView only builds what
  // fits, and these tests assert on the detail cards below the chart.
  tester.view.physicalSize = const Size(800, 4000);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ChangeNotifierProvider<ChickenViewModel>.value(
      value: vm,
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        locale: const Locale('vi'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const ChickenStatisticsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  // The view model coalesces its notifications behind a short timer, which is
  // not tied to a frame — let it fire so no test ends with it pending.
  await tester.pump(const Duration(seconds: 1));
  return vm;
}

/// The strings a widget test can assert on: the widget tree's Text values.
List<String> _texts(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.data ?? '')
    .toList();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await storageService.init();
  });

  testWidgets('every revenue source is listed with its amount and share', (
    tester,
  ) async {
    await _pumpScreen(
      tester,
      _FakeRepository(
        batches: [_batch(month: 7, revenue: 6000000, expense: 1000000)],
        cockSales: [
          _cockSale(
            id: 'c1',
            month: 7,
            amount: 3000000,
            category: SaleCategory.fighting,
          ),
          // The one that used to vanish: meat sales are the third source and
          // must not be folded into the fighting-rooster figure.
          _cockSale(
            id: 'c2',
            month: 7,
            amount: 1000000,
            category: SaleCategory.meat,
          ),
        ],
      ),
    );

    final texts = _texts(tester);
    // 6M chick + 3M fighting + 1M meat = 10M revenue.
    expect(texts, contains('6,000,000đ · 60%'));
    expect(texts, contains('3,000,000đ · 30%'));
    expect(texts, contains('1,000,000đ · 10%'));
    // Both breakdowns (summary card and the month's detail card) show all three.
    expect(texts.where((t) => t == '1,000,000đ · 10%').length, 2);
  });

  testWidgets('meat revenue counts towards profit and the chart bar', (
    tester,
  ) async {
    await _pumpScreen(
      tester,
      _FakeRepository(
        batches: [_batch(month: 3, revenue: 5000000, expense: 2000000)],
        cockSales: [
          _cockSale(
            id: 'c1',
            month: 3,
            amount: 4000000,
            category: SaleCategory.meat,
          ),
        ],
      ),
    );

    // 5M + 4M meat - 2M = 7M profit, shown as the headline figure.
    expect(_texts(tester), contains('7,000,000đ'));

    final chart = tester.widget<CuteBarChart>(find.byType(CuteBarChart));
    final march = chart.items[2];
    expect(march.label, 'T3');
    expect(march.value, 9000000);
    expect(march.compareValue, 2000000);
    // The bar is sliced per source, meat included, so the chart shows where the
    // revenue came from rather than one opaque total.
    expect(march.segments.map((s) => s.value).toList(), [5000000, 0, 4000000]);
  });

  testWidgets('common expenses count against the period they fall in', (
    tester,
  ) async {
    await _pumpScreen(
      tester,
      _FakeRepository(
        batches: [_batch(month: 4, revenue: 3000000, expense: 500000)],
        expenses: [
          Expense(
            id: 'g1',
            type: ExpenseType.electricity,
            amount: 700000,
            date: DateTime(2026, 4, 8),
          ),
        ],
      ),
    );

    // 500k on the batch + 700k common = 1.2M spent, so 1.8M profit.
    final texts = _texts(tester);
    expect(texts, contains('1,200,000đ'));
    expect(texts, contains('1,800,000đ'));

    final chart = tester.widget<CuteBarChart>(find.byType(CuteBarChart));
    expect(chart.items.last.compareValue, 1200000);
  });

  testWidgets('the chart stops at the last recorded period', (tester) async {
    await _pumpScreen(
      tester,
      _FakeRepository(
        batches: [
          _batch(month: 2, revenue: 1000000, expense: 0),
          _batch(month: 5, revenue: 2000000, expense: 0),
        ],
      ),
    );

    final chart = tester.widget<CuteBarChart>(find.byType(CuteBarChart));
    // Months 1..5: the gaps in between are real, the empty tail is not — the
    // chart highlights its rightmost group, and that must be a month with data.
    expect(chart.items.length, 5);
    expect(chart.items.last.label, 'T5');
    expect(chart.items.last.value, 2000000);
  });

  testWidgets('a year with no records shows the empty state', (tester) async {
    await _pumpScreen(tester, _FakeRepository());

    expect(find.byType(CuteBarChart), findsNothing);
    expect(find.textContaining('Không có dữ liệu trong năm'), findsOneWidget);
  });
}
