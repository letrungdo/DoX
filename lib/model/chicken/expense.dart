import 'package:json_annotation/json_annotation.dart';

part 'expense.g.dart';

enum ExpenseType {
  feed,
  medicine,
  electricity,
  water,
  other,
}

@JsonSerializable()
class Expense {
  final String id;
  final ExpenseType type;
  final double amount;
  final DateTime date;
  final String? note;

  Expense({
    required this.id,
    required this.type,
    required this.amount,
    required this.date,
    this.note,
  });

  factory Expense.fromJson(Map<String, dynamic> json) => _$ExpenseFromJson(json);
  Map<String, dynamic> toJson() => _$ExpenseToJson(this);
}
