import 'dart:convert';

import 'package:do_x/model/chicken/batch_sale.dart';
import 'package:do_x/model/chicken/chicken_batch.dart';
import 'package:do_x/model/chicken/cock_sale.dart';
import 'package:do_x/model/chicken/expense.dart';
import 'package:do_x/model/chicken/vaccination.dart';
import 'package:uuid/uuid.dart';

class ChickenImportData {
  final List<ChickenBatch> batches;
  final List<CockSale> globalSales;
  final List<Expense> globalExpenses;

  ChickenImportData({required this.batches, required this.globalSales, required this.globalExpenses});

  int get totalRecords =>
      batches.length +
      globalSales.length +
      globalExpenses.length +
      batches.fold(0, (sum, b) => sum + b.sales.length + b.vaccinations.length + b.expenses.length + b.cockSales.length);
}

/// Parses the chicken import JSON format (all ids are generated on import):
/// {
///   "batches": [{ "name", "incubationDate", "quantity", "actualHatchDate"?,
///                 "sales"?: [{"date", "amount", "quantity"?, "note"?}],
///                 "vaccinations"?: [{"title", "date", "completed"?}],
///                 "expenses"?: [{"type", "amount", "date", "note"?}],
///                 "cockSales"?: [{"amount", "date", "note"?, "category"?}] }],
///   "cockSales": [...],   // global sales (gà đá / gà thịt)
///   "expenses": [...]     // global expenses (cám, thuốc... không gắn bầy)
/// }
class ChickenImportService {
  static const _uuid = Uuid();

  static ChickenImportData parse(String jsonString) {
    final root = jsonDecode(jsonString) as Map<String, dynamic>;
    final batches = ((root['batches'] as List?) ?? []).map((e) => _parseBatch(e)).toList();
    final globalSales = ((root['cockSales'] as List?) ?? []).map((e) => _parseSale(e)).toList();
    final globalExpenses = ((root['expenses'] as List?) ?? []).map((e) => _parseExpense(e)).toList();
    return ChickenImportData(batches: batches, globalSales: globalSales, globalExpenses: globalExpenses);
  }

  static ChickenBatch _parseBatch(Map<String, dynamic> json) {
    return ChickenBatch(
      id: _uuid.v4(),
      name: json['name'] as String,
      incubationDate: DateTime.parse(json['incubationDate'] as String),
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      actualHatchDate: _date(json['actualHatchDate']),
      sales: ((json['sales'] as List?) ?? []).map((e) => _parseBatchSale(e)).toList(),
      vaccinations: ((json['vaccinations'] as List?) ?? []).map((e) => _parseVaccination(e)).toList(),
      expenses: ((json['expenses'] as List?) ?? []).map((e) => _parseExpense(e)).toList(),
      cockSales: ((json['cockSales'] as List?) ?? []).map((e) => _parseSale(e)).toList(),
    );
  }

  static BatchSale _parseBatchSale(Map<String, dynamic> json) => BatchSale(
    id: _uuid.v4(),
    date: DateTime.parse(json['date'] as String),
    quantity: (json['quantity'] as num?)?.toInt() ?? 0,
    amount: (json['amount'] as num).toDouble(),
    note: json['note'] as String?,
  );

  static Vaccination _parseVaccination(Map<String, dynamic> json) => Vaccination(
    id: _uuid.v4(),
    title: json['title'] as String,
    scheduledDate: DateTime.parse(json['date'] as String),
    isCompleted: json['completed'] as bool? ?? false,
  );

  static Expense _parseExpense(Map<String, dynamic> json) => Expense(
    id: _uuid.v4(),
    type: ExpenseType.values.asNameMap()[json['type']] ?? ExpenseType.other,
    amount: (json['amount'] as num).toDouble(),
    date: DateTime.parse(json['date'] as String),
    note: json['note'] as String?,
  );

  static CockSale _parseSale(Map<String, dynamic> json) => CockSale(
    id: _uuid.v4(),
    note: json['note'] as String? ?? '',
    amount: (json['amount'] as num).toDouble(),
    date: DateTime.parse(json['date'] as String),
    category: SaleCategory.values.asNameMap()[json['category']] ?? SaleCategory.fighting,
  );

  static DateTime? _date(dynamic value) => value == null ? null : DateTime.parse(value as String);
}
