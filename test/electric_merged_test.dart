import 'package:do_x/model/electric/electric_account.dart';
import 'package:do_x/model/electric/electric_merged.dart';
import 'package:do_x/model/electric/electric_models.dart';
import 'package:do_x/model/electric/electric_tariff.dart';
import 'package:flutter_test/flutter_test.dart';

ElectricAccount _account(
  String contractType,
  List<ElectricMonthlyUsage> months, {
  String owner = "LE TRUNG DO",
}) {
  return ElectricAccount(
    username: "$owner/$contractType",
    password: "x",
    customerName: owner,
    contractType: contractType,
  )..monthlyUsages = months;
}

ElectricMonthlyUsage _month(
  int year,
  int month, {
  required num kwh,
  required num amount,
}) {
  return ElectricMonthlyUsage(
    year: year,
    month: month,
    usageKwh: kwh,
    totalAmount: amount,
  );
}

void main() {
  group("contract type", () {
    test("household contract is residential", () {
      expect(_account("Sinh hoạt", []).isResidential, isTrue);
    });

    test("'ngoài sinh hoạt' is not residential even though it contains it", () {
      expect(_account("Ngoài sinh hoạt", []).isResidential, isFalse);
    });

    test("unknown / missing contract type is not residential", () {
      expect(_account("", []).isResidential, isFalse);
      expect(_account("Nông nghiệp", []).isResidential, isFalse);
    });
  });

  group("residential tariff", () {
    test("empty month costs nothing", () {
      expect(ElectricTariff.pricePerMonth(0), 0);
      expect(ElectricTariff.pricePerMonth(-5), 0);
    });

    test("stays inside the first tier", () {
      expect(ElectricTariff.pricePerMonth(50), 50 * 1984);
    });

    test("climbs the ladder tier by tier", () {
      expect(
        ElectricTariff.pricePerMonth(150),
        50 * 1984 + 50 * 2050 + 50 * 2380,
      );
    });

    test("top tier is open ended", () {
      const upToFive =
          50 * 1984 + 50 * 2050 + 100 * 2380 + 100 * 2998 + 100 * 3350;
      expect(ElectricTariff.pricePerMonth(500), upToFive + 100 * 3460);
    });

    test("marginal price only ever grows", () {
      num previous = 0;
      num? previousMarginal;
      for (var kwh = 10; kwh <= 600; kwh += 10) {
        final cost = ElectricTariff.pricePerMonth(kwh);
        final marginal = (cost - previous) / 10;
        if (previousMarginal != null) {
          expect(marginal, greaterThanOrEqualTo(previousMarginal));
        }
        previous = cost;
        previousMarginal = marginal;
      }
    });
  });

  group("merging accounts", () {
    test("needs both meter kinds to be comparable", () {
      final merged = ElectricMergedUsage.from([
        _account("Sinh hoạt", [_month(2026, 7, kwh: 200, amount: 500000)]),
      ]);
      expect(merged.isComparable, isFalse);
      expect(merged.months, isEmpty);
    });

    test("keeps only months billed on both meters", () {
      final merged = ElectricMergedUsage.from([
        _account("Sinh hoạt", [
          _month(2026, 7, kwh: 200, amount: 500000),
          _month(2026, 6, kwh: 300, amount: 800000),
        ]),
        _account("Ngoài sinh hoạt", [
          _month(2026, 7, kwh: 300, amount: 600000),
        ]),
      ]);
      expect(merged.isComparable, isTrue);
      expect(merged.months.length, 1);
      expect(merged.months.single.month, 7);
    });

    test("sums both meters and prices the single-meter alternative", () {
      const residentialKwh = 200;
      const residentialAmount = 550000;
      final merged = ElectricMergedUsage.from([
        _account("Sinh hoạt", [
          _month(2026, 7, kwh: residentialKwh, amount: residentialAmount),
        ]),
        _account("Ngoài sinh hoạt", [
          _month(2026, 7, kwh: 300, amount: 600000),
        ]),
      ]);

      final month = merged.months.single;
      expect(month.totalKwh, 500);
      expect(month.actualAmount, residentialAmount + 600000);

      // The tier table is only trusted for the shape of the ladder: the level
      // comes from the real household bill of the same month.
      final ratio =
          residentialAmount / ElectricTariff.pricePerMonth(residentialKwh);
      expect(
        month.singleMeterAmount,
        closeTo(ElectricTariff.pricePerMonth(500) * ratio, 0.001),
      );
      expect(month.savings, month.singleMeterAmount - month.actualAmount);
      // Pushing 300 kWh of farm load up the household ladder costs more than
      // the flat agricultural bill it replaced, so splitting saves money.
      expect(month.savings, greaterThan(0));
    });

    test("sorts months newest first and totals across them", () {
      final merged = ElectricMergedUsage.from([
        _account("Sinh hoạt", [
          _month(2025, 12, kwh: 180, amount: 450000),
          _month(2026, 1, kwh: 200, amount: 520000),
        ]),
        _account("Ngoài sinh hoạt", [
          _month(2025, 12, kwh: 250, amount: 480000),
          _month(2026, 1, kwh: 260, amount: 500000),
        ]),
      ]);

      expect(merged.months.map((m) => (m.year, m.month)), [
        (2026, 1),
        (2025, 12),
      ]);
      expect(merged.totalKwh, 180 + 200 + 250 + 260);
      expect(merged.totalActualAmount, 450000 + 520000 + 480000 + 500000);
      expect(
        merged.totalSavings,
        merged.totalSingleMeterAmount - merged.totalActualAmount,
      );
      expect(merged.latest?.month, 1);
    });

    test("groups meters by customer name", () {
      final groups = ElectricMergedGroup.of([
        _account("Sinh hoạt", [_month(2026, 7, kwh: 200, amount: 500000)]),
        _account("Ngoài sinh hoạt", [
          _month(2026, 7, kwh: 300, amount: 600000),
        ]),
        // Grandfather's meter, signed in on the same device — it must not land
        // in the household's total.
        _account("Sinh hoạt", [
          _month(2026, 7, kwh: 90, amount: 200000),
        ], owner: "LE VAN A"),
      ]);

      expect(groups.length, 1);
      expect(groups.single.ownerName, "LE TRUNG DO");
      expect(groups.single.accounts.length, 2);
      expect(groups.single.usage.months.single.totalKwh, 500);
    });

    test("a customer with a single meter forms no group", () {
      final groups = ElectricMergedGroup.of([
        _account("Sinh hoạt", []),
        _account("Sinh hoạt", [], owner: "LE VAN A"),
      ]);
      expect(groups, isEmpty);
    });

    test("each customer with two meters gets its own group", () {
      final groups = ElectricMergedGroup.of([
        _account("Sinh hoạt", []),
        _account("Ngoài sinh hoạt", []),
        _account("Sinh hoạt", [], owner: "LE VAN A"),
        _account("Ngoài sinh hoạt", [], owner: "LE VAN A"),
      ]);
      expect(groups.map((g) => g.ownerName), ["LE TRUNG DO", "LE VAN A"]);
      expect(groups.every((g) => g.accounts.length == 2), isTrue);
    });

    test("name matching ignores case and extra spacing", () {
      final groups = ElectricMergedGroup.of([
        _account("Sinh hoạt", [], owner: "LE  TRUNG DO"),
        _account("Ngoài sinh hoạt", [], owner: "Le Trung Do"),
      ]);
      expect(groups.length, 1);
      expect(groups.single.accounts.length, 2);
    });

    test("falls back to VAT when the household bill is missing", () {
      final merged = ElectricMergedUsage.from([
        _account("Sinh hoạt", [_month(2026, 7, kwh: 0, amount: 0)]),
        _account("Ngoài sinh hoạt", [
          _month(2026, 7, kwh: 300, amount: 600000),
        ]),
      ]);
      final month = merged.months.single;
      expect(
        month.singleMeterAmount,
        closeTo(
          ElectricTariff.pricePerMonth(300) * (1 + ElectricTariff.vatRate),
          0.001,
        ),
      );
    });
  });
}
