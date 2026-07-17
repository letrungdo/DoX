import 'package:do_x/model/chicken/batch_sale.dart';
import 'package:do_x/model/chicken/cock_sale.dart';
import 'package:do_x/model/chicken/expense.dart';
import 'package:do_x/model/chicken/vaccination.dart';
import 'package:json_annotation/json_annotation.dart';

part 'chicken_batch.g.dart';

@JsonSerializable()
class ChickenBatch {
  final String id;
  final String name;
  final DateTime incubationDate;
  final int quantity;
  final List<Expense> expenses;
  final List<Vaccination> vaccinations;
  final List<CockSale> cockSales;
  final List<BatchSale> sales;
  final DateTime? actualHatchDate;

  ChickenBatch({
    required this.id,
    required this.name,
    required this.incubationDate,
    required this.quantity,
    this.expenses = const [],
    this.vaccinations = const [],
    this.cockSales = const [],
    this.sales = const [],
    this.actualHatchDate,
  });

  factory ChickenBatch.fromJson(Map<String, dynamic> json) =>
      _$ChickenBatchFromJson(json);
  Map<String, dynamic> toJson() => _$ChickenBatchToJson(this);

  // Helper to calculate expected hatch date (usually 21 days for chickens)
  DateTime get expectedHatchDate =>
      incubationDate.add(const Duration(days: 21));

  double get totalExpenses =>
      expenses.fold(0, (sum, item) => sum + item.amount);

  double get totalCockSales =>
      cockSales.fold(0, (sum, item) => sum + item.amount);

  double get totalSaleAmount => sales.fold(0, (sum, item) => sum + item.amount);

  int get soldQuantity => sales.fold(0, (sum, item) => sum + item.quantity);

  int get remainingQuantity => quantity - soldQuantity;

  DateTime? get lastSaleDate => sales.isEmpty
      ? null
      : sales.map((s) => s.date).reduce((a, b) => a.isAfter(b) ? a : b);

  double get profit => (totalSaleAmount + totalCockSales) - totalExpenses;

  ChickenBatch shiftVaccinationSchedule(Duration offset) {
    if (offset == Duration.zero) return this;
    return copyWith(
      vaccinations: vaccinations
          .map(
            (vaccination) => vaccination.copyWith(
              scheduledDate: vaccination.scheduledDate.add(offset),
            ),
          )
          .toList(),
    );
  }

  int get ageInDays {
    // Once the batch is sold out, its age freezes at the last sale date.
    final referenceDate =
        (remainingQuantity <= 0 ? lastSaleDate : null) ?? DateTime.now();
    final hatchDate = actualHatchDate ?? expectedHatchDate;
    return referenceDate.difference(hatchDate).inDays;
  }

  ChickenBatch copyWith({
    String? id,
    String? name,
    DateTime? incubationDate,
    int? quantity,
    List<Expense>? expenses,
    List<Vaccination>? vaccinations,
    List<CockSale>? cockSales,
    List<BatchSale>? sales,
    DateTime? actualHatchDate,
  }) {
    return ChickenBatch(
      id: id ?? this.id,
      name: name ?? this.name,
      incubationDate: incubationDate ?? this.incubationDate,
      quantity: quantity ?? this.quantity,
      expenses: expenses ?? this.expenses,
      vaccinations: vaccinations ?? this.vaccinations,
      cockSales: cockSales ?? this.cockSales,
      sales: sales ?? this.sales,
      actualHatchDate: actualHatchDate ?? this.actualHatchDate,
    );
  }
}
