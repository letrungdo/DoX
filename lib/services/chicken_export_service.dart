import 'dart:convert';

import 'package:do_x/model/chicken/batch_sale.dart';
import 'package:do_x/model/chicken/chicken_batch.dart';
import 'package:do_x/model/chicken/cock_sale.dart';
import 'package:do_x/model/chicken/expense.dart';
import 'package:do_x/model/chicken/vaccination.dart';

/// Writes the file [ChickenImportService] reads back.
///
/// Deliberately not the models' own `toJson()`: those carry the row ids and
/// the server's field names, while the import format is id-free (every record
/// is inserted fresh) and names a few fields differently. Keep the two in step
/// — a field added here has to be parsed there, and the other way round.
class ChickenExportService {
  static const _encoder = JsonEncoder.withIndent('  ');

  static String encode({
    required List<ChickenBatch> batches,
    required List<CockSale> globalSales,
    required List<Expense> globalExpenses,
  }) {
    return _encoder.convert({
      // The import refuses a file without this: a lunar date cannot record the
      // leap-month flag, so it has to be told the dates below are solar.
      'dateCalendar': 'solar',
      'batches': batches.map(_batch).toList(),
      'cockSales': globalSales.map(_sale).toList(),
      'expenses': globalExpenses.map(_expense).toList(),
    });
  }

  static Map<String, dynamic> _batch(ChickenBatch batch) => {
    'name': batch.name,
    'incubationDate': _date(batch.incubationDate),
    'quantity': batch.quantity,
    if (batch.actualHatchDate != null)
      'actualHatchDate': _date(batch.actualHatchDate!),
    if (batch.sales.isNotEmpty) 'sales': batch.sales.map(_batchSale).toList(),
    if (batch.vaccinations.isNotEmpty)
      'vaccinations': batch.vaccinations.map(_vaccination).toList(),
    if (batch.expenses.isNotEmpty)
      'expenses': batch.expenses.map(_expense).toList(),
    if (batch.cockSales.isNotEmpty)
      'cockSales': batch.cockSales.map(_sale).toList(),
  };

  static Map<String, dynamic> _batchSale(BatchSale sale) => {
    'date': _date(sale.date),
    'quantity': sale.quantity,
    'amount': sale.amount,
    if (sale.note != null && sale.note!.isNotEmpty) 'note': sale.note,
  };

  static Map<String, dynamic> _vaccination(Vaccination vaccination) => {
    'title': vaccination.title,
    'date': _date(vaccination.scheduledDate),
    'completed': vaccination.isCompleted,
  };

  static Map<String, dynamic> _expense(Expense expense) => {
    'type': expense.type.name,
    'amount': expense.amount,
    'date': _date(expense.date),
    if (expense.note != null && expense.note!.isNotEmpty) 'note': expense.note,
  };

  static Map<String, dynamic> _sale(CockSale sale) => {
    'amount': sale.amount,
    'date': _date(sale.date),
    if (sale.note.isNotEmpty) 'note': sale.note,
    'category': sale.category.name,
  };

  /// Day precision, which is all any of these dates carry — and far easier to
  /// read than a full timestamp if the file is ever edited by hand.
  static String _date(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
