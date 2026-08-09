import 'package:do_x/model/chicken/batch_sale.dart';
import 'package:do_x/model/chicken/chicken_batch.dart';
import 'package:do_x/model/chicken/cock_sale.dart';
import 'package:do_x/model/chicken/expense.dart';
import 'package:do_x/model/chicken/pending_op.dart';
import 'package:do_x/model/chicken/vaccination.dart';
import 'package:do_x/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A slice of the chicken data. Screens ask for the slices they show so they
/// do not pay for the rest, and each slice has its own function on the server.
enum ChickenSection {
  batches('batches', 'get_chicken_batches'),
  globalCockSales('global_cock_sales', 'get_global_cock_sales'),
  globalExpenses('global_expenses', 'get_global_expenses');

  const ChickenSection(this.wireName, this.functionName);

  /// How the server names this section in the years payload.
  final String wireName;

  /// The function that reads this section.
  final String functionName;
}

/// The result of a read. A section that was not asked for comes back null,
/// which is not the same as an empty list — that would mean the user has none.
typedef ChickenData = ({
  List<ChickenBatch>? batches,
  List<CockSale>? globalCockSales,
  List<Expense>? globalExpenses,
  Map<ChickenSection, Set<int>> years,
});

class ChickenDataSource {
  const ChickenDataSource({
    required this.ownerId,
    required this.email,
    required this.isOwner,
  });

  final String ownerId;
  final String email;
  final bool isOwner;

  factory ChickenDataSource.fromRow(Map<String, dynamic> row) =>
      ChickenDataSource(
        ownerId: row['owner_id'] as String,
        email: row['owner_email'] as String,
        isOwner: row['is_owner'] as bool,
      );
}

class ChickenShareViewer {
  const ChickenShareViewer({required this.userId, required this.email});

  final String userId;
  final String email;

  factory ChickenShareViewer.fromRow(Map<String, dynamic> row) =>
      ChickenShareViewer(
        userId: row['viewer_id'] as String,
        email: row['viewer_email'] as String,
      );
}

class ChickenRepository {
  SupabaseClient get _client => supabase;

  /// Reads the requested [sections], or all of them when [sections] is null.
  ///
  /// Each section has its own function on the server and they are fetched in
  /// parallel, so a screen pays for one request holding only what it shows.
  /// Going through functions rather than table queries also means the payload
  /// is a contract of its own: the client no longer breaks when a column or an
  /// embed is renamed. They are SECURITY INVOKER, so every table they touch is
  /// still filtered by row level security.
  ///
  /// [year] narrows the read to that year. The server widens it to the stored
  /// years `[year - 1, year]`, because a batch is grouped by its hatch date and
  /// that can land in the year after the stored incubation date — see the SQL.
  /// Stored dates are solar; the caller is the one that knows which calendar
  /// the user is filtering on, and must still apply its own exact filter.
  Future<ChickenData> getChickenData({
    Set<ChickenSection>? sections,
    int? year,
    String? ownerId,
  }) async {
    final wanted = sections ?? ChickenSection.values.toSet();
    final reads = await Future.wait([
      for (final section in wanted) _readSection(section, year, ownerId),
      _readYears(ownerId),
    ]);
    final rows = {
      for (final (index, section) in wanted.indexed)
        section: reads[index] as List,
    };
    final years = reads.last as Map<ChickenSection, Set<int>>;

    List<T>? decode<T>(
      ChickenSection section,
      T Function(Map<String, dynamic>) fromRow,
    ) => rows[section]
        ?.map((row) => fromRow(row as Map<String, dynamic>))
        .toList();

    return (
      batches: decode(ChickenSection.batches, _batchFromRow),
      globalCockSales: decode(ChickenSection.globalCockSales, _cockSaleFromRow),
      globalExpenses: decode(ChickenSection.globalExpenses, _expenseFromRow),
      years: years,
    );
  }

  Future<List<dynamic>> _readSection(
    ChickenSection section,
    int? year,
    String? ownerId,
  ) async {
    final shared = ownerId != null && ownerId != _client.auth.currentUser?.id;
    final rows = await _client.rpc(
      shared
          ? 'get_shared_${section.functionName.substring(4)}'
          : section.functionName,
      params: {'p_year': ?year, if (shared) 'p_owner_id': ownerId},
    );
    return (rows as List?) ?? const [];
  }

  /// Every year the user has records in. The year pickers are built from the
  /// data on screen, so with a year filter in place they would otherwise only
  /// ever offer the year already being shown; this keeps them complete for
  /// about a hundred bytes.
  Future<Map<ChickenSection, Set<int>>> _readYears(String? ownerId) async {
    final shared = ownerId != null && ownerId != _client.auth.currentUser?.id;
    final data =
        await _client.rpc(
              shared ? 'get_shared_chicken_years' : 'get_chicken_years',
              params: {if (shared) 'p_owner_id': ownerId},
            )
            as Map<String, dynamic>;
    return {
      for (final section in ChickenSection.values)
        section: ((data[section.wireName] as List?) ?? const [])
            .map((year) => (year as num).toInt())
            .toSet(),
    };
  }

  Future<List<ChickenDataSource>> getDataSources() async {
    final rows = await _client.rpc('get_chicken_data_sources') as List;
    return rows
        .map((row) => ChickenDataSource.fromRow(row as Map<String, dynamic>))
        .toList();
  }

  Future<List<ChickenShareViewer>> getShareViewers() async {
    final rows = await _client.rpc('get_chicken_share_viewers') as List;
    return rows
        .map((row) => ChickenShareViewer.fromRow(row as Map<String, dynamic>))
        .toList();
  }

  /// Grants read-only access, then sends a best-effort email notification.
  ///
  /// A mail-provider outage must not undo or misreport the permission that was
  /// already stored. The return value lets the UI distinguish full success
  /// from "access granted, notification pending".
  Future<bool> shareWith(String email) async {
    final normalizedEmail = email.trim();
    await _client.rpc(
      'share_chicken_data',
      params: {'p_email': normalizedEmail},
    );
    try {
      final response = await _client.functions.invoke(
        'notify-chicken-share',
        body: {'email': normalizedEmail},
      );
      final data = response.data;
      return data is Map && data['email_sent'] == true;
    } on FunctionException {
      return false;
    }
  }

  Future<void> revokeShare(String viewerId) async {
    await _client.rpc(
      'revoke_chicken_share',
      params: {'p_viewer_id': viewerId},
    );
  }

  // --- Writes ---------------------------------------------------------------
  // Every write is first described as a [PendingOp] and then executed by
  // [apply]. That indirection is what makes offline editing possible: the very
  // same value the view model tried to send can be parked in the sync queue and
  // replayed later, with no second code path to keep in step.

  /// Inserts a batch together with its vaccinations, expenses and sales.
  ///
  /// This goes through the `insert_chicken_batch` function rather than five
  /// separate table inserts: PostgREST gives the client no way to group those,
  /// so a failure part-way through used to leave a batch row on the server
  /// without its children. A function body is one transaction, so the insert
  /// now either lands whole or not at all. Row level security still applies —
  /// the function is SECURITY INVOKER and every row keeps defaulting `user_id`
  /// to `auth.uid()`.
  PendingOp insertBatchOp(ChickenBatch batch) => PendingOp(
    action: PendingOpAction.rpc,
    target: 'insert_chicken_batch',
    payload: {
      'p_batch': _batchToRow(batch),
      'p_vaccinations': batch.vaccinations
          .map((v) => _vaccinationToRow(v, batch.id))
          .toList(),
      'p_expenses': batch.expenses
          .map((e) => _expenseToRow(e, batch.id))
          .toList(),
      'p_cock_sales': batch.cockSales
          .map((s) => _cockSaleToRow(s, batch.id))
          .toList(),
      'p_batch_sales': batch.sales
          .map((s) => _batchSaleToRow(s, batch.id))
          .toList(),
    },
  );

  /// Updates the batch's own fields only. Expenses, vaccinations and sales are
  /// managed through their dedicated operations.
  PendingOp updateBatchOp(ChickenBatch batch) => PendingOp(
    action: PendingOpAction.update,
    target: 'chicken_batches',
    rowId: batch.id,
    payload: _batchToRow(batch),
  );

  PendingOp deleteBatchOp(String id) => PendingOp(
    action: PendingOpAction.delete,
    target: 'chicken_batches',
    rowId: id,
  );

  /// One op per vaccination whose date moved with the incubation date.
  List<PendingOp> updateVaccinationDateOps(List<Vaccination> vaccinations) => [
    for (final vaccination in vaccinations)
      PendingOp(
        action: PendingOpAction.update,
        target: 'vaccinations',
        rowId: vaccination.id,
        payload: {'scheduled_date': _dateStr(vaccination.scheduledDate)},
      ),
  ];

  PendingOp setVaccinationCompletedOp(String id, bool isCompleted) => PendingOp(
    action: PendingOpAction.update,
    target: 'vaccinations',
    rowId: id,
    payload: {'is_completed': isCompleted},
  );

  PendingOp insertBatchSaleOp(String batchId, BatchSale sale) => PendingOp(
    action: PendingOpAction.insert,
    target: 'batch_sales',
    payload: _batchSaleToRow(sale, batchId),
  );

  PendingOp updateBatchSaleOp(BatchSale sale) => PendingOp(
    action: PendingOpAction.update,
    target: 'batch_sales',
    rowId: sale.id,
    payload: {
      'date': _dateStr(sale.date),
      'quantity': sale.quantity,
      'amount': sale.amount,
      'note': sale.note,
    },
  );

  PendingOp deleteBatchSaleOp(String id) => PendingOp(
    action: PendingOpAction.delete,
    target: 'batch_sales',
    rowId: id,
  );

  /// [batchId] null means a global expense (not tied to any batch).
  PendingOp insertExpenseOp(String? batchId, Expense expense) => PendingOp(
    action: PendingOpAction.insert,
    target: 'expenses',
    payload: _expenseToRow(expense, batchId),
  );

  /// [globalRecord] scopes the write to the signed-in user's batch-less
  /// records, the way the global expense screen needs it.
  PendingOp updateExpenseOp(Expense expense, {bool globalRecord = false}) =>
      PendingOp(
        action: PendingOpAction.update,
        target: 'expenses',
        rowId: expense.id,
        globalRecord: globalRecord,
        payload: {
          'type': expense.type.name,
          'amount': expense.amount,
          'date': _dateStr(expense.date),
          'note': expense.note,
        },
      );

  PendingOp deleteExpenseOp(String id, {bool globalRecord = false}) =>
      PendingOp(
        action: PendingOpAction.delete,
        target: 'expenses',
        rowId: id,
        globalRecord: globalRecord,
      );

  /// [batchId] null means a global cock sale (not tied to any batch).
  PendingOp insertCockSaleOp(String? batchId, CockSale sale) => PendingOp(
    action: PendingOpAction.insert,
    target: 'cock_sales',
    payload: _cockSaleToRow(sale, batchId),
  );

  PendingOp updateCockSaleOp(CockSale sale, {bool globalRecord = false}) =>
      PendingOp(
        action: PendingOpAction.update,
        target: 'cock_sales',
        rowId: sale.id,
        globalRecord: globalRecord,
        payload: {
          'note': sale.note,
          'amount': sale.amount,
          'date': _dateStr(sale.date),
          'category': sale.category.name,
        },
      );

  PendingOp deleteCockSaleOp(String id, {bool globalRecord = false}) =>
      PendingOp(
        action: PendingOpAction.delete,
        target: 'cock_sales',
        rowId: id,
        globalRecord: globalRecord,
      );

  /// Executes one write against the server. Throws if it does not land: a
  /// [globalRecord] write that matches no row is a failure, because the record
  /// it was meant to change is not there (or is not the caller's).
  Future<void> apply(PendingOp op) async {
    switch (op.action) {
      case PendingOpAction.rpc:
        await _client.rpc(op.target, params: op.payload);
      case PendingOpAction.insert:
        await _client.from(op.target).insert(op.payload);
      case PendingOpAction.update:
        final query = _client
            .from(op.target)
            .update(op.payload)
            .eq('id', op.rowId!);
        final updated =
            await (op.globalRecord ? _scopeToOwnGlobalRecords(query) : query)
                .select('id')
                .maybeSingle();
        if (updated == null) {
          throw StateError('Không tìm thấy bản ghi để cập nhật.');
        }
      case PendingOpAction.delete:
        final query = _client.from(op.target).delete().eq('id', op.rowId!);
        final deleted =
            await (op.globalRecord ? _scopeToOwnGlobalRecords(query) : query)
                .select('id')
                .maybeSingle();
        if (deleted == null) throw StateError('Không tìm thấy bản ghi để xóa.');
    }
  }

  /// Narrows a write to records of the signed-in user that belong to no batch.
  PostgrestFilterBuilder<T> _scopeToOwnGlobalRecords<T>(
    PostgrestFilterBuilder<T> query,
  ) {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Bạn cần đăng nhập để sửa dữ liệu.');
    return query.eq('user_id', userId).isFilter('batch_id', null);
  }

  Future<void> insertBatch(
    ChickenBatch batch, {
    void Function(int count)? onInserted,
  }) async {
    final op = insertBatchOp(batch);
    await apply(op);
    // One request, so progress is reported once the whole batch is in.
    onInserted?.call(op.recordCount);
  }

  Future<void> insertCockSale(String? batchId, CockSale sale) =>
      apply(insertCockSaleOp(batchId, sale));

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
    final deleted = await _client.rpc('delete_all_chicken_data');
    return (deleted as num).toInt();
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
