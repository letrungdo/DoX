import 'package:do_x/model/electric/electric_account.dart';
import 'package:do_x/model/electric/electric_tariff.dart';

/// One billing month with every meter of the household added together, plus
/// what the same consumption would have cost on a single residential meter.
class ElectricMergedMonth {
  const ElectricMergedMonth({
    required this.year,
    required this.month,
    required this.residentialKwh,
    required this.residentialAmount,
    required this.otherKwh,
    required this.otherAmount,
    required this.singleMeterAmount,
  });

  final int year;
  final int month;

  /// kWh / đ billed on the household meter(s) ("sinh hoạt").
  final num residentialKwh;
  final num residentialAmount;

  /// kWh / đ billed on the non-household meter(s) — agriculture, business…
  final num otherKwh;
  final num otherAmount;

  /// Estimated bill had all [totalKwh] gone through one residential meter,
  /// i.e. climbing the progressive tiers on its own.
  final num singleMeterAmount;

  num get totalKwh => residentialKwh + otherKwh;
  num get actualAmount => residentialAmount + otherAmount;

  /// Positive when splitting the load across meters is cheaper.
  num get savings => singleMeterAmount - actualAmount;

  double get savingsRatio =>
      singleMeterAmount <= 0 ? 0 : savings / singleMeterAmount;
}

/// All accounts of the household merged month by month, newest first.
class ElectricMergedUsage {
  const ElectricMergedUsage({
    required this.months,
    required this.residentialAccounts,
    required this.otherAccounts,
  });

  final List<ElectricMergedMonth> months;
  final int residentialAccounts;
  final int otherAccounts;

  bool get isEmpty => months.isEmpty;

  /// True once the household actually has both meter kinds signed in — without
  /// them there is nothing to compare.
  bool get isComparable => residentialAccounts > 0 && otherAccounts > 0;

  ElectricMergedMonth? get latest => months.isEmpty ? null : months.first;

  num get totalKwh => _sum((m) => m.totalKwh);
  num get totalActualAmount => _sum((m) => m.actualAmount);
  num get totalSingleMeterAmount => _sum((m) => m.singleMeterAmount);
  num get totalSavings => totalSingleMeterAmount - totalActualAmount;

  num _sum(num Function(ElectricMergedMonth month) value) =>
      months.fold<num>(0, (sum, month) => sum + value(month));

  /// Merges the billing history of [accounts]. Only months where both a
  /// residential and a non-residential bill exist are kept: earlier months
  /// (before the second meter was installed) have nothing to save.
  factory ElectricMergedUsage.from(List<ElectricAccount> accounts) {
    final residential = accounts.where((a) => a.isResidential).toList();
    final others = accounts.where((a) => !a.isResidential).toList();

    final buckets = <int, _MonthBucket>{};
    void collect(List<ElectricAccount> group, {required bool isResidential}) {
      for (final account in group) {
        for (final usage in account.monthlyUsages) {
          final year = usage.year;
          final month = usage.month;
          if (year == null || month == null) continue;
          final bucket = buckets.putIfAbsent(
            year * 100 + month,
            () => _MonthBucket(year: year, month: month),
          );
          bucket.add(
            kwh: usage.usageKwh ?? 0,
            amount: usage.totalAmount ?? 0,
            isResidential: isResidential,
          );
        }
      }
    }

    collect(residential, isResidential: true);
    collect(others, isResidential: false);

    final months =
        buckets.values
            .where((b) => b.hasResidential && b.hasOther)
            .map((b) => b.build())
            .toList()
          ..sort((a, b) {
            final byYear = b.year.compareTo(a.year);
            return byYear != 0 ? byYear : b.month.compareTo(a.month);
          });

    return ElectricMergedUsage(
      months: months,
      residentialAccounts: residential.length,
      otherAccounts: others.length,
    );
  }
}

/// The meters of one customer, merged. Accounts are grouped by customer name,
/// so a relative's meter signed in on the same device never lands in the same
/// total as the household's own.
class ElectricMergedGroup {
  const ElectricMergedGroup({
    required this.ownerName,
    required this.accounts,
    required this.usage,
  });

  final String ownerName;
  final List<ElectricAccount> accounts;
  final ElectricMergedUsage usage;

  /// Groups [accounts] by customer name, keeping only the names holding more
  /// than one meter — a lone meter has nothing to be merged with. Order follows
  /// the accounts themselves, so the tabs and the sections read the same way.
  static List<ElectricMergedGroup> of(List<ElectricAccount> accounts) {
    final byName = <String, List<ElectricAccount>>{};
    for (final account in accounts) {
      // Accounts still loading fall back to their username here, so they group
      // on their own until the customer name arrives.
      final key = _nameKey(account.displayName);
      byName.putIfAbsent(key, () => []).add(account);
    }
    return byName.values
        .where((group) => group.length > 1)
        .map(
          (group) => ElectricMergedGroup(
            ownerName: group.first.displayName,
            accounts: group,
            usage: ElectricMergedUsage.from(group),
          ),
        )
        .toList();
  }

  /// Case- and spacing-insensitive, since the API is not consistent about
  /// either ("LE  TRUNG DO" vs "Le Trung Do"). Diacritics are left alone: they
  /// are what tells two similar names apart.
  static String _nameKey(String name) =>
      name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), " ");
}

class _MonthBucket {
  _MonthBucket({required this.year, required this.month});

  final int year;
  final int month;

  num residentialKwh = 0;
  num residentialAmount = 0;
  num otherKwh = 0;
  num otherAmount = 0;
  bool hasResidential = false;
  bool hasOther = false;

  void add({
    required num kwh,
    required num amount,
    required bool isResidential,
  }) {
    if (isResidential) {
      hasResidential = true;
      residentialKwh += kwh;
      residentialAmount += amount;
    } else {
      hasOther = true;
      otherKwh += kwh;
      otherAmount += amount;
    }
  }

  ElectricMergedMonth build() {
    // The tier table is pre-VAT and can lag behind an EVN price change, so it
    // is only trusted for the *shape* of the ladder: the real residential bill
    // of the very same month calibrates the level. Falls back to plain VAT
    // when that month's residential bill can't provide a ratio.
    final reference = ElectricTariff.pricePerMonth(residentialKwh);
    final ratio = reference > 0 && residentialAmount > 0
        ? residentialAmount / reference
        : 1 + ElectricTariff.vatRate;
    final total = residentialKwh + otherKwh;
    return ElectricMergedMonth(
      year: year,
      month: month,
      residentialKwh: residentialKwh,
      residentialAmount: residentialAmount,
      otherKwh: otherKwh,
      otherAmount: otherAmount,
      singleMeterAmount: ElectricTariff.pricePerMonth(total) * ratio,
    );
  }
}
