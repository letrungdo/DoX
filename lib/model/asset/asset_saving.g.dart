// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'asset_saving.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$AssetSavingCWProxy {
  AssetSaving id(String id);

  AssetSaving bankName(String bankName);

  AssetSaving amount(double amount);

  AssetSaving interestRate(double interestRate);

  AssetSaving startDate(DateTime startDate);

  AssetSaving termMonths(int? termMonths);

  AssetSaving note(String? note);

  AssetSaving createdAt(DateTime? createdAt);

  AssetSaving updatedAt(DateTime? updatedAt);

  /// Creates a new instance with the provided field values.
  /// Passing `null` to a nullable field nullifies it, while `null` for a non-nullable field is ignored. To update a single field use `AssetSaving(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// AssetSaving(...).copyWith(id: 12, name: "My name")
  /// ```
  AssetSaving call({
    String id,
    String bankName,
    double amount,
    double interestRate,
    DateTime startDate,
    int? termMonths,
    String? note,
    DateTime? createdAt,
    DateTime? updatedAt,
  });
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfAssetSaving.copyWith(...)` or call `instanceOfAssetSaving.copyWith.fieldName(value)` for a single field.
class _$AssetSavingCWProxyImpl implements _$AssetSavingCWProxy {
  const _$AssetSavingCWProxyImpl(this._value);

  final AssetSaving _value;

  @override
  AssetSaving id(String id) => call(id: id);

  @override
  AssetSaving bankName(String bankName) => call(bankName: bankName);

  @override
  AssetSaving amount(double amount) => call(amount: amount);

  @override
  AssetSaving interestRate(double interestRate) =>
      call(interestRate: interestRate);

  @override
  AssetSaving startDate(DateTime startDate) => call(startDate: startDate);

  @override
  AssetSaving termMonths(int? termMonths) => call(termMonths: termMonths);

  @override
  AssetSaving note(String? note) => call(note: note);

  @override
  AssetSaving createdAt(DateTime? createdAt) => call(createdAt: createdAt);

  @override
  AssetSaving updatedAt(DateTime? updatedAt) => call(updatedAt: updatedAt);

  @override
  /// Creates a new instance with the provided field values.
  /// Passing `null` to a nullable field nullifies it, while `null` for a non-nullable field is ignored. To update a single field use `AssetSaving(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// AssetSaving(...).copyWith(id: 12, name: "My name")
  /// ```
  AssetSaving call({
    Object? id = const $CopyWithPlaceholder(),
    Object? bankName = const $CopyWithPlaceholder(),
    Object? amount = const $CopyWithPlaceholder(),
    Object? interestRate = const $CopyWithPlaceholder(),
    Object? startDate = const $CopyWithPlaceholder(),
    Object? termMonths = const $CopyWithPlaceholder(),
    Object? note = const $CopyWithPlaceholder(),
    Object? createdAt = const $CopyWithPlaceholder(),
    Object? updatedAt = const $CopyWithPlaceholder(),
  }) {
    return AssetSaving(
      id: id == const $CopyWithPlaceholder() || id == null
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as String,
      bankName: bankName == const $CopyWithPlaceholder() || bankName == null
          ? _value.bankName
          // ignore: cast_nullable_to_non_nullable
          : bankName as String,
      amount: amount == const $CopyWithPlaceholder() || amount == null
          ? _value.amount
          // ignore: cast_nullable_to_non_nullable
          : amount as double,
      interestRate:
          interestRate == const $CopyWithPlaceholder() || interestRate == null
          ? _value.interestRate
          // ignore: cast_nullable_to_non_nullable
          : interestRate as double,
      startDate: startDate == const $CopyWithPlaceholder() || startDate == null
          ? _value.startDate
          // ignore: cast_nullable_to_non_nullable
          : startDate as DateTime,
      termMonths: termMonths == const $CopyWithPlaceholder()
          ? _value.termMonths
          // ignore: cast_nullable_to_non_nullable
          : termMonths as int?,
      note: note == const $CopyWithPlaceholder()
          ? _value.note
          // ignore: cast_nullable_to_non_nullable
          : note as String?,
      createdAt: createdAt == const $CopyWithPlaceholder()
          ? _value.createdAt
          // ignore: cast_nullable_to_non_nullable
          : createdAt as DateTime?,
      updatedAt: updatedAt == const $CopyWithPlaceholder()
          ? _value.updatedAt
          // ignore: cast_nullable_to_non_nullable
          : updatedAt as DateTime?,
    );
  }
}

extension $AssetSavingCopyWith on AssetSaving {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfAssetSaving.copyWith(...)` or `instanceOfAssetSaving.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$AssetSavingCWProxy get copyWith => _$AssetSavingCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AssetSaving _$AssetSavingFromJson(Map<String, dynamic> json) => AssetSaving(
  id: json['id'] as String,
  bankName: json['bank_name'] as String,
  amount: (json['amount'] as num).toDouble(),
  interestRate: (json['interest_rate'] as num).toDouble(),
  startDate: DateTime.parse(json['start_date'] as String),
  termMonths: (json['term_months'] as num?)?.toInt(),
  note: json['note'] as String?,
  createdAt: json['created_at'] == null
      ? null
      : DateTime.parse(json['created_at'] as String),
  updatedAt: json['updated_at'] == null
      ? null
      : DateTime.parse(json['updated_at'] as String),
);

Map<String, dynamic> _$AssetSavingToJson(AssetSaving instance) =>
    <String, dynamic>{
      'id': instance.id,
      'bank_name': instance.bankName,
      'amount': instance.amount,
      'interest_rate': instance.interestRate,
      'start_date': instance.startDate.toIso8601String(),
      'term_months': instance.termMonths,
      'note': instance.note,
      'created_at': ?instance.createdAt?.toIso8601String(),
      'updated_at': ?instance.updatedAt?.toIso8601String(),
    };
