import 'package:do_x/extensions/date_extensions.dart';
import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/model/chicken/batch_sale.dart';
import 'package:do_x/model/chicken/chicken_batch.dart';
import 'package:do_x/model/chicken/pending_op.dart';
import 'package:do_x/repository/chicken_repository.dart';
import 'package:do_x/screen/chicken/chicken_batch_detail_screen.dart';
import 'package:do_x/services/storage_service.dart';
import 'package:do_x/theme/app_theme.dart';
import 'package:do_x/view_model/chicken_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeAuth extends ChickenAuth {
  @override
  bool get isSignedIn => true;

  @override
  String? get userId => 'user-1';

  @override
  Stream<AuthState> get changes => const Stream.empty();
}

class _FakeRepository extends ChickenRepository {
  final List<ChickenBatch> batches;

  _FakeRepository(this.batches);

  @override
  Future<ChickenData> getChickenData({
    Set<ChickenSection>? sections,
    int? year,
  }) async => (
    batches: batches,
    globalCockSales: null,
    globalExpenses: null,
    years: const <ChickenSection, Set<int>>{},
  );

  @override
  Future<void> apply(PendingOp op) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await storageService.init();
  });

  testWidgets('sale card and new-sale dialog show the same suggested price', (
    tester,
  ) async {
    await storageService.clearChickenCache();
    await storageService.clearChickenSyncQueue();
    await storageService.setChickenLunarDisplay(false);

    final today = DateTime.now().dateOnly;
    final targetHatchDate = today.subtract(const Duration(days: 100));
    final target = ChickenBatch(
      id: 'target',
      name: 'Lứa đang bán',
      incubationDate: targetHatchDate.subtract(const Duration(days: 21)),
      actualHatchDate: targetHatchDate,
      quantity: 30,
    );
    final historicalHatchDate = today.subtract(const Duration(days: 465));
    final history = ChickenBatch(
      id: 'history',
      name: 'Lứa cũ',
      incubationDate: historicalHatchDate.subtract(const Duration(days: 21)),
      actualHatchDate: historicalHatchDate,
      quantity: 30,
      sales: [
        BatchSale(
          id: 'historical-sale',
          date: historicalHatchDate.add(const Duration(days: 100)),
          quantity: 20,
          amount: 840000,
        ),
      ],
    );
    final vm = ChickenViewModel(
      repository: _FakeRepository([target, history]),
      auth: _FakeAuth(),
    );
    addTearDown(vm.dispose);

    tester.view.physicalSize = const Size(1200, 3000);
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
          home: const ChickenBatchDetailScreen(batchId: 'target'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('42,000đ/con'), findsOneWidget);

    final recordSale = find.text('Ghi nhận đợt bán mới');
    await tester.ensureVisible(recordSale);
    await tester.tap(recordSale);
    await tester.pumpAndSettle();

    expect(find.text('Gợi ý 42,000đ/con'), findsOneWidget);
  });
}
