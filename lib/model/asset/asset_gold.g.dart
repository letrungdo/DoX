// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'asset_gold.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$AssetGoldCWProxy {
  AssetGold id(String id);

  AssetGold goldType(String goldType);

  AssetGold quantity(double quantity);

  AssetGold buyPrice(double buyPrice);

  AssetGold buyDate(DateTime buyDate);

  AssetGold note(String? note);

  AssetGold createdAt(DateTime? createdAt);

  AssetGold updatedAt(DateTime? updatedAt);

  /// Creates a new instance with the provided field values.
  /// Passing `null` to a nullable field nullifies it, while `null` for a non-nullable field is ignored. To update a single field use `AssetGold(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// AssetGold(...).copyWith(id: 12, name: "My name")
  /// ```
  AssetGold call({
    String id,
    String goldType,
    double quantity,
    double buyPrice,
    DateTime buyDate,
    String? note,
    DateTime? createdAt,
    DateTime? updatedAt,
  });
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfAssetGold.copyWith(...)` or call `instanceOfAssetGold.copyWith.fieldName(value)` for a single field.
class _$AssetGoldCWProxyImpl implements _$AssetGoldCWProxy {
  const _$AssetGoldCWProxyImpl(this._value);

  final AssetGold _value;

  @override
  AssetGold id(String id) => call(id: id);

  @override
  AssetGold goldType(String goldType) => call(goldType: goldType);

  @override
  AssetGold quantity(double quantity) => call(quantity: quantity);

  @override
  AssetGold buyPrice(double buyPrice) => call(buyPrice: buyPrice);

  @override
  AssetGold buyDate(DateTime buyDate) => call(buyDate: buyDate);

  @override
  AssetGold note(String? note) => call(note: note);

  @override
  AssetGold createdAt(DateTime? createdAt) => call(createdAt: createdAt);

  @override
  AssetGold updatedAt(DateTime? updatedAt) => call(updatedAt: updatedAt);

  @override
  /// Creates a new instance with the provided field values.
  /// Passing `null` to a nullable field nullifies it, while `null` for a non-nullable field is ignored. To update a single field use `AssetGold(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// AssetGold(...).copyWith(id: 12, name: "My name")
  /// ```
  AssetGold call({
    Object? id = const $CopyWithPlaceholder(),
    Object? goldType = const $CopyWithPlaceholder(),
    Object? quantity = const $CopyWithPlaceholder(),
    Object? buyPrice = const $CopyWithPlaceholder(),
    Object? buyDate = const $CopyWithPlaceholder(),
    Object? note = const $CopyWithPlaceholder(),
    Object? createdAt = const $CopyWithPlaceholder(),
    Object? updatedAt = const $CopyWithPlaceholder(),
  }) {
    return AssetGold(
      id: id == const $CopyWithPlaceholder() || id == null
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as String,
      goldType: goldType == const $CopyWithPlaceholder() || goldType == null
          ? _value.goldType
          // ignore: cast_nullable_to_non_nullable
          : goldType as String,
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

extension $AssetGoldCopyWith on AssetGold {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfAssetGold.copyWith(...)` or `instanceOfAssetGold.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$AssetGoldCWProxy get copyWith => _$AssetGoldCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AssetGold _$AssetGoldFromJson(Map<String, dynamic> json) => AssetGold(
  id: json['id'] as String,
  goldType: json['gold_type'] as String,
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

Map<String, dynamic> _$AssetGoldToJson(AssetGold instance) => <String, dynamic>{
  'id': instance.id,
  'gold_type': instance.goldType,
  'quantity': instance.quantity,
  'buy_price': instance.buyPrice,
  'buy_date': instance.buyDate.toIso8601String(),
  'note': instance.note,
  'created_at': ?instance.createdAt?.toIso8601String(),
  'updated_at': ?instance.updatedAt?.toIso8601String(),
};
