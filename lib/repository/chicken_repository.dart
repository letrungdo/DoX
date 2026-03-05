import 'dart:convert';

import 'package:do_x/model/chicken/chicken_batch.dart';
import 'package:do_x/model/chicken/cock_sale.dart';
import 'package:do_x/services/storage_service.dart';

class ChickenRepository {
  static const String _storageKey = 'chicken_batches';
  static const String _cockSalesKey = 'cock_sales';

  Future<List<ChickenBatch>> getBatches() async {
    final raw = storageService.prefs.getString(_storageKey);
    if (raw == null) return [];

    final List<dynamic> jsonList = jsonDecode(raw);
    return jsonList.map((e) => ChickenBatch.fromJson(e)).toList();
  }

  Future<void> saveBatches(List<ChickenBatch> batches) async {
    final jsonList = batches.map((e) => e.toJson()).toList();
    await storageService.prefs.setString(_storageKey, jsonEncode(jsonList));
  }

  Future<void> addBatch(ChickenBatch batch) async {
    final batches = await getBatches();
    batches.add(batch);
    await saveBatches(batches);
  }

  Future<void> updateBatch(ChickenBatch batch) async {
    final batches = await getBatches();
    final index = batches.indexWhere((e) => e.id == batch.id);
    if (index != -1) {
      batches[index] = batch;
      await saveBatches(batches);
    }
  }

  Future<void> deleteBatch(String id) async {
    final batches = await getBatches();
    batches.removeWhere((e) => e.id == id);
    await saveBatches(batches);
  }

  Future<List<CockSale>> getCockSales() async {
    final raw = storageService.prefs.getString(_cockSalesKey);
    if (raw == null) return [];
    final List<dynamic> jsonList = jsonDecode(raw);
    return jsonList.map((e) => CockSale.fromJson(e)).toList();
  }

  Future<void> saveCockSales(List<CockSale> sales) async {
    final jsonList = sales.map((e) => e.toJson()).toList();
    await storageService.prefs.setString(_cockSalesKey, jsonEncode(jsonList));
  }
}
