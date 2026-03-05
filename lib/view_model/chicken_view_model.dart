import 'package:collection/collection.dart';
import 'package:do_x/model/chicken/chicken_batch.dart';
import 'package:do_x/model/chicken/cock_sale.dart';
import 'package:do_x/model/chicken/expense.dart';
import 'package:do_x/model/chicken/vaccination.dart';
import 'package:do_x/repository/chicken_repository.dart';
import 'package:do_x/services/google_sync_service.dart';
import 'package:do_x/view_model/core/core_view_model.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

class ChickenViewModel extends CoreViewModel {
  final ChickenRepository _repository = ChickenRepository();
  final _uuid = const Uuid();

  List<ChickenBatch> _batches = [];
  List<ChickenBatch> get batches => _batches;

  List<CockSale> _globalCockSales = [];
  List<CockSale> get globalCockSales => _globalCockSales;

  @override
  void initData() async {
    super.initData();
    setBusy(true);
    _batches = await _repository.getBatches();
    _globalCockSales = await _repository.getCockSales();
    setBusy(false);
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
    await _repository.saveBatches(_batches);
    notifyListenersSafe();
  }

  Future<void> updateBatch(ChickenBatch batch) async {
    final index = _batches.indexWhere((e) => e.id == batch.id);
    if (index != -1) {
      _batches[index] = batch;
      await _repository.saveBatches(_batches);
      notifyListenersSafe();
    }
  }

  Future<void> deleteBatch(String id) async {
    final batch = _batches.firstWhereOrNull((e) => e.id == id);
    if (batch != null) {
      if (googleSyncService.currentUser != null) {
        googleSyncService.deleteTaskList(batch.name);
      }
      _batches.removeWhere((e) => e.id == id);
      await _repository.saveBatches(_batches);
      notifyListenersSafe();
    }
  }

  Future<void> addExpense(String batchId, Expense expense) async {
    final index = _batches.indexWhere((e) => e.id == batchId);
    if (index != -1) {
      final updatedExpenses = List<Expense>.from(_batches[index].expenses)..add(expense);
      _batches[index] = _batches[index].copyWith(expenses: updatedExpenses);
      await _repository.saveBatches(_batches);
      notifyListenersSafe();
    }
  }

  Future<void> addCockSale(String batchId, CockSale sale) async {
    final index = _batches.indexWhere((e) => e.id == batchId);
    if (index != -1) {
      final updatedSales = List<CockSale>.from(_batches[index].cockSales)..add(sale);
      _batches[index] = _batches[index].copyWith(cockSales: updatedSales);
      await _repository.saveBatches(_batches);
      notifyListenersSafe();
    }
  }

  Future<void> addGlobalCockSale(CockSale sale) async {
    _globalCockSales.add(sale);
    await _repository.saveCockSales(_globalCockSales);
    notifyListenersSafe();
  }

  Future<void> toggleVaccination(String batchId, String vaccinationId) async {
    final index = _batches.indexWhere((e) => e.id == batchId);
    if (index != -1) {
      final updatedVaccinations = _batches[index].vaccinations.map((v) {
        if (v.id == vaccinationId) {
          return v.copyWith(isCompleted: !v.isCompleted);
        }
        return v;
      }).toList();
      _batches[index] = _batches[index].copyWith(vaccinations: updatedVaccinations);
      await _repository.saveBatches(_batches);
      notifyListenersSafe();

      if (googleSyncService.currentUser != null) {
        syncToGoogle();
      }
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

  Future<void> syncToGoogle() async {
    showLoading();
    try {
      await googleSyncService.syncToGoogleTasks(_batches);
      final success = await googleSyncService.backupToDrive(_batches, _globalCockSales);
      hideLoading();
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Đã sao lưu lên Google Cloud")));
      }
    } catch (e) {
      hideLoading();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Lỗi sao lưu: $e")));
    }
  }

  Future<void> restoreFromGoogle() async {
    showLoading();
    try {
      final data = await googleSyncService.restoreFromDrive();
      hideLoading();
      if (data != null) {
        final List<dynamic> batchJson = data['batches'] ?? [];
        final List<dynamic> cockSaleJson = data['cockSales'] ?? [];
        _batches = batchJson.map((e) => ChickenBatch.fromJson(e)).toList();
        _globalCockSales = cockSaleJson.map((e) => CockSale.fromJson(e)).toList();
        await _repository.saveBatches(_batches);
        await _repository.saveCockSales(_globalCockSales);
        notifyListenersSafe();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Đã khôi phục dữ liệu")));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Không tìm thấy bản sao lưu")));
      }
    } catch (e) {
      hideLoading();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Lỗi khôi phục: $e")));
    }
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
