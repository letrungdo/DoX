// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'asset_investment.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$AssetInvestmentCWProxy {
  AssetInvestment id(String id);

  AssetInvestment symbol(String symbol);

  AssetInvestment type(InvestmentType type);

  AssetInvestment quantity(double quantity);

  AssetInvestment buyPrice(double buyPrice);

  AssetInvestment buyDate(DateTime buyDate);

  AssetInvestment note(String? note);

  AssetInvestment createdAt(DateTime? createdAt);

  AssetInvestment updatedAt(DateTime? updatedAt);

  /// Creates a new instance with the provided field values.
  /// Passing `null` to a nullable field nullifies it, while `null` for a non-nullable field is ignored. To update a single field use `AssetInvestment(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// AssetInvestment(...).copyWith(id: 12, name: "My name")
  /// ```
  AssetInvestment call({
    String id,
    String symbol,
    InvestmentType type,
    double quantity,
    double buyPrice,
    DateTime buyDate,
    String? note,
    DateTime? createdAt,
    DateTime? updatedAt,
  });
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfAssetInvestment.copyWith(...)` or call `instanceOfAssetInvestment.copyWith.fieldName(value)` for a single field.
class _$AssetInvestmentCWProxyImpl implements _$AssetInvestmentCWProxy {
  const _$AssetInvestmentCWProxyImpl(this._value);

  final AssetInvestment _value;

  @override
  AssetInvestment id(String id) => call(id: id);

  @override
  AssetInvestment symbol(String symbol) => call(symbol: symbol);

  @override
  AssetInvestment type(InvestmentType type) => call(type: type);

  @override
  AssetInvestment quantity(double quantity) => call(quantity: quantity);

  @override
  AssetInvestment buyPrice(double buyPrice) => call(buyPrice: buyPrice);

  @override
  AssetInvestment buyDate(DateTime buyDate) => call(buyDate: buyDate);

  @override
  AssetInvestment note(String? note) => call(note: note);

  @override
  AssetInvestment createdAt(DateTime? createdAt) => call(createdAt: createdAt);

  @override
  AssetInvestment updatedAt(DateTime? updatedAt) => call(updatedAt: updatedAt);

  @override
  /// Creates a new instance with the provided field values.
  /// Passing `null` to a nullable field nullifies it, while `null` for a non-nullable field is ignored. To update a single field use `AssetInvestment(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// AssetInvestment(...).copyWith(id: 12, name: "My name")
  /// ```
  AssetInvestment call({
    Object? id = const $CopyWithPlaceholder(),
    Object? symbol = const $CopyWithPlaceholder(),
    Object? type = const $CopyWithPlaceholder(),
    Object? quantity = const $CopyWithPlaceholder(),
    Object? buyPrice = const $CopyWithPlaceholder(),
    Object? buyDate = const $CopyWithPlaceholder(),
    Object? note = const $CopyWithPlaceholder(),
    Object? createdAt = const $CopyWithPlaceholder(),
    Object? updatedAt = const $CopyWithPlaceholder(),
  }) {
    return AssetInvestment(
      id: id == const $CopyWithPlaceholder() || id == null
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as String,
      symbol: symbol == const $CopyWithPlaceholder() || symbol == null
          ? _value.symbol
          // ignore: cast_nullable_to_non_nullable
          : symbol as String,
      type: type == const $CopyWithPlaceholder() || type == null
          ? _value.type
          // ignore: cast_nullable_to_non_nullable
          : type as InvestmentType,
      quantity: quantity == const $CopyWithPlaceholder() || quantity == null
          ? _value.quantity
          // ignore: cast_nullable_to_non_nullable
          : quantity as double,
      buyPrice: buyPrice == const $CopyWithPlaceholder() || buyPrice == null
          ? _value.buyPrice
          // ignore: cast_nullable_to_non_nullable
          : buyPrice as double,
      buyDate: buyDate == const $CopyWithPlaceholder() || buyDate == null
          ? _value.buyDate
          // ignore: cast_nullable_to_non_nullable
          : buyDate as DateTime,
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

extension $AssetInvestmentCopyWith on AssetInvestment {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfAssetInvestment.copyWith(...)` or `instanceOfAssetInvestment.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$AssetInvestmentCWProxy get copyWith => _$AssetInvestmentCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AssetInvestment _$AssetInvestmentFromJson(Map<String, dynamic> json) =>
    AssetInvestment(
      id: json['id'] as String,
      symbol: json['symbol'] as String,
      type: $enumDecode(_$InvestmentTypeEnumMap, json['type']),
      quantity: (json['quantity'] as num).toDouble(),
      buyPrice: (json['buy_price'] as num).toDouble(),
      buyDate: DateTime.parse(json['buy_date'] as String),
      note: json['note'] as String?,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$AssetInvestmentToJson(AssetInvestment instance) =>
    <String, dynamic>{
      'id': instance.id,
      'symbol': instance.symbol,
      'type': _$InvestmentTypeEnumMap[instance.type]!,
      'quantity': instance.quantity,
      'buy_price': instance.buyPrice,
      'buy_date': instance.buyDate.toIso8601String(),
      'note': instance.note,
      'created_at': ?instance.createdAt?.toIso8601String(),
      'updated_at': ?instance.updatedAt?.toIso8601String(),
    };

const _$InvestmentTypeEnumMap = {
  InvestmentType.stock: 'stock',
  InvestmentType.crypto: 'crypto',
};
