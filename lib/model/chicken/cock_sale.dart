import 'package:do_x/model/chicken/record_change.dart';
import 'package:json_annotation/json_annotation.dart';

part 'cock_sale.g.dart';

/// Loại gà bán lẻ: gà đá (nòi) hoặc gà thịt.
enum SaleCategory { fighting, meat }

@JsonSerializable()
class CockSale with TimestampedRecord<CockSale> {
  final String id;
  final String note;
  final double amount;
  final DateTime date;
  final SaleCategory category;
  @override
  final DateTime? createdAt;
  @override
  final DateTime? updatedAt;

  CockSale({
    required this.id,
    required this.note,
    required this.amount,
    required this.date,
    this.category = SaleCategory.fighting,
    this.createdAt,
    this.updatedAt,
  });

  @override
  CockSale stamped({DateTime? createdAt, DateTime? updatedAt}) =>
      copyWith(createdAt: createdAt, updatedAt: updatedAt);

  CockSale copyWith({
    String? id,
    String? note,
    double? amount,
    DateTime? date,
    SaleCategory? category,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CockSale(
      id: id ?? this.id,
      note: note ?? this.note,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory CockSale.fromJson(Map<String, dynamic> json) =>
      _$CockSaleFromJson(json);
  Map<String, dynamic> toJson() => _$CockSaleToJson(this);
}
