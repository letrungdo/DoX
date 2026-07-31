import 'package:do_x/model/chicken/batch_sale.dart';
import 'package:do_x/model/chicken/chicken_batch.dart';
import 'package:do_x/utils/chicken_date.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('solar mode shows the stored date as it is', () {
    expect(
      ChickenDate.format(DateTime(2025, 8, 1), useLunar: false),
      '01/08/2025',
    );
  });

  test('lunar mode converts and marks the date', () {
    expect(
      ChickenDate.format(DateTime(2025, 7, 2), useLunar: true),
      '08/06/2025 ÂL',
    );
  });

  // 2025 has a leap sixth month (25/07 - 22/08 solar). Its days used to be
  // stored as an ordinary "6", indistinguishable from the month before, which
  // read back about 30 days out. Storing the solar date keeps them apart and
  // the "N" says which of the two months it is.
  test('lunar mode marks a leap month', () {
    expect(
      ChickenDate.format(DateTime(2025, 8, 1), useLunar: true),
      '08/06N/2025 ÂL',
    );
  });

  test('the two sixth months of 2025 are told apart', () {
    final regular = ChickenDate.format(DateTime(2025, 7, 2), useLunar: true);
    final leap = ChickenDate.format(DateTime(2025, 8, 1), useLunar: true);
    expect(regular, isNot(leap));
  });

  test('an age over a leap month is a real day count', () {
    // Hatched just before the leap sixth month, sold inside it.
    final batch = ChickenBatch(
      id: 'batch-1',
      name: 'Lứa nhuận',
      incubationDate: DateTime(2025, 6, 12),
      quantity: 50,
      actualHatchDate: DateTime(2025, 7, 3),
      sales: [
        BatchSale(
          id: 'sale-1',
          date: DateTime(2025, 8, 1),
          quantity: 50,
          amount: 2000000,
        ),
      ],
    );

    expect(batch.ageInDaysAt(batch.sales.single.date), 29);
    expect(batch.ageInDays, 29, reason: 'sold out, so the age is frozen');
  });
}
