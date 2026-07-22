import 'dart:async';

import 'package:collection/collection.dart';
import 'package:do_x/model/chicken/batch_sale.dart';
import 'package:do_x/model/chicken/chicken_batch.dart';
import 'package:do_x/model/chicken/cock_sale.dart';
import 'package:do_x/model/chicken/expense.dart';
import 'package:do_x/model/chicken/vaccination.dart';
import 'package:do_x/repository/chicken_repository.dart';
import 'package:do_x/services/chicken_import_service.dart';
import 'package:do_x/services/notification_service.dart';
import 'package:do_x/services/storage_service.dart';
import 'package:do_x/services/supabase_service.dart';
import 'package:do_x/utils/logger.dart';
import 'package:do_x/utils/lunar_calendar.dart';
import 'package:do_x/view_model/core/core_view_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class ChickenViewModel extends CoreViewModel {
  final ChickenRepository _repository = ChickenRepository();
  final _uuid = const Uuid();

  List<ChickenBatch> _batches = [];
  List<ChickenBatch> get batches => _batches;

  // Ids of batches deleted locally whose server delete may still be settling.
  // A batch load in flight can return a stale snapshot that still contains a
  // just-deleted batch; we filter those out so it doesn't reappear.
  final Set<String> _pendingDeletedBatchIds = {};

  List<CockSale> _globalCockSales = [];
  List<CockSale> get globalCockSales => _globalCockSales;

  List<Expense> _globalExpenses = [];
  List<Expense> get globalExpenses => _globalExpenses;

  bool _isImporting = false;
  bool get isImporting => _isImporting;

  double _importProgress = 0;
  double get importProgress => _importProgress;

  bool _useLunarCalendar = storageService.getChickenLunarDisplay();

  /// Whether chicken dates are displayed on the lunar calendar (default) or
  /// converted to the solar calendar. Stored dates are always lunar values.
  bool get useLunarCalendar => _useLunarCalendar;

  Future<void> setUseLunarCalendar(bool value) async {
    if (_useLunarCalendar == value) return;
    _useLunarCalendar = value;
    notifyListenersSafe();
    await storageService.setChickenLunarDisplay(value);
  }

  String? _highlightedId;

  /// Id of a freshly added record to highlight briefly in the lists. Shared by
  /// all chicken screens (they observe this view model).
  String? get highlightedId => _highlightedId;

  Timer? _highlightTimer;

  /// Highlights [id] for a short moment, then clears it.
  void flashHighlight(String id) {
    _highlightTimer?.cancel();
    _highlightedId = id;
    notifyListenersSafe();
    _highlightTimer = Timer(const Duration(milliseconds: 2500), () {
      _highlightedId = null;
      notifyListenersSafe();
    });
  }

  /// Year of a stored (lunar) [date] in the currently displayed calendar:
  /// the lunar year in lunar mode, the solar year in solar mode. Used by the
  /// year filters/grouping so they match the statistics.
  int displayYear(DateTime date) => _useLunarCalendar
      ? date.year
      : LunarCalendar.lunarDateTimeToSolar(date).year;

  StreamSubscription<AuthState>? _authSub;

  bool _batchesLoaded = false;
  bool _cockSalesLoaded = false;
  bool _expensesLoaded = false;

  // Sections requested by a screen at least once; reloaded again on sign-in.
  bool _batchesRequested = false;
  bool _cockSalesRequested = false;
  bool _expensesRequested = false;

  bool _batchesLoading = false;
  bool get isBatchesLoading => _batchesLoading;

  bool _cockSalesLoading = false;
  bool get isCockSalesLoading => _cockSalesLoading;

  bool _expensesLoading = false;
  bool get isExpensesLoading => _expensesLoading;

  // True while a fetch is in flight (including silent refreshes), used to drive
  // the thin progress bar under the app bar.
  bool _batchesFetching = false;
  bool get isBatchesFetching => _batchesFetching;

  bool _cockSalesFetching = false;
  bool get isCockSalesFetching => _cockSalesFetching;

  bool _expensesFetching = false;
  bool get isExpensesFetching => _expensesFetching;

  @override
  void initState() {
    super.initState();
    // This view model lives app-wide and initState runs on every screen mount,
    // so only subscribe once. Data is (re)loaded on sign-in because screens may
    // already be built (empty) while the login screen is shown.
    _authSub ??= supabase.auth.onAuthStateChange.listen((state) {
      switch (state.event) {
        case AuthChangeEvent.signedIn:
          if (_batchesRequested) {
            unawaited(loadBatches(showLoading: true));
          }
          if (_cockSalesRequested) {
            unawaited(loadCockSales(showLoading: true));
          }
          if (_expensesRequested) {
            unawaited(loadExpenses(showLoading: true));
          }
        case AuthChangeEvent.signedOut:
          _batches = [];
          _globalCockSales = [];
          _globalExpenses = [];
          _batchesLoaded = false;
          _cockSalesLoaded = false;
          _expensesLoaded = false;
          notifyListenersSafe();
          unawaited(_syncVaccinationNotifications());
        default:
          break;
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _highlightTimer?.cancel();
    super.dispose();
  }

  @override
  void initData() {
    super.initData();
    if (supabase.auth.currentSession == null &&
        vaccinationNotificationsEnabled) {
      unawaited(notificationService.cancelVaccinationNotifications());
    }
  }

  /// Called when a screen showing batches opens: always re-fetches; shows the
  /// spinner only on the first load, later entries refresh silently.
  Future<void> ensureBatchesLoaded() async {
    _batchesRequested = true;
    if (_batchesLoading) return;
    await loadBatches(showLoading: !_batchesLoaded);
  }

  /// Same as [ensureBatchesLoaded] but for global cock sales.
  Future<void> ensureCockSalesLoaded() async {
    _cockSalesRequested = true;
    if (_cockSalesLoading) return;
    await loadCockSales(showLoading: !_cockSalesLoaded);
  }

  /// Same as [ensureBatchesLoaded] but for global expenses.
  Future<void> ensureExpensesLoaded() async {
    _expensesRequested = true;
    if (_expensesLoading) return;
    await loadExpenses(showLoading: !_expensesLoaded);
  }

  Future<void> loadBatches({bool showLoading = false}) async {
    if (supabase.auth.currentSession == null) return;
    _batchesFetching = true;
    if (showLoading) _batchesLoading = true;
    notifyListenersSafe();
    try {
      final fetched = await _repository.getBatches();
      if (_pendingDeletedBatchIds.isNotEmpty) {
        // Once the server no longer returns a deleted batch, stop guarding it.
        final fetchedIds = fetched.map((b) => b.id).toSet();
        _pendingDeletedBatchIds.removeWhere((id) => !fetchedIds.contains(id));
      }
      _batches = _pendingDeletedBatchIds.isEmpty
          ? fetched
          : fetched
                .where((b) => !_pendingDeletedBatchIds.contains(b.id))
                .toList();
      _batchesLoaded = true;
    } catch (e) {
      logger.e("load chicken batches failed", error: e);
    } finally {
      _batchesLoading = false;
      _batchesFetching = false;
      notifyListenersSafe();
    }
    // Scheduling local notifications can be slow; keep it off the UI path.
    unawaited(_syncVaccinationNotifications());
  }

  Future<void> loadCockSales({bool showLoading = false}) async {
    if (supabase.auth.currentSession == null) return;
    _cockSalesFetching = true;
    if (showLoading) _cockSalesLoading = true;
    notifyListenersSafe();
    try {
      _globalCockSales = await _repository.getGlobalCockSales();
      _cockSalesLoaded = true;
    } catch (e) {
      logger.e("load cock sales failed", error: e);
    } finally {
      _cockSalesLoading = false;
      _cockSalesFetching = false;
      notifyListenersSafe();
    }
  }

  Future<void> loadExpenses({bool showLoading = false}) async {
    if (supabase.auth.currentSession == null) return;
    _expensesFetching = true;
    if (showLoading) _expensesLoading = true;
    notifyListenersSafe();
    try {
      _globalExpenses = await _repository.getGlobalExpenses();
      _expensesLoaded = true;
    } catch (e) {
      logger.e("load global expenses failed", error: e);
    } finally {
      _expensesLoading = false;
      _expensesFetching = false;
      notifyListenersSafe();
    }
  }

  /// Refreshes every section that has been loaded before.
  Future<void> refreshData() async {
    await Future.wait([
      if (_batchesLoaded) loadBatches(),
      if (_cockSalesLoaded) loadCockSales(),
      if (_expensesLoaded) loadExpenses(),
    ]);
  }

  Future<ChickenBatch> addBatch({
    required String name,
    required DateTime incubationDate,
    required int quantity,
  }) async {
    final newBatch = ChickenBatch(
      id: _uuid.v4(),
      name: name,
      incubationDate: incubationDate,
      quantity: quantity,
      vaccinations: _getDefaultVaccinationSchedule(incubationDate),
    );
    _batches.insert(0, newBatch);
    // Stable sort so a batch added with the same incubation date as an existing
    // one stays on top (it was just inserted at the front).
    mergeSort(
      _batches,
      compare: (a, b) => b.incubationDate.compareTo(a.incubationDate),
    );
    await _repository.insertBatch(newBatch);
    notifyListenersSafe();
    await _syncVaccinationNotifications();
    return newBatch;
  }

  Future<void> updateBatch(ChickenBatch batch) async {
    final index = _batches.indexWhere((e) => e.id == batch.id);
    if (index != -1) {
      final previousBatch = _batches[index];
      // Dates are lunar values; measure the shift in real (solar) days so the
      // vaccination schedule moves by the same physical amount.
      final incubationDateDelta = LunarCalendar.lunarDateTimeToSolar(
        batch.incubationDate,
      ).difference(
        LunarCalendar.lunarDateTimeToSolar(previousBatch.incubationDate),
      );
      final updatedBatch = incubationDateDelta == Duration.zero
          ? batch
          : batch.shiftVaccinationSchedule(incubationDateDelta);

      _batches[index] = updatedBatch;
      await _repository.updateBatch(updatedBatch);
      if (incubationDateDelta != Duration.zero) {
        await _repository.updateVaccinationDates(updatedBatch.vaccinations);
      }
      notifyListenersSafe();
      await _syncVaccinationNotifications();
    }
  }

  Future<void> deleteBatch(String id) async {
    final batch = _batches.firstWhereOrNull((e) => e.id == id);
    if (batch != null) {
      _batches.removeWhere((e) => e.id == id);
      // Guard against an in-flight load re-adding this batch before the server
      // delete has settled. The guard is cleared by a later load once the
      // server confirms the batch is gone.
      _pendingDeletedBatchIds.add(id);
      notifyListenersSafe();
      try {
        await _repository.deleteBatch(id);
      } catch (e) {
        logger.e("delete chicken batch failed", error: e);
        // Delete failed: stop guarding and restore the batch locally.
        _pendingDeletedBatchIds.remove(id);
        _batches.add(batch);
        mergeSort(
          _batches,
          compare: (a, b) => b.incubationDate.compareTo(a.incubationDate),
        );
        notifyListenersSafe();
        return;
      }
      await _syncVaccinationNotifications();
    }
  }

  Future<void> addExpense(String batchId, Expense expense) async {
    final index = _batches.indexWhere((e) => e.id == batchId);
    if (index != -1) {
      final updatedExpenses = List<Expense>.from(_batches[index].expenses)
        ..add(expense);
      _batches[index] = _batches[index].copyWith(expenses: updatedExpenses);
      await _repository.insertExpense(batchId, expense);
      notifyListenersSafe();
    }
  }

  Future<void> updateExpense(String batchId, Expense expense) async {
    final index = _batches.indexWhere((e) => e.id == batchId);
    if (index != -1) {
      final updatedExpenses = _batches[index].expenses
          .map((e) => e.id == expense.id ? expense : e)
          .toList();
      _batches[index] = _batches[index].copyWith(expenses: updatedExpenses);
      await _repository.updateExpense(expense);
      notifyListenersSafe();
    }
  }

  Future<void> deleteExpense(String batchId, String expenseId) async {
    final index = _batches.indexWhere((e) => e.id == batchId);
    if (index != -1) {
      final updatedExpenses = _batches[index].expenses
          .where((e) => e.id != expenseId)
          .toList();
      _batches[index] = _batches[index].copyWith(expenses: updatedExpenses);
      await _repository.deleteExpense(expenseId);
      notifyListenersSafe();
    }
  }

  Future<void> addBatchSale(String batchId, BatchSale sale) async {
    final index = _batches.indexWhere((e) => e.id == batchId);
    if (index != -1) {
      final updatedSales = List<BatchSale>.from(_batches[index].sales)
        ..add(sale);
      updatedSales.sort((a, b) => a.date.compareTo(b.date));
      _batches[index] = _batches[index].copyWith(sales: updatedSales);
      await _repository.insertBatchSale(batchId, sale);
      notifyListenersSafe();
    }
  }

  Future<void> updateBatchSale(String batchId, BatchSale sale) async {
    final index = _batches.indexWhere((e) => e.id == batchId);
    if (index != -1) {
      final updatedSales =
          _batches[index].sales
              .map((s) => s.id == sale.id ? sale : s)
              .toList()
            ..sort((a, b) => a.date.compareTo(b.date));
      _batches[index] = _batches[index].copyWith(sales: updatedSales);
      await _repository.updateBatchSale(sale);
      notifyListenersSafe();
    }
  }

  Future<void> deleteBatchSale(String batchId, String saleId) async {
    final index = _batches.indexWhere((e) => e.id == batchId);
    if (index != -1) {
      final updatedSales = _batches[index].sales
          .where((s) => s.id != saleId)
          .toList();
      _batches[index] = _batches[index].copyWith(sales: updatedSales);
      await _repository.deleteBatchSale(saleId);
      notifyListenersSafe();
    }
  }

  Future<void> addCockSale(String batchId, CockSale sale) async {
    final index = _batches.indexWhere((e) => e.id == batchId);
    if (index != -1) {
      final updatedSales = List<CockSale>.from(_batches[index].cockSales)
        ..add(sale);
      _batches[index] = _batches[index].copyWith(cockSales: updatedSales);
      await _repository.insertCockSale(batchId, sale);
      notifyListenersSafe();
    }
  }

  Future<void> addGlobalCockSale(CockSale sale) async {
    // Front of the list so a same-date sale shows on top (stable sort keeps it).
    _globalCockSales.insert(0, sale);
    await _repository.insertCockSale(null, sale);
    notifyListenersSafe();
  }

  Future<void> updateGlobalCockSale(CockSale sale) async {
    final index = _globalCockSales.indexWhere((item) => item.id == sale.id);
    if (index == -1) return;
    await _repository.updateGlobalCockSale(sale);
    _globalCockSales[index] = sale;
    notifyListenersSafe();
  }

  Future<void> deleteGlobalCockSale(String id) async {
    await _repository.deleteGlobalCockSale(id);
    _globalCockSales.removeWhere((sale) => sale.id == id);
    notifyListenersSafe();
  }

  Future<void> addGlobalExpense(Expense expense) async {
    await _repository.insertExpense(null, expense);
    _globalExpenses.insert(0, expense);
    notifyListenersSafe();
  }

  Future<void> updateGlobalExpense(Expense expense) async {
    final index = _globalExpenses.indexWhere((item) => item.id == expense.id);
    if (index == -1) return;
    await _repository.updateGlobalExpense(expense);
    _globalExpenses[index] = expense;
    notifyListenersSafe();
  }

  Future<void> deleteGlobalExpense(String id) async {
    await _repository.deleteGlobalExpense(id);
    _globalExpenses.removeWhere((expense) => expense.id == id);
    notifyListenersSafe();
  }

  /// Imports data from the JSON format described in [ChickenImportService].
  /// Returns the number of imported records, or throws on invalid input.
  Future<int> importFromJson(String jsonString) async {
    final data = ChickenImportService.parse(jsonString);
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw StateError('Bạn cần đăng nhập trước khi import.');

    _isImporting = true;
    _importProgress = 0;
    notifyListenersSafe();

    try {
      await _repository.importData(
        batches: data.batches,
        globalSales: data.globalSales,
        globalExpenses: data.globalExpenses,
        onProgress: (completed, total) {
          _importProgress = total == 0 ? 1 : completed / total;
          notifyListenersSafe();
        },
      );
      await refreshData();
      return data.totalRecords;
    } finally {
      _isImporting = false;
      notifyListenersSafe();
    }
  }

  Future<int> deleteAllData() async {
    if (supabase.auth.currentUser == null) {
      throw StateError('Bạn cần đăng nhập trước khi xóa dữ liệu.');
    }

    final deletedCount = await _repository.deleteAllData();
    await refreshData();
    return deletedCount;
  }

  Future<void> toggleVaccination(String batchId, String vaccinationId) async {
    final index = _batches.indexWhere((e) => e.id == batchId);
    if (index != -1) {
      Vaccination? toggled;
      final updatedVaccinations = _batches[index].vaccinations.map((v) {
        if (v.id == vaccinationId) {
          toggled = v.copyWith(isCompleted: !v.isCompleted);
          return toggled!;
        }
        return v;
      }).toList();
      _batches[index] = _batches[index].copyWith(
        vaccinations: updatedVaccinations,
      );
      if (toggled != null) {
        await _repository.setVaccinationCompleted(
          vaccinationId,
          toggled!.isCompleted,
        );
      }
      notifyListenersSafe();
      await _syncVaccinationNotifications();
    }
  }

  List<Vaccination> _getDefaultVaccinationSchedule(DateTime incubationDate) {
    // [incubationDate] is a lunar-valued date. The offsets below are real
    // (biological) day counts, so compute them in the solar calendar and store
    // the result back as lunar values to stay consistent with the rest of the
    // data.
    final hatchSolar = LunarCalendar.lunarDateTimeToSolar(
      incubationDate,
    ).add(const Duration(days: 21));

    Vaccination vaccination(String title, int daysAfterHatch) => Vaccination(
      id: _uuid.v4(),
      title: title,
      scheduledDate: LunarCalendar.solarToLunarDateTime(
        hatchSolar.add(Duration(days: daysAfterHatch)),
      ),
    );

    return [
      vaccination('Gumboro (Lần 1)', 7),
      vaccination('Newcastle (Lần 1)', 10),
      vaccination('Gumboro (Lần 2)', 14),
      vaccination('Newcastle (Lần 2)', 21),
      vaccination('Tụ huyết trùng', 45),
    ];
  }

  /// Giá gợi ý theo mặt bằng giá bán thực tế trong sổ (đ/con).
  /// Tuổi âm (chưa nở) vẫn trả mức thấp nhất để form bán có giá mặc định.
  double suggestPrice(int ageInDays) {
    if (ageInDays < 7) return 20000;
    if (ageInDays < 21) return 25000;
    if (ageInDays < 30) return 33000;
    if (ageInDays < 45) return 40000;
    return 50000;
  }

  bool get vaccinationNotificationsEnabled =>
      storageService.getChickenNotificationsEnabled();

  Future<bool> setVaccinationNotificationsEnabled(bool enabled) async {
    if (enabled && !await notificationService.requestPermission()) return false;
    try {
      if (enabled) {
        await notificationService.scheduleVaccinations(_batches);
      } else {
        await notificationService.cancelVaccinationNotifications();
      }
      await storageService.setChickenNotificationsEnabled(enabled);
      notifyListenersSafe();
      return true;
    } catch (e) {
      logger.e('update vaccination notification setting failed', error: e);
      notifyListenersSafe();
      return false;
    }
  }

  Future<void> _syncVaccinationNotifications() async {
    if (!vaccinationNotificationsEnabled) return;
    try {
      await notificationService.scheduleVaccinations(_batches);
    } catch (e) {
      logger.e('schedule vaccination notifications failed', error: e);
    }
  }

  Map<int, ChickenStats> getMonthlyStats(int year) {
    final stats = <int, _MutableStats>{
      for (int i = 1; i <= 12; i++) i: _MutableStats(),
    };
    _accumulateStats((date) => date.year == year ? stats[date.month]! : null);
    return stats.map((m, val) => MapEntry(m, val.toRecord()));
  }

  Map<int, ChickenStats> getYearlyStats() {
    final stats = <int, _MutableStats>{};
    _accumulateStats(
      (date) => stats.putIfAbsent(date.year, () => _MutableStats()),
    );
    return stats.map((y, val) => MapEntry(y, val.toRecord()));
  }

  void _accumulateStats(_MutableStats? Function(DateTime date) bucketOf) {
    // Stored dates are lunar values. In lunar mode the buckets are lunar
    // year/month; in solar mode convert first so stats group by solar dates.
    DateTime bucketDate(DateTime date) => _useLunarCalendar
        ? date
        : LunarCalendar.lunarDateTimeToSolar(date);

    void addSale(CockSale sale) {
      final bucket = bucketOf(bucketDate(sale.date));
      if (bucket == null) return;
      if (sale.category == SaleCategory.meat) {
        bucket.meatRevenue += sale.amount;
      } else {
        bucket.cockRevenue += sale.amount;
      }
    }

    void addExpense(Expense exp) =>
        bucketOf(bucketDate(exp.date))?.expense += exp.amount;

    for (var batch in _batches) {
      for (var sale in batch.sales) {
        bucketOf(bucketDate(sale.date))?.batchRevenue += sale.amount;
      }
      batch.cockSales.forEach(addSale);
      batch.expenses.forEach(addExpense);
    }
    _globalCockSales.forEach(addSale);
    _globalExpenses.forEach(addExpense);
  }
}

typedef ChickenStats = ({
  double batchRevenue,
  double cockRevenue,
  double meatRevenue,
  double expense,
  double profit,
});

class _MutableStats {
  double batchRevenue = 0;
  double cockRevenue = 0;
  double meatRevenue = 0;
  double expense = 0;

  ChickenStats toRecord() => (
    batchRevenue: batchRevenue,
    cockRevenue: cockRevenue,
    meatRevenue: meatRevenue,
    expense: expense,
    profit: (batchRevenue + cockRevenue + meatRevenue) - expense,
  );
}
