import 'package:do_x/model/chicken/record_change.dart';
import 'package:json_annotation/json_annotation.dart';

part 'batch_sale.g.dart';

/// Một đợt bán gà con của một lứa (một lứa có thể bán nhiều đợt).
@JsonSerializable()
class BatchSale with TimestampedRecord<BatchSale> {
  final String id;
  final DateTime date;
  final int quantity;
  final double amount;
  final String? note;
  @override
  final DateTime? createdAt;
  @override
  final DateTime? updatedAt;

  BatchSale({
    required this.id,
    required this.date,
    required this.quantity,
    required this.amount,
    this.note,
    this.createdAt,
    this.updatedAt,
  });

  @override
  BatchSale stamped({DateTime? createdAt, DateTime? updatedAt}) =>
      copyWith(createdAt: createdAt, updatedAt: updatedAt);

  BatchSale copyWith({
    String? id,
    DateTime? date,
    int? quantity,
    double? amount,
    String? note,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BatchSale(
      id: id ?? this.id,
      date: date ?? this.date,
      quantity: quantity ?? this.quantity,
      amount: amount ?? this.amount,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory BatchSale.fromJson(Map<String, dynamic> json) =>
      _$BatchSaleFromJson(json);
  Map<String, dynamic> toJson() => _$BatchSaleToJson(this);
}
