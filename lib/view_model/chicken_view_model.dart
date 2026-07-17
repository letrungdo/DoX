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
import 'package:do_x/view_model/core/core_view_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class ChickenViewModel extends CoreViewModel {
  final ChickenRepository _repository = ChickenRepository();
  final _uuid = const Uuid();

  List<ChickenBatch> _batches = [];
  List<ChickenBatch> get batches => _batches;

  List<CockSale> _globalCockSales = [];
  List<CockSale> get globalCockSales => _globalCockSales;

  List<Expense> _globalExpenses = [];
  List<Expense> get globalExpenses => _globalExpenses;

  bool _isImporting = false;
  bool get isImporting => _isImporting;

  double _importProgress = 0;
  double get importProgress => _importProgress;

  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    // Data is (re)loaded on sign-in because this view model lives app-wide:
    // ChickenScreen may already be built (empty) while the login screen is shown.
    _authSub = supabase.auth.onAuthStateChange.listen((state) {
      switch (state.event) {
        case AuthChangeEvent.signedIn:
          _loadData();
        case AuthChangeEvent.signedOut:
          _batches = [];
          _globalCockSales = [];
          _globalExpenses = [];
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
    super.dispose();
  }

  @override
  void initData() {
    super.initData();
    if (supabase.auth.currentSession == null) {
      if (vaccinationNotificationsEnabled) {
        unawaited(notificationService.cancelVaccinationNotifications());
      }
      return;
    }
    _loadData();
  }

  Future<void> _loadData({bool showLoading = true}) async {
    if (showLoading) setBusy(true);
    try {
      _batches = await _repository.getBatches();
      _globalCockSales = await _repository.getGlobalCockSales();
      _globalExpenses = await _repository.getGlobalExpenses();
      await _syncVaccinationNotifications();
    } catch (e) {
      logger.e("load chicken data failed", error: e);
    } finally {
      if (showLoading) {
        setBusy(false);
      } else {
        notifyListenersSafe();
      }
    }
  }

  Future<void> refreshData() => _loadData(showLoading: false);

  Future<void> addBatch({
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
    _batches.sort((a, b) => b.incubationDate.compareTo(a.incubationDate));
    await _repository.insertBatch(newBatch);
    notifyListenersSafe();
    await _syncVaccinationNotifications();
  }

  Future<void> updateBatch(ChickenBatch batch) async {
    final index = _batches.indexWhere((e) => e.id == batch.id);
    if (index != -1) {
      final previousBatch = _batches[index];
      final incubationDateDelta = batch.incubationDate.difference(
        previousBatch.incubationDate,
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
      await _repository.deleteBatch(id);
      notifyListenersSafe();
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
    _globalCockSales.add(sale);
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
      await _loadData();
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
    await _loadData();
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
    final hatchDate = incubationDate.add(const Duration(days: 21));
    return [
      Vaccination(
        id: _uuid.v4(),
        title: 'Gumboro (Lần 1)',
        scheduledDate: hatchDate.add(const Duration(days: 7)),
      ),
      Vaccination(
        id: _uuid.v4(),
        title: 'Newcastle (Lần 1)',
        scheduledDate: hatchDate.add(const Duration(days: 10)),
      ),
      Vaccination(
        id: _uuid.v4(),
        title: 'Gumboro (Lần 2)',
        scheduledDate: hatchDate.add(const Duration(days: 14)),
      ),
      Vaccination(
        id: _uuid.v4(),
        title: 'Newcastle (Lần 2)',
        scheduledDate: hatchDate.add(const Duration(days: 21)),
      ),
      Vaccination(
        id: _uuid.v4(),
        title: 'Tụ huyết trùng',
        scheduledDate: hatchDate.add(const Duration(days: 45)),
      ),
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
    void addSale(CockSale sale) {
      final bucket = bucketOf(sale.date);
      if (bucket == null) return;
      if (sale.category == SaleCategory.meat) {
        bucket.meatRevenue += sale.amount;
      } else {
        bucket.cockRevenue += sale.amount;
      }
    }

    void addExpense(Expense exp) => bucketOf(exp.date)?.expense += exp.amount;

    for (var batch in _batches) {
      for (var sale in batch.sales) {
        bucketOf(sale.date)?.batchRevenue += sale.amount;
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
