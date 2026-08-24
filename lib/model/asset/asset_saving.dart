import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'asset_saving.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake)
@CopyWith()
class AssetSaving {
  const AssetSaving({
    required this.id,
    required this.bankName,
    required this.amount,
    required this.interestRate,
    required this.startDate,
    this.termMonths,
    this.note,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String bankName;
  final double amount;
  final double interestRate; // Annual interest rate in %
  final DateTime startDate;
  final int? termMonths;
  final String? note;
  @JsonKey(includeIfNull: false)
  final DateTime? createdAt;
  @JsonKey(includeIfNull: false)
  final DateTime? updatedAt;

  factory AssetSaving.fromJson(Map<String, dynamic> json) =>
      _$AssetSavingFromJson(json);

  Map<String, dynamic> toJson() => _$AssetSavingToJson(this);

  double get monthlyInterest => (amount * (interestRate / 100)) / 12;

  double get accruedInterest {
    final days = DateTime.now().difference(startDate).inDays;
    if (days <= 0) return 0;
    return (amount * (interestRate / 100)) * (days / 365.0);
  }

  double get currentValue => amount + accruedInterest;
}
