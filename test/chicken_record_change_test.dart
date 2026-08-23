import 'package:do_x/model/chicken/expense.dart';
import 'package:do_x/model/chicken/record_change.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Expense expense({DateTime? createdAt, DateTime? updatedAt}) => Expense(
    id: 'e1',
    type: ExpenseType.feed,
    amount: 1000,
    date: DateTime(2026, 8, 20),
    createdAt: createdAt,
    updatedAt: updatedAt,
  );

  final now = DateTime.now();
  final long = now.subtract(const Duration(days: 30));
  final recent = now.subtract(const Duration(hours: 2));

  group('changeBadge', () {
    test('a record created recently is badged new', () {
      expect(
        expense(createdAt: recent, updatedAt: recent).changeBadge,
        RecordChange.added,
      );
    });

    test('an old record edited recently is badged edited', () {
      expect(
        expense(createdAt: long, updatedAt: recent).changeBadge,
        RecordChange.updated,
      );
    });

    test('a recent record edited keeps the stronger "new" label', () {
      expect(
        expense(createdAt: recent, updatedAt: now).changeBadge,
        RecordChange.added,
      );
    });

    test('an untouched old record carries no badge', () {
      expect(expense(createdAt: long, updatedAt: long).changeBadge, isNull);
    });

    test('a row written before the columns existed carries no badge', () {
      expect(expense().changeBadge, isNull);
    });

    test('the badge expires with the retention window', () {
      final justOutside = now.subtract(
        TimestampedRecord.retention + const Duration(minutes: 1),
      );
      expect(
        expense(createdAt: justOutside, updatedAt: justOutside).changeBadge,
        isNull,
      );
    });
  });
}
