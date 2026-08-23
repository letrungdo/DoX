import 'package:do_x/model/chicken/batch_sale.dart';
import 'package:do_x/model/chicken/cock_sale.dart';
import 'package:do_x/model/chicken/expense.dart';
import 'package:do_x/model/chicken/record_change.dart';
import 'package:do_x/model/chicken/vaccination.dart';
import 'package:json_annotation/json_annotation.dart';

part 'chicken_batch.g.dart';

@JsonSerializable()
class ChickenBatch with TimestampedRecord<ChickenBatch> {
  /// How long eggs sit in the incubator. Both directions of the
  /// incubation date <-> hatch date conversion go through this.
  static const incubationDuration = Duration(days: 21);

  final String id;
  final String name;
  final DateTime incubationDate;
  final int quantity;
  final List<Expense> expenses;
  final List<Vaccination> vaccinations;
  final List<CockSale> cockSales;
  final List<BatchSale> sales;
  final DateTime? actualHatchDate;
  @override
  final DateTime? createdAt;
  @override
  final DateTime? updatedAt;

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
    this.createdAt,
    this.updatedAt,
  });

  factory ChickenBatch.fromJson(Map<String, dynamic> json) =>
      _$ChickenBatchFromJson(json);
  Map<String, dynamic> toJson() => _$ChickenBatchToJson(this);

  // Every stored date is a solar (Gregorian) date, so day arithmetic — age,
  // incubation length, vaccination offsets — is plain [Duration] maths. The
  // lunar calendar is a display layer on top; see [ChickenDate].

  /// Expected hatch date, usually 21 days after incubation.
  DateTime get expectedHatchDate => incubationDate.add(incubationDuration);

  DateTime get _hatchDate => actualHatchDate ?? expectedHatchDate;

  double get totalExpenses =>
      expenses.fold(0, (sum, item) => sum + item.amount);

  double get totalCockSales =>
      cockSales.fold(0, (sum, item) => sum + item.amount);

  /// Split of [totalCockSales] by kind. Fighting roosters and meat chickens
  /// fetch very different prices, so anywhere the revenue is broken down they
  /// have to be told apart instead of shown as one "cock sales" figure.
  double get totalFightingSales => cockSales
      .where((sale) => sale.category != SaleCategory.meat)
      .fold(0, (sum, item) => sum + item.amount);

  double get totalMeatSales => cockSales
      .where((sale) => sale.category == SaleCategory.meat)
      .fold(0, (sum, item) => sum + item.amount);

  double get totalSaleAmount => sales.fold(0, (sum, item) => sum + item.amount);

  int get soldQuantity => sales.fold(0, (sum, item) => sum + item.quantity);

  int get remainingQuantity => quantity - soldQuantity;

  DateTime? get lastSaleDate => sales.isEmpty
      ? null
      : sales.map((s) => s.date).reduce((a, b) => a.isAfter(b) ? a : b);

  double get profit => (totalSaleAmount + totalCockSales) - totalExpenses;

  /// Age of the batch (in days) on a given date, e.g. a sale date.
  int ageInDaysAt(DateTime date) => date.difference(_hatchDate).inDays;

  /// Shifts every vaccination by [offset], following a change of the
  /// incubation date.
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
    return referenceDate.difference(_hatchDate).inDays;
  }

  @override
  ChickenBatch stamped({DateTime? createdAt, DateTime? updatedAt}) =>
      copyWith(createdAt: createdAt, updatedAt: updatedAt);

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
    DateTime? createdAt,
    DateTime? updatedAt,
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
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
