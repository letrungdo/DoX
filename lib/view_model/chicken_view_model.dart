import 'dart:async';

import 'package:collection/collection.dart';
import 'package:do_x/model/chicken/chicken_batch.dart';
import 'package:do_x/model/chicken/cock_sale.dart';
import 'package:do_x/model/chicken/expense.dart';
import 'package:do_x/model/chicken/vaccination.dart';
import 'package:do_x/repository/chicken_repository.dart';
import 'package:do_x/services/google_sync_service.dart';
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
          notifyListenersSafe();
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
    if (supabase.auth.currentSession == null) return;
    _loadData();
  }

  Future<void> _loadData() async {
    setBusy(true);
    try {
      _batches = await _repository.getBatches();
      _globalCockSales = await _repository.getGlobalCockSales();
    } catch (e) {
      logger.e("load chicken data failed", error: e);
    } finally {
      setBusy(false);
    }
  }

  Future<void> addBatch({required String name, required DateTime incubationDate, required int quantity}) async {
    final newBatch = ChickenBatch(
      id: _uuid.v4(),
      name: name,
      incubationDate: incubationDate,
      quantity: quantity,
      vaccinations: _getDefaultVaccinationSchedule(incubationDate),
    );
    _batches.add(newBatch);
    await _repository.insertBatch(newBatch);
    notifyListenersSafe();
    _autoSyncGoogleTasks();
  }

  Future<void> updateBatch(ChickenBatch batch) async {
    final index = _batches.indexWhere((e) => e.id == batch.id);
    if (index != -1) {
      _batches[index] = batch;
      await _repository.updateBatch(batch);
      notifyListenersSafe();
      _autoSyncGoogleTasks();
    }
  }

  Future<void> deleteBatch(String id) async {
    final batch = _batches.firstWhereOrNull((e) => e.id == id);
    if (batch != null) {
      if (googleSyncService.currentUser != null) {
        googleSyncService.deleteTaskList(batch.name);
      }
      _batches.removeWhere((e) => e.id == id);
      await _repository.deleteBatch(id);
      notifyListenersSafe();
    }
  }

  Future<void> addExpense(String batchId, Expense expense) async {
    final index = _batches.indexWhere((e) => e.id == batchId);
    if (index != -1) {
      final updatedExpenses = List<Expense>.from(_batches[index].expenses)..add(expense);
      _batches[index] = _batches[index].copyWith(expenses: updatedExpenses);
      await _repository.insertExpense(batchId, expense);
      notifyListenersSafe();
    }
  }

  Future<void> addCockSale(String batchId, CockSale sale) async {
    final index = _batches.indexWhere((e) => e.id == batchId);
    if (index != -1) {
      final updatedSales = List<CockSale>.from(_batches[index].cockSales)..add(sale);
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
      _batches[index] = _batches[index].copyWith(vaccinations: updatedVaccinations);
      if (toggled != null) {
        await _repository.setVaccinationCompleted(vaccinationId, toggled!.isCompleted);
      }
      notifyListenersSafe();
      _autoSyncGoogleTasks();
    }
  }

  List<Vaccination> _getDefaultVaccinationSchedule(DateTime incubationDate) {
    final hatchDate = incubationDate.add(const Duration(days: 21));
    return [
      Vaccination(id: _uuid.v4(), title: 'Gumboro (Lần 1)', scheduledDate: hatchDate.add(const Duration(days: 7))),
      Vaccination(id: _uuid.v4(), title: 'Newcastle (Lần 1)', scheduledDate: hatchDate.add(const Duration(days: 10))),
      Vaccination(id: _uuid.v4(), title: 'Gumboro (Lần 2)', scheduledDate: hatchDate.add(const Duration(days: 14))),
      Vaccination(id: _uuid.v4(), title: 'Newcastle (Lần 2)', scheduledDate: hatchDate.add(const Duration(days: 21))),
      Vaccination(id: _uuid.v4(), title: 'Tụ huyết trùng', scheduledDate: hatchDate.add(const Duration(days: 45))),
    ];
  }

  double suggestPrice(int ageInDays) {
    if (ageInDays < 30) return 0;
    if (ageInDays < 60) return 50000;
    if (ageInDays < 90) return 100000;
    return 150000;
  }

  bool get autoSyncEnabled => storageService.getChickenAutoSync();

  /// Enables/disables auto sync of vaccination schedules to Google Tasks.
  /// Returns false when enabling failed (Google sign-in declined).
  Future<bool> setAutoSyncEnabled(bool enabled) async {
    if (enabled && googleSyncService.currentUser == null) {
      final user = await googleSyncService.signIn();
      if (user == null) return false;
    }
    await storageService.setChickenAutoSync(enabled);
    if (enabled) _autoSyncGoogleTasks();
    notifyListenersSafe();
    return true;
  }

  void _autoSyncGoogleTasks() {
    if (!autoSyncEnabled || googleSyncService.currentUser == null) return;
    googleSyncService.syncToGoogleTasks(_batches).catchError((e) {
      logger.e("auto sync Google Tasks failed", error: e);
      return false;
    });
  }

  Map<int, ({double batchRevenue, double cockRevenue, double expense, double profit})> getMonthlyStats(int year) {
    final stats = <int, ({double batchRevenue, double cockRevenue, double expense, double profit})>{};
    for (int i = 1; i <= 12; i++) {
      stats[i] = (batchRevenue: 0.0, cockRevenue: 0.0, expense: 0.0, profit: 0.0);
    }

    for (var batch in _batches) {
      if (batch.saleDate != null && batch.saleDate!.year == year) {
        final m = batch.saleDate!.month;
        final current = stats[m]!;
        stats[m] = (
          batchRevenue: current.batchRevenue + (batch.totalSaleAmount ?? 0),
          cockRevenue: current.cockRevenue,
          expense: current.expense,
          profit: 0.0,
        );
      }
      for (var sale in batch.cockSales) {
        if (sale.date.year == year) {
          final m = sale.date.month;
          final current = stats[m]!;
          stats[m] = (
            batchRevenue: current.batchRevenue,
            cockRevenue: current.cockRevenue + sale.amount,
            expense: current.expense,
            profit: 0.0,
          );
        }
      }
      for (var exp in batch.expenses) {
        if (exp.date.year == year) {
          final m = exp.date.month;
          final current = stats[m]!;
          stats[m] = (
            batchRevenue: current.batchRevenue,
            cockRevenue: current.cockRevenue,
            expense: current.expense + exp.amount,
            profit: 0.0,
          );
        }
      }
    }
    for (var sale in _globalCockSales) {
      if (sale.date.year == year) {
        final m = sale.date.month;
        final current = stats[m]!;
        stats[m] = (
          batchRevenue: current.batchRevenue,
          cockRevenue: current.cockRevenue + sale.amount,
          expense: current.expense,
          profit: 0.0,
        );
      }
    }
    stats.updateAll(
      (m, val) => (
        batchRevenue: val.batchRevenue,
        cockRevenue: val.cockRevenue,
        expense: val.expense,
        profit: (val.batchRevenue + val.cockRevenue) - val.expense,
      ),
    );
    return stats;
  }

  Map<int, ({double batchRevenue, double cockRevenue, double expense, double profit})> getYearlyStats() {
    final stats = <int, ({double batchRevenue, double cockRevenue, double expense, double profit})>{};
    for (var batch in _batches) {
      if (batch.saleDate != null) {
        final y = batch.saleDate!.year;
        stats.putIfAbsent(y, () => (batchRevenue: 0.0, cockRevenue: 0.0, expense: 0.0, profit: 0.0));
        final current = stats[y]!;
        stats[y] = (
          batchRevenue: current.batchRevenue + (batch.totalSaleAmount ?? 0),
          cockRevenue: current.cockRevenue,
          expense: current.expense,
          profit: 0.0,
        );
      }
      for (var sale in batch.cockSales) {
        final y = sale.date.year;
        stats.putIfAbsent(y, () => (batchRevenue: 0.0, cockRevenue: 0.0, expense: 0.0, profit: 0.0));
        final current = stats[y]!;
        stats[y] = (
          batchRevenue: current.batchRevenue,
          cockRevenue: current.cockRevenue + sale.amount,
          expense: current.expense,
          profit: 0.0,
        );
      }
      for (var exp in batch.expenses) {
        final y = exp.date.year;
        stats.putIfAbsent(y, () => (batchRevenue: 0.0, cockRevenue: 0.0, expense: 0.0, profit: 0.0));
        final current = stats[y]!;
        stats[y] = (
          batchRevenue: current.batchRevenue,
          cockRevenue: current.cockRevenue,
          expense: current.expense + exp.amount,
          profit: 0.0,
        );
      }
    }
    for (var sale in _globalCockSales) {
      final y = sale.date.year;
      stats.putIfAbsent(y, () => (batchRevenue: 0.0, cockRevenue: 0.0, expense: 0.0, profit: 0.0));
      final current = stats[y]!;
      stats[y] = (
        batchRevenue: current.batchRevenue,
        cockRevenue: current.cockRevenue + sale.amount,
        expense: current.expense,
        profit: 0.0,
      );
    }
    stats.updateAll(
      (y, val) => (
        batchRevenue: val.batchRevenue,
        cockRevenue: val.cockRevenue,
        expense: val.expense,
        profit: (val.batchRevenue + val.cockRevenue) - val.expense,
      ),
    );
    return stats;
  }
}
