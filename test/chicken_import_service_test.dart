import 'dart:convert';

import 'package:do_x/services/chicken_import_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rejects a legacy import whose calendar is ambiguous', () {
    expect(
      () => ChickenImportService.parse(
        jsonEncode({'batches': [], 'cockSales': [], 'expenses': []}),
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('keeps dates from a solar import unchanged', () {
    final data = ChickenImportService.parse(
      jsonEncode({
        'dateCalendar': 'solar',
        'batches': [
          {
            'name': 'Bầy thử',
            'incubationDate': '2025-07-02',
            'actualHatchDate': '2025-07-23',
            'quantity': 10,
            'sales': [
              {'date': '2025-08-01', 'amount': 400000, 'quantity': 10},
            ],
          },
        ],
        'cockSales': [],
        'expenses': [],
      }),
    );

    expect(data.batches.single.incubationDate, DateTime(2025, 7, 2));
    expect(data.batches.single.actualHatchDate, DateTime(2025, 7, 23));
    expect(data.batches.single.sales.single.date, DateTime(2025, 8, 1));
  });
}
