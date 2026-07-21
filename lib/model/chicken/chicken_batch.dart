import 'package:do_x/model/chicken/batch_sale.dart';
import 'package:do_x/model/chicken/cock_sale.dart';
import 'package:do_x/model/chicken/expense.dart';
import 'package:do_x/model/chicken/vaccination.dart';
import 'package:do_x/utils/lunar_calendar.dart';
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

  // Stored dates are lunar values; the solar equivalents are used for any
  // real (physical) day arithmetic such as age and incubation duration.
  DateTime get incubationDateSolar =>
      LunarCalendar.lunarDateTimeToSolar(incubationDate);

  DateTime? get actualHatchDateSolar => actualHatchDate == null
      ? null
      : LunarCalendar.lunarDateTimeToSolar(actualHatchDate!);

  /// Expected hatch date in the solar calendar, usually 21 real days after
  /// incubation.
  DateTime get expectedHatchDateSolar =>
      incubationDateSolar.add(const Duration(days: 21));

  /// Expected hatch date (lunar value), usually 21 real days after incubation.
  DateTime get expectedHatchDate =>
      LunarCalendar.solarToLunarDateTime(expectedHatchDateSolar);

  DateTime get _hatchDateSolar => actualHatchDateSolar ?? expectedHatchDateSolar;

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

  /// Age of the batch (in real days) on a given date, e.g. a sale date.
  /// [date] is a stored lunar value; both sides are converted to solar so the
  /// result is a real elapsed-day count.
  int ageInDaysAt(DateTime date) =>
      LunarCalendar.lunarDateTimeToSolar(date).difference(_hatchDateSolar).inDays;

  /// Shifts every vaccination by a real (solar) [offset]. Dates are lunar
  /// values, so the shift is applied in the solar calendar and converted back.
  ChickenBatch shiftVaccinationSchedule(Duration offset) {
    if (offset == Duration.zero) return this;
    return copyWith(
      vaccinations: vaccinations
          .map(
            (vaccination) => vaccination.copyWith(
              scheduledDate: LunarCalendar.solarToLunarDateTime(
                LunarCalendar.lunarDateTimeToSolar(
                  vaccination.scheduledDate,
                ).add(offset),
              ),
            ),
          )
          .toList(),
    );
  }

  int get ageInDays {
    // Once the batch is sold out, its age freezes at the last sale date.
    // Everything here is in the solar calendar so the day count is a real
    // elapsed-day count, not a lunar-day difference.
    final lastSaleSolar = lastSaleDate == null
        ? null
        : LunarCalendar.lunarDateTimeToSolar(lastSaleDate!);
    final referenceDate =
        (remainingQuantity <= 0 ? lastSaleSolar : null) ?? DateTime.now();
    return referenceDate.difference(_hatchDateSolar).inDays;
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
