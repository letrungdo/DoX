import 'package:json_annotation/json_annotation.dart';

part 'cock_sale.g.dart';

/// Loại gà bán lẻ: gà đá (nòi) hoặc gà thịt.
enum SaleCategory {
  fighting,
  meat,
}

@JsonSerializable()
class CockSale {
  final String id;
  final String note;
  final double amount;
  final DateTime date;
  final SaleCategory category;

  CockSale({
    required this.id,
    required this.note,
    required this.amount,
    required this.date,
    this.category = SaleCategory.fighting,
  });

  factory CockSale.fromJson(Map<String, dynamic> json) => _$CockSaleFromJson(json);
  Map<String, dynamic> toJson() => _$CockSaleToJson(this);
}
