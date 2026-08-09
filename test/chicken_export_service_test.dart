import 'package:do_x/model/chicken/batch_sale.dart';
import 'package:do_x/model/chicken/chicken_batch.dart';
import 'package:do_x/model/chicken/cock_sale.dart';
import 'package:do_x/model/chicken/expense.dart';
import 'package:do_x/model/chicken/vaccination.dart';
import 'package:do_x/services/chicken_export_service.dart';
import 'package:do_x/services/chicken_import_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // The export exists to be imported again, so the two are tested together:
  // a field added to one and forgotten in the other fails here.
  test('an exported file imports back to the same records', () {
    final batch = ChickenBatch(
      id: 'batch-1',
      name: 'Bầy 7',
      incubationDate: DateTime(2025, 7, 2),
      actualHatchDate: DateTime(2025, 7, 23),
      quantity: 12,
      sales: [
        BatchSale(
          id: 'sale-1',
          date: DateTime(2025, 8, 1),
          quantity: 10,
          amount: 400000,
          note: 'bán cho chú Tư',
        ),
      ],
      vaccinations: [
        Vaccination(
          id: 'vac-1',
          title: 'Newcastle',
          scheduledDate: DateTime(2025, 7, 26),
          isCompleted: true,
        ),
      ],
      expenses: [
        Expense(
          id: 'exp-1',
          type: ExpenseType.medicine,
          amount: 55000,
          date: DateTime(2025, 7, 27),
        ),
      ],
      cockSales: [
        CockSale(
          id: 'cock-1',
          note: 'gà nòi',
          amount: 900000,
          date: DateTime(2025, 12, 3),
          category: SaleCategory.fighting,
        ),
      ],
    );
    final globalSale = CockSale(
      id: 'cock-2',
      note: '',
      amount: 300000,
      date: DateTime(2025, 9, 9),
      category: SaleCategory.meat,
    );
    final globalExpense = Expense(
      id: 'exp-2',
      type: ExpenseType.feed,
      amount: 1200000,
      date: DateTime(2025, 9, 10),
      note: 'cám',
    );

    final imported = ChickenImportService.parse(
      ChickenExportService.encode(
        batches: [batch],
        globalSales: [globalSale],
        globalExpenses: [globalExpense],
      ),
    );

    final restored = imported.batches.single;
    expect(restored.name, batch.name);
    expect(restored.incubationDate, batch.incubationDate);
    expect(restored.actualHatchDate, batch.actualHatchDate);
    expect(restored.quantity, batch.quantity);

    expect(restored.sales.single.date, batch.sales.single.date);
    expect(restored.sales.single.quantity, batch.sales.single.quantity);
    expect(restored.sales.single.amount, batch.sales.single.amount);
    expect(restored.sales.single.note, batch.sales.single.note);

    expect(restored.vaccinations.single.title, 'Newcastle');
    expect(restored.vaccinations.single.scheduledDate, DateTime(2025, 7, 26));
    expect(restored.vaccinations.single.isCompleted, isTrue);

    expect(restored.expenses.single.type, ExpenseType.medicine);
    expect(restored.expenses.single.amount, 55000);
    expect(restored.expenses.single.date, DateTime(2025, 7, 27));

    expect(restored.cockSales.single.category, SaleCategory.fighting);
    expect(restored.cockSales.single.amount, 900000);

    expect(imported.globalSales.single.category, SaleCategory.meat);
    expect(imported.globalSales.single.amount, 300000);
    expect(imported.globalSales.single.date, DateTime(2025, 9, 9));

    expect(imported.globalExpenses.single.type, ExpenseType.feed);
    expect(imported.globalExpenses.single.note, 'cám');

    // 1 batch + 1 sale + 1 vaccination + 1 expense + 1 cock sale, plus the two
    // global records.
    expect(imported.totalRecords, 7);
  });
}
