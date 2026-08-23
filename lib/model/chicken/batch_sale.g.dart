// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'batch_sale.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BatchSale _$BatchSaleFromJson(Map<String, dynamic> json) => BatchSale(
  id: json['id'] as String,
  date: DateTime.parse(json['date'] as String),
  quantity: (json['quantity'] as num).toInt(),
  amount: (json['amount'] as num).toDouble(),
  note: json['note'] as String?,
  createdAt: json['createdAt'] == null
      ? null
      : DateTime.parse(json['createdAt'] as String),
  updatedAt: json['updatedAt'] == null
      ? null
      : DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$BatchSaleToJson(BatchSale instance) => <String, dynamic>{
  'id': instance.id,
  'date': instance.date.toIso8601String(),
  'quantity': instance.quantity,
  'amount': instance.amount,
  'note': instance.note,
  'createdAt': instance.createdAt?.toIso8601String(),
  'updatedAt': instance.updatedAt?.toIso8601String(),
};
