import 'package:do_x/model/chicken/batch_sale.dart';
import 'package:do_x/model/chicken/chicken_batch.dart';
import 'package:do_x/utils/sale_price_suggestion.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sales are given as (age in days at the sale, price per chicken, quantity).
ChickenBatch _batch(
  String id,
  DateTime hatchDate,
  List<(int, int, int)> sales,
) {
  return ChickenBatch(
    id: id,
    name: id,
    incubationDate: hatchDate.subtract(const Duration(days: 21)),
    quantity: 100,
    actualHatchDate: hatchDate,
    sales: [
      for (var i = 0; i < sales.length; i++)
        BatchSale(
          id: '$id-$i',
          date: hatchDate.add(Duration(days: sales[i].$1)),
          quantity: sales[i].$3,
          amount: (sales[i].$2 * sales[i].$3).toDouble(),
        ),
    ],
  );
}

void main() {
  final now = DateTime(2026, 7, 31);
  final lastYear = DateTime(2025, 11, 1);

  test('returns null with no sale history', () {
    expect(
      suggestSaleUnitPrice(
        batches: [_batch('a', lastYear, const [])],
        ageInDays: 100,
        now: now,
      ),
      isNull,
    );
  });

  test('prices from the rounds sold at a similar age', () {
    // Day-100 rounds fetch 40k, day-30 rounds 20k. A day-100 sale must be
    // priced from the day-100 rounds only.
    final batches = [
      _batch('a', lastYear, const [(98, 40000, 20), (102, 41000, 20)]),
      _batch('b', lastYear, const [(100, 40000, 20), (30, 20000, 20)]),
    ];
    final suggestion = suggestSaleUnitPrice(
      batches: batches,
      ageInDays: 100,
      now: now,
    );
    expect(suggestion, isNotNull);
    expect(suggestion!.windowDays, 7);
    expect(suggestion.sampleCount, 3);
    expect(suggestion.unitPrice, 40000);
    expect(suggestion.ageInDays, 100);
  });

  test('one outlier round does not drag the suggestion', () {
    final batches = [
      _batch('a', lastYear, const [
        (100, 40000, 20),
        (100, 41000, 20),
        (100, 39000, 20),
        (100, 150000, 1),
      ]),
    ];
    final suggestion = suggestSaleUnitPrice(
      batches: batches,
      ageInDays: 100,
      now: now,
    )!;
    expect(suggestion.unitPrice, inInclusiveRange(39000, 41000));
    expect(suggestion.maxPrice, 150000);
  });

  test('widens the age window when no round is close', () {
    final batches = [
      _batch('a', lastYear, const [(80, 30000, 20), (120, 34000, 20)]),
    ];
    final suggestion = suggestSaleUnitPrice(
      batches: batches,
      ageInDays: 100,
      now: now,
    )!;
    expect(suggestion.windowDays, 30);
    expect(suggestion.sampleCount, 2);
  });

  test('falls back to the whole history when nothing is close in age', () {
    final batches = [
      _batch('a', lastYear, const [(100, 40000, 20), (110, 42000, 20)]),
    ];
    final suggestion = suggestSaleUnitPrice(
      batches: batches,
      ageInDays: 10,
      now: now,
    )!;
    expect(suggestion.windowDays, isNull);
    expect(suggestion.sampleCount, 2);
    expect(suggestion.minPrice, 40000);
    expect(suggestion.maxPrice, 42000);
  });

  test('skips typo prices and the round being edited', () {
    final batches = [
      _batch('a', lastYear, const [
        (100, 40, 20), // missing zeros
        (100, 40000, 20),
        (100, 41000, 20),
      ]),
    ];
    final suggestion = suggestSaleUnitPrice(
      batches: batches,
      ageInDays: 100,
      excludeSaleId: 'a-2',
      now: now,
    )!;
    expect(suggestion.sampleCount, 1);
    expect(suggestion.unitPrice, 40000);
  });

  test('recent rounds outweigh old ones at the same age', () {
    final batches = [
      // Three-year-old rounds at 20k, one round from this year at 40k.
      _batch('old', DateTime(2022, 8, 1), const [
        (100, 20000, 20),
        (101, 20000, 20),
        (99, 20000, 20),
      ]),
      _batch('new', DateTime(2026, 2, 20), const [(100, 40000, 20)]),
    ];
    final suggestion = suggestSaleUnitPrice(
      batches: batches,
      ageInDays: 100,
      now: now,
    )!;
    expect(suggestion.unitPrice, 40000);
  });
}
