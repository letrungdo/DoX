// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cock_sale.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CockSale _$CockSaleFromJson(Map<String, dynamic> json) => CockSale(
  id: json['id'] as String,
  note: json['note'] as String,
  amount: (json['amount'] as num).toDouble(),
  date: DateTime.parse(json['date'] as String),
  category:
      $enumDecodeNullable(_$SaleCategoryEnumMap, json['category']) ??
      SaleCategory.fighting,
  createdAt: json['createdAt'] == null
      ? null
      : DateTime.parse(json['createdAt'] as String),
  updatedAt: json['updatedAt'] == null
      ? null
      : DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$CockSaleToJson(CockSale instance) => <String, dynamic>{
  'id': instance.id,
  'note': instance.note,
  'amount': instance.amount,
  'date': instance.date.toIso8601String(),
  'category': _$SaleCategoryEnumMap[instance.category]!,
  'createdAt': instance.createdAt?.toIso8601String(),
  'updatedAt': instance.updatedAt?.toIso8601String(),
};

const _$SaleCategoryEnumMap = {
  SaleCategory.fighting: 'fighting',
  SaleCategory.meat: 'meat',
};
