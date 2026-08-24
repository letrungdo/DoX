import 'package:do_x/model/asset/asset_gold.dart';
import 'package:do_x/model/asset/asset_investment.dart';
import 'package:do_x/model/asset/asset_saving.dart';
import 'package:do_x/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AssetRepository {
  SupabaseClient get _client => supabase;

  // Savings
  Future<List<AssetSaving>> getSavings() async {
    final response = await _client
        .from('asset_savings')
        .select()
        .order('created_at', ascending: false);
    return (response as List).map((e) => AssetSaving.fromJson(e)).toList();
  }

  Future<void> upsertSaving(AssetSaving saving) async {
    await _client.from('asset_savings').upsert(saving.toJson());
  }

  Future<void> deleteSaving(String id) async {
    await _client.from('asset_savings').delete().eq('id', id);
  }

  // Investments
  Future<List<AssetInvestment>> getInvestments() async {
    final response = await _client
        .from('asset_investments')
        .select()
        .order('created_at', ascending: false);
    return (response as List).map((e) => AssetInvestment.fromJson(e)).toList();
  }

  Future<void> upsertInvestment(AssetInvestment investment) async {
    await _client.from('asset_investments').upsert(investment.toJson());
  }

  Future<void> deleteInvestment(String id) async {
    await _client.from('asset_investments').delete().eq('id', id);
  }

  // Gold
  Future<List<AssetGold>> getGold() async {
    final response = await _client
        .from('asset_gold')
        .select()
        .order('created_at', ascending: false);
    return (response as List).map((e) => AssetGold.fromJson(e)).toList();
  }

  Future<void> upsertGold(AssetGold gold) async {
    await _client.from('asset_gold').upsert(gold.toJson());
  }

  Future<void> deleteGold(String id) async {
    await _client.from('asset_gold').delete().eq('id', id);
  }
}
