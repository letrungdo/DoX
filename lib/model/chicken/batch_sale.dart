import 'package:json_annotation/json_annotation.dart';

part 'batch_sale.g.dart';

/// Một đợt bán gà con của một lứa (một lứa có thể bán nhiều đợt).
@JsonSerializable()
class BatchSale {
  final String id;
  final DateTime date;
  final int quantity;
  final double amount;
  final String? note;

  BatchSale({required this.id, required this.date, required this.quantity, required this.amount, this.note});

  factory BatchSale.fromJson(Map<String, dynamic> json) => _$BatchSaleFromJson(json);
  Map<String, dynamic> toJson() => _$BatchSaleToJson(this);
}
