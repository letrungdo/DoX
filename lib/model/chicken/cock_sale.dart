import 'package:json_annotation/json_annotation.dart';

part 'cock_sale.g.dart';

@JsonSerializable()
class CockSale {
  final String id;
  final String note;
  final double amount;
  final DateTime date;

  CockSale({required this.id, required this.note, required this.amount, required this.date});

  factory CockSale.fromJson(Map<String, dynamic> json) => _$CockSaleFromJson(json);
  Map<String, dynamic> toJson() => _$CockSaleToJson(this);
}
