import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'asset_investment.g.dart';

enum InvestmentType {
  stock,
  crypto,
}

@JsonSerializable(fieldRename: FieldRename.snake)
@CopyWith()
class AssetInvestment {
  const AssetInvestment({
    required this.id,
    required this.symbol,
    required this.type,
    required this.quantity,
    required this.buyPrice,
    required this.buyDate,
    this.note,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String symbol;
  final InvestmentType type;
  final double quantity;
  final double buyPrice;
  final DateTime buyDate;
  final String? note;
  @JsonKey(includeIfNull: false)
  final DateTime? createdAt;
  @JsonKey(includeIfNull: false)
  final DateTime? updatedAt;

  factory AssetInvestment.fromJson(Map<String, dynamic> json) =>
      _$AssetInvestmentFromJson(json);

  Map<String, dynamic> toJson() => _$AssetInvestmentToJson(this);
}
