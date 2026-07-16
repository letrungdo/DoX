import 'package:do_x/model/chicken/chicken_batch.dart';
import 'package:do_x/model/chicken/cock_sale.dart';
import 'package:do_x/model/chicken/expense.dart';
import 'package:do_x/model/chicken/vaccination.dart';
import 'package:do_x/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChickenRepository {
  SupabaseClient get _client => supabase;

  Future<List<ChickenBatch>> getBatches() async {
    final rows = await _client
        .from('chicken_batches')
        .select('*, vaccinations(*), expenses(*), cock_sales(*)')
        .order('incubation_date', ascending: false);
    return rows.map(_batchFromRow).toList();
  }

  Future<void> insertBatch(ChickenBatch batch) async {
    await _client.from('chicken_batches').insert(_batchToRow(batch));
    if (batch.vaccinations.isNotEmpty) {
      await _client.from('vaccinations').insert(batch.vaccinations.map((v) => _vaccinationToRow(v, batch.id)).toList());
    }
    if (batch.expenses.isNotEmpty) {
      await _client.from('expenses').insert(batch.expenses.map((e) => _expenseToRow(e, batch.id)).toList());
    }
    if (batch.cockSales.isNotEmpty) {
      await _client.from('cock_sales').insert(batch.cockSales.map((s) => _cockSaleToRow(s, batch.id)).toList());
    }
  }

  /// Updates the batch's own fields only. Expenses, vaccinations and cock
  /// sales are managed through their dedicated methods.
  Future<void> updateBatch(ChickenBatch batch) async {
    await _client.from('chicken_batches').update(_batchToRow(batch)).eq('id', batch.id);
  }

  Future<void> deleteBatch(String id) async {
    await _client.from('chicken_batches').delete().eq('id', id);
  }

  Future<void> insertExpense(String batchId, Expense expense) async {
    await _client.from('expenses').insert(_expenseToRow(expense, batchId));
  }

  /// [batchId] null means a global cock sale (not tied to any batch).
  Future<void> insertCockSale(String? batchId, CockSale sale) async {
    await _client.from('cock_sales').insert(_cockSaleToRow(sale, batchId));
  }

  Future<void> setVaccinationCompleted(String id, bool isCompleted) async {
    await _client.from('vaccinations').update({'is_completed': isCompleted}).eq('id', id);
  }

  Future<List<CockSale>> getGlobalCockSales() async {
    final rows = await _client
        .from('cock_sales')
        .select()
        .isFilter('batch_id', null)
        .order('date', ascending: false);
    return rows.map(_cockSaleFromRow).toList();
  }

  /// Replaces all remote data of the current user (used by Google Drive restore).
  Future<void> replaceAll(List<ChickenBatch> batches, List<CockSale> globalSales) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    await _client.from('cock_sales').delete().eq('user_id', userId);
    await _client.from('chicken_batches').delete().eq('user_id', userId);
    for (final batch in batches) {
      await insertBatch(batch);
    }
    for (final sale in globalSales) {
      await insertCockSale(null, sale);
    }
  }

  // ---- Row mapping (Supabase snake_case <-> app models) ----

  static String? _dateStr(DateTime? date) => date?.toIso8601String().substring(0, 10);

  static DateTime? _parseDate(dynamic value) => value == null ? null : DateTime.parse(value as String);

  Map<String, dynamic> _batchToRow(ChickenBatch b) => {
    'id': b.id,
    'name': b.name,
    'incubation_date': _dateStr(b.incubationDate),
    'quantity': b.quantity,
    'actual_hatch_date': _dateStr(b.actualHatchDate),
    'sale_date': _dateStr(b.saleDate),
    'total_sale_amount': b.totalSaleAmount,
    'sale_quantity': b.saleQuantity,
  };

  ChickenBatch _batchFromRow(Map<String, dynamic> row) {
    final vaccinations = ((row['vaccinations'] as List?) ?? []).map((e) => _vaccinationFromRow(e)).toList()
      ..sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));
    final expenses = ((row['expenses'] as List?) ?? []).map((e) => _expenseFromRow(e)).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final cockSales = ((row['cock_sales'] as List?) ?? []).map((e) => _cockSaleFromRow(e)).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return ChickenBatch(
      id: row['id'],
      name: row['name'],
      incubationDate: _parseDate(row['incubation_date'])!,
      quantity: row['quantity'],
      vaccinations: vaccinations,
      expenses: expenses,
      cockSales: cockSales,
      actualHatchDate: _parseDate(row['actual_hatch_date']),
      saleDate: _parseDate(row['sale_date']),
      totalSaleAmount: (row['total_sale_amount'] as num?)?.toDouble(),
      saleQuantity: row['sale_quantity'],
    );
  }

  Map<String, dynamic> _vaccinationToRow(Vaccination v, String batchId) => {
    'id': v.id,
    'batch_id': batchId,
    'title': v.title,
    'scheduled_date': _dateStr(v.scheduledDate),
    'is_completed': v.isCompleted,
  };

  Vaccination _vaccinationFromRow(Map<String, dynamic> row) => Vaccination(
    id: row['id'],
    title: row['title'],
    scheduledDate: _parseDate(row['scheduled_date'])!,
    isCompleted: row['is_completed'] ?? false,
  );

  Map<String, dynamic> _expenseToRow(Expense e, String batchId) => {
    'id': e.id,
    'batch_id': batchId,
    'type': e.type.name,
    'amount': e.amount,
    'date': _dateStr(e.date),
    'note': e.note,
  };

  Expense _expenseFromRow(Map<String, dynamic> row) => Expense(
    id: row['id'],
    type: ExpenseType.values.asNameMap()[row['type']] ?? ExpenseType.other,
    amount: (row['amount'] as num).toDouble(),
    date: _parseDate(row['date'])!,
    note: row['note'],
  );

  Map<String, dynamic> _cockSaleToRow(CockSale s, String? batchId) => {
    'id': s.id,
    'batch_id': batchId,
    'note': s.note,
    'amount': s.amount,
    'date': _dateStr(s.date),
  };

  CockSale _cockSaleFromRow(Map<String, dynamic> row) => CockSale(
    id: row['id'],
    note: row['note'] ?? '',
    amount: (row['amount'] as num).toDouble(),
    date: _parseDate(row['date'])!,
  );
}
