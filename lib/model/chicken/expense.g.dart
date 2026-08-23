// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'expense.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Expense _$ExpenseFromJson(Map<String, dynamic> json) => Expense(
  id: json['id'] as String,
  type: $enumDecode(_$ExpenseTypeEnumMap, json['type']),
  amount: (json['amount'] as num).toDouble(),
  date: DateTime.parse(json['date'] as String),
  note: json['note'] as String?,
  createdAt: json['createdAt'] == null
      ? null
      : DateTime.parse(json['createdAt'] as String),
  updatedAt: json['updatedAt'] == null
      ? null
      : DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$ExpenseToJson(Expense instance) => <String, dynamic>{
  'id': instance.id,
  'type': _$ExpenseTypeEnumMap[instance.type]!,
  'amount': instance.amount,
  'date': instance.date.toIso8601String(),
  'note': instance.note,
  'createdAt': instance.createdAt?.toIso8601String(),
  'updatedAt': instance.updatedAt?.toIso8601String(),
};

const _$ExpenseTypeEnumMap = {
  ExpenseType.feed: 'feed',
  ExpenseType.medicine: 'medicine',
  ExpenseType.electricity: 'electricity',
  ExpenseType.water: 'water',
  ExpenseType.other: 'other',
};
