import 'package:do_x/model/chicken/record_change.dart';
import 'package:json_annotation/json_annotation.dart';

part 'expense.g.dart';

enum ExpenseType { feed, medicine, electricity, water, other }

@JsonSerializable()
class Expense with TimestampedRecord<Expense> {
  final String id;
  final ExpenseType type;
  final double amount;
  final DateTime date;
  final String? note;
  @override
  final DateTime? createdAt;
  @override
  final DateTime? updatedAt;

  Expense({
    required this.id,
    required this.type,
    required this.amount,
    required this.date,
    this.note,
    this.createdAt,
    this.updatedAt,
  });

  @override
  Expense stamped({DateTime? createdAt, DateTime? updatedAt}) =>
      copyWith(createdAt: createdAt, updatedAt: updatedAt);

  Expense copyWith({
    String? id,
    ExpenseType? type,
    double? amount,
    DateTime? date,
    String? note,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Expense(
      id: id ?? this.id,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory Expense.fromJson(Map<String, dynamic> json) =>
      _$ExpenseFromJson(json);
  Map<String, dynamic> toJson() => _$ExpenseToJson(this);
}
