// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chicken_batch.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ChickenBatch _$ChickenBatchFromJson(Map<String, dynamic> json) => ChickenBatch(
  id: json['id'] as String,
  name: json['name'] as String,
  incubationDate: DateTime.parse(json['incubationDate'] as String),
  quantity: (json['quantity'] as num).toInt(),
  expenses:
      (json['expenses'] as List<dynamic>?)
          ?.map((e) => Expense.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  vaccinations:
      (json['vaccinations'] as List<dynamic>?)
          ?.map((e) => Vaccination.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  cockSales:
      (json['cockSales'] as List<dynamic>?)
          ?.map((e) => CockSale.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  sales:
      (json['sales'] as List<dynamic>?)
          ?.map((e) => BatchSale.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  actualHatchDate: json['actualHatchDate'] == null
      ? null
      : DateTime.parse(json['actualHatchDate'] as String),
);

Map<String, dynamic> _$ChickenBatchToJson(ChickenBatch instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'incubationDate': instance.incubationDate.toIso8601String(),
      'quantity': instance.quantity,
      'expenses': instance.expenses,
      'vaccinations': instance.vaccinations,
      'cockSales': instance.cockSales,
      'sales': instance.sales,
      'actualHatchDate': instance.actualHatchDate?.toIso8601String(),
    };
