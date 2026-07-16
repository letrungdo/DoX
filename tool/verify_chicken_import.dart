// ignore_for_file: avoid_print
import 'dart:io';

import 'package:do_x/services/chicken_import_service.dart';

void main() {
  final json = File('import_data/chicken_import_2023_2026.json').readAsStringSync();
  final data = ChickenImportService.parse(json);
  print('batches: ${data.batches.length}');
  print('globalSales: ${data.globalSales.length}');
  print('globalExpenses: ${data.globalExpenses.length}');
  print('totalRecords: ${data.totalRecords}');
  final vaccs = data.batches.fold(0, (s, b) => s + b.vaccinations.length);
  final batchSales = data.batches.fold(0, (s, b) => s + b.sales.length);
  print('vaccinations in batches: $vaccs');
  print('sales in batches: $batchSales');
}
