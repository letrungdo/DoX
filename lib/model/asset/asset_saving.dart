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

  /// The day the term ends, or null for an open-ended deposit.
  DateTime? get maturityDate {
    final months = termMonths;
    if (months == null || months <= 0) return null;

    return DateTime(startDate.year, startDate.month + months, startDate.day);
  }

  bool get isMatured {
    final maturity = maturityDate;

    return maturity != null && DateTime.now().isAfter(maturity);
  }

  double get monthlyInterest {
    if (isMatured) return 0;

    return (amount * (interestRate / 100)) / 12;
  }

  /// Interest stops at maturity. Past that date the bank pays the demand rate
  /// on the balance until it is rolled over, and a rollover is a new deposit
  /// with its own start date — a new record, not more interest on this one.
  double get accruedInterest {
    final maturity = maturityDate;
    final now = DateTime.now();
    final until = maturity != null && now.isAfter(maturity) ? maturity : now;
    final days = until.difference(startDate).inDays;
    if (days <= 0) return 0;

    return (amount * (interestRate / 100)) * (days / 365.0);
  }

  double get currentValue => amount + accruedInterest;
}
