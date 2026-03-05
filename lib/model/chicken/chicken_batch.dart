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
  final DateTime? actualHatchDate;
  final DateTime? saleDate;
  final double? totalSaleAmount;
  final int? saleQuantity;

  ChickenBatch({
    required this.id,
    required this.name,
    required this.incubationDate,
    required this.quantity,
    this.expenses = const [],
    this.vaccinations = const [],
    this.cockSales = const [],
    this.actualHatchDate,
    this.saleDate,
    this.totalSaleAmount,
    this.saleQuantity,
  });

  factory ChickenBatch.fromJson(Map<String, dynamic> json) => _$ChickenBatchFromJson(json);
  Map<String, dynamic> toJson() => _$ChickenBatchToJson(this);

  // Helper to calculate expected hatch date (usually 21 days for chickens)
  DateTime get expectedHatchDate => incubationDate.add(const Duration(days: 21));

  double get totalExpenses => expenses.fold(0, (sum, item) => sum + item.amount);

  double get totalCockSales => cockSales.fold(0, (sum, item) => sum + item.amount);

  double get profit {
    final totalRevenue = (totalSaleAmount ?? 0) + totalCockSales;
    return totalRevenue - totalExpenses;
  }

  int get ageInDays {
    final referenceDate = saleDate ?? DateTime.now();
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
    DateTime? actualHatchDate,
    DateTime? saleDate,
    double? totalSaleAmount,
    int? saleQuantity,
  }) {
    return ChickenBatch(
      id: id ?? this.id,
      name: name ?? this.name,
      incubationDate: incubationDate ?? this.incubationDate,
      quantity: quantity ?? this.quantity,
      expenses: expenses ?? this.expenses,
      vaccinations: vaccinations ?? this.vaccinations,
      cockSales: cockSales ?? this.cockSales,
      actualHatchDate: actualHatchDate ?? this.actualHatchDate,
      saleDate: saleDate ?? this.saleDate,
      totalSaleAmount: totalSaleAmount ?? this.totalSaleAmount,
      saleQuantity: saleQuantity ?? this.saleQuantity,
    );
  }
}
