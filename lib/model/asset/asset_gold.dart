import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'asset_gold.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake)
@CopyWith()
class AssetGold {
  const AssetGold({
    required this.id,
    required this.goldType, // e.g., SJC, PNJ, 9999
    required this.quantity, // in "lượng" or "chỉ"
    required this.buyPrice,
    required this.buyDate,
    this.note,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String goldType;
  final double quantity;
  final double buyPrice;
  final DateTime buyDate;
  final String? note;
  @JsonKey(includeIfNull: false)
  final DateTime? createdAt;
  @JsonKey(includeIfNull: false)
  final DateTime? updatedAt;

  factory AssetGold.fromJson(Map<String, dynamic> json) =>
      _$AssetGoldFromJson(json);

  Map<String, dynamic> toJson() => _$AssetGoldToJson(this);
}
