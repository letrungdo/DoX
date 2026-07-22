import 'package:do_x/model/chicken/batch_sale.dart';
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
        .select(
          '*, vaccinations(*), expenses(*), cock_sales(*), batch_sales(*)',
        )
        .order('incubation_date', ascending: false)
        .order('created_at', ascending: false);
    return rows.map(_batchFromRow).toList();
  }

  Future<void> insertBatch(
    ChickenBatch batch, {
    void Function(int count)? onInserted,
  }) async {
    await _client.from('chicken_batches').insert(_batchToRow(batch));
    onInserted?.call(1);
    if (batch.vaccinations.isNotEmpty) {
      await _client
          .from('vaccinations')
          .insert(
            batch.vaccinations
                .map((v) => _vaccinationToRow(v, batch.id))
                .toList(),
          );
      onInserted?.call(batch.vaccinations.length);
    }
    if (batch.expenses.isNotEmpty) {
      await _client
          .from('expenses')
          .insert(
            batch.expenses.map((e) => _expenseToRow(e, batch.id)).toList(),
          );
      onInserted?.call(batch.expenses.length);
    }
    if (batch.cockSales.isNotEmpty) {
      await _client
          .from('cock_sales')
          .insert(
            batch.cockSales.map((s) => _cockSaleToRow(s, batch.id)).toList(),
          );
      onInserted?.call(batch.cockSales.length);
    }
    if (batch.sales.isNotEmpty) {
      await _client
          .from('batch_sales')
          .insert(
            batch.sales.map((s) => _batchSaleToRow(s, batch.id)).toList(),
          );
      onInserted?.call(batch.sales.length);
    }
  }

  Future<void> insertBatchSale(String batchId, BatchSale sale) async {
    await _client.from('batch_sales').insert(_batchSaleToRow(sale, batchId));
  }

  Future<void> updateBatchSale(BatchSale sale) async {
    await _client
        .from('batch_sales')
        .update({
          'date': _dateStr(sale.date),
          'quantity': sale.quantity,
          'amount': sale.amount,
          'note': sale.note,
        })
        .eq('id', sale.id);
  }

  Future<void> deleteBatchSale(String id) async {
    await _client.from('batch_sales').delete().eq('id', id);
  }

  /// Updates the batch's own fields only. Expenses, vaccinations and cock
  /// sales are managed through their dedicated methods.
  Future<void> updateBatch(ChickenBatch batch) async {
    await _client
        .from('chicken_batches')
        .update(_batchToRow(batch))
        .eq('id', batch.id);
  }

  Future<void> updateVaccinationDates(List<Vaccination> vaccinations) async {
    for (final vaccination in vaccinations) {
      await _client
          .from('vaccinations')
          .update({'scheduled_date': _dateStr(vaccination.scheduledDate)})
          .eq('id', vaccination.id);
    }
  }

  Future<void> deleteBatch(String id) async {
    await _client.from('chicken_batches').delete().eq('id', id);
  }

  /// [batchId] null means a global expense (not tied to any batch).
  Future<void> insertExpense(String? batchId, Expense expense) async {
    await _client.from('expenses').insert(_expenseToRow(expense, batchId));
  }

  Future<void> updateExpense(Expense expense) async {
    await _client
        .from('expenses')
        .update({
          'type': expense.type.name,
          'amount': expense.amount,
          'date': _dateStr(expense.date),
          'note': expense.note,
        })
        .eq('id', expense.id);
  }

  Future<void> deleteExpense(String id) async {
    await _client.from('expenses').delete().eq('id', id);
  }

  Future<void> updateGlobalExpense(Expense expense) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Bạn cần đăng nhập để sửa chi phí.');
    final updated = await _client
        .from('expenses')
        .update({
          'type': expense.type.name,
          'amount': expense.amount,
          'date': _dateStr(expense.date),
          'note': expense.note,
        })
        .eq('id', expense.id)
        .eq('user_id', userId)
        .isFilter('batch_id', null)
        .select('id')
        .maybeSingle();
    if (updated == null) {
      throw StateError('Không tìm thấy chi phí để cập nhật.');
    }
  }

  Future<void> deleteGlobalExpense(String id) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Bạn cần đăng nhập để xóa chi phí.');
    final deleted = await _client
        .from('expenses')
        .delete()
        .eq('id', id)
        .eq('user_id', userId)
        .isFilter('batch_id', null)
        .select('id')
        .maybeSingle();
    if (deleted == null) throw StateError('Không tìm thấy chi phí để xóa.');
  }

  Future<List<Expense>> getGlobalExpenses() async {
    final rows = await _client
        .from('expenses')
        .select()
        .isFilter('batch_id', null)
        .order('date', ascending: false)
        .order('created_at', ascending: false);
    return rows.map(_expenseFromRow).toList();
  }

  /// [batchId] null means a global cock sale (not tied to any batch).
  Future<void> insertCockSale(String? batchId, CockSale sale) async {
    await _client.from('cock_sales').insert(_cockSaleToRow(sale, batchId));
  }

  Future<void> updateGlobalCockSale(CockSale sale) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Bạn cần đăng nhập để sửa lượt bán.');
    final updated = await _client
        .from('cock_sales')
        .update({
          'note': sale.note,
          'amount': sale.amount,
          'date': _dateStr(sale.date),
          'category': sale.category.name,
        })
        .eq('id', sale.id)
        .eq('user_id', userId)
        .isFilter('batch_id', null)
        .select('id')
        .maybeSingle();
    if (updated == null) {
      throw StateError('Không tìm thấy lượt bán để cập nhật.');
    }
  }

  Future<void> deleteGlobalCockSale(String id) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Bạn cần đăng nhập để xóa lượt bán.');
    final deleted = await _client
        .from('cock_sales')
        .delete()
        .eq('id', id)
        .eq('user_id', userId)
        .isFilter('batch_id', null)
        .select('id')
        .maybeSingle();
    if (deleted == null) throw StateError('Không tìm thấy lượt bán để xóa.');
  }

  Future<void> setVaccinationCompleted(String id, bool isCompleted) async {
    await _client
        .from('vaccinations')
        .update({'is_completed': isCompleted})
        .eq('id', id);
  }

  Future<List<CockSale>> getGlobalCockSales() async {
    final rows = await _client
        .from('cock_sales')
        .select()
        .isFilter('batch_id', null)
        .order('date', ascending: false)
        .order('created_at', ascending: false);
    return rows.map(_cockSaleFromRow).toList();
  }

  /// Inserts imported data additively (batches with children, global sales, global expenses).
  Future<void> importData({
    List<ChickenBatch> batches = const [],
    List<CockSale> globalSales = const [],
    List<Expense> globalExpenses = const [],
    void Function(int completed, int total)? onProgress,
  }) async {
    final total =
        batches.length +
        globalSales.length +
        globalExpenses.length +
        batches.fold<int>(
          0,
          (sum, batch) =>
              sum +
              batch.sales.length +
              batch.vaccinations.length +
              batch.expenses.length +
              batch.cockSales.length,
        );
    var completed = 0;

    void reportProgress(int count) {
      completed += count;
      onProgress?.call(completed, total);
    }

    for (final batch in batches) {
      await insertBatch(batch, onInserted: reportProgress);
    }
    if (globalSales.isNotEmpty) {
      await _client
          .from('cock_sales')
          .insert(globalSales.map((s) => _cockSaleToRow(s, null)).toList());
      reportProgress(globalSales.length);
    }
    if (globalExpenses.isNotEmpty) {
      await _client
          .from('expenses')
          .insert(globalExpenses.map((e) => _expenseToRow(e, null)).toList());
      reportProgress(globalExpenses.length);
    }
  }

  Future<int> deleteAllData() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return 0;

    var deletedCount = 0;

    Future<void> deleteRows(String table) async {
      final deleted = await _client
          .from(table)
          .delete()
          .eq('user_id', userId)
          .select('id');
      deletedCount += deleted.length;
    }

    await deleteRows('cock_sales');
    await deleteRows('expenses');
    await deleteRows('chicken_batches');
    return deletedCount;
  }

  /// Replaces all remote data of the current user (used by Google Drive restore).
  Future<void> replaceAll(
    List<ChickenBatch> batches,
    List<CockSale> globalSales,
  ) async {
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

  static String? _dateStr(DateTime? date) =>
      date?.toIso8601String().substring(0, 10);

  static DateTime? _parseDate(dynamic value) =>
      value == null ? null : DateTime.parse(value as String);

  Map<String, dynamic> _batchToRow(ChickenBatch b) => {
    'id': b.id,
    'name': b.name,
    'incubation_date': _dateStr(b.incubationDate),
    'quantity': b.quantity,
    'actual_hatch_date': _dateStr(b.actualHatchDate),
  };

  ChickenBatch _batchFromRow(Map<String, dynamic> row) {
    final vaccinations =
        ((row['vaccinations'] as List?) ?? [])
            .map((e) => _vaccinationFromRow(e))
            .toList()
          ..sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));
    final expenses =
        ((row['expenses'] as List?) ?? [])
            .map((e) => _expenseFromRow(e))
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    final cockSales =
        ((row['cock_sales'] as List?) ?? [])
            .map((e) => _cockSaleFromRow(e))
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    final sales =
        ((row['batch_sales'] as List?) ?? [])
            .map((e) => _batchSaleFromRow(e))
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    return ChickenBatch(
      id: row['id'],
      name: row['name'],
      incubationDate: _parseDate(row['incubation_date'])!,
      quantity: row['quantity'],
      vaccinations: vaccinations,
      expenses: expenses,
      cockSales: cockSales,
      sales: sales,
      actualHatchDate: _parseDate(row['actual_hatch_date']),
    );
  }

  Map<String, dynamic> _batchSaleToRow(BatchSale s, String batchId) => {
    'id': s.id,
    'batch_id': batchId,
    'date': _dateStr(s.date),
    'quantity': s.quantity,
    'amount': s.amount,
    'note': s.note,
  };

  BatchSale _batchSaleFromRow(Map<String, dynamic> row) => BatchSale(
    id: row['id'],
    date: _parseDate(row['date'])!,
    quantity: row['quantity'] ?? 0,
    amount: (row['amount'] as num).toDouble(),
    note: row['note'],
  );

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

  Map<String, dynamic> _expenseToRow(Expense e, String? batchId) => {
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
    'category': s.category.name,
  };

  CockSale _cockSaleFromRow(Map<String, dynamic> row) => CockSale(
    id: row['id'],
    note: row['note'] ?? '',
    amount: (row['amount'] as num).toDouble(),
    date: _parseDate(row['date'])!,
    category:
        SaleCategory.values.asNameMap()[row['category']] ??
        SaleCategory.fighting,
  );
}
