import 'dart:math' as math;

import 'package:do_x/model/chicken/chicken_batch.dart';
import 'package:do_x/utils/lunar_calendar.dart';
import 'package:do_x/widgets/dialog/low_price_warning_dialog.dart';

/// A price per chicken taken from a past sale round, together with the age the
/// batch had on that day.
class _PriceSample {
  final int ageInDays;
  final double unitPrice;
  final DateTime dateSolar;

  const _PriceSample(this.ageInDays, this.unitPrice, this.dateSolar);
}

/// Suggested price per chicken for a sale, derived from past sale rounds.
class SalePriceSuggestion {
  /// Suggested price per chicken, rounded to the nearest 500.
  final int unitPrice;

  /// Lowest and highest price among the rounds the suggestion is based on.
  final int minPrice;
  final int maxPrice;

  /// How many past sale rounds went into it.
  final int sampleCount;

  /// Age (real days) the suggestion was computed for.
  final int ageInDays;

  /// Age window the samples were taken from, in days; null when no round was
  /// close enough in age and every past round was used instead.
  final int? windowDays;

  const SalePriceSuggestion({
    required this.unitPrice,
    required this.minPrice,
    required this.maxPrice,
    required this.sampleCount,
    required this.ageInDays,
    required this.windowDays,
  });
}

/// Age windows tried in order; the first one holding at least
/// [_minSamplesInWindow] rounds wins.
const List<int> _ageWindows = [7, 15, 30];

const int _minSamplesInWindow = 3;

/// A round loses half its weight every this many days, so last month's prices
/// count for much more than last year's.
const double _recencyHalfLifeDays = 365;

/// Suggested price per chicken for a batch sold at [ageInDays] days old, based
/// on every past sale round in [batches].
///
/// Rounds are weighted by how close their age is to [ageInDays] and by how
/// recent they are, then the weighted median is taken — the median so one
/// unusually cheap or expensive round cannot drag the figure away.
///
/// Returns null when there is nothing to learn from yet. [excludeSaleId] drops
/// the round currently being edited, so it never suggests its own price back.
SalePriceSuggestion? suggestSaleUnitPrice({
  required List<ChickenBatch> batches,
  required int ageInDays,
  String? excludeSaleId,
  DateTime? now,
}) {
  final today = now ?? DateTime.now();
  final samples = <_PriceSample>[];
  for (final batch in batches) {
    for (final sale in batch.sales) {
      if (sale.id == excludeSaleId || sale.quantity <= 0) continue;
      final unitPrice = sale.amount / sale.quantity;
      // Below the threshold the record is a typo (a missing zero) rather than a
      // real price, and it would pull the suggestion right down.
      if (unitPrice < kSuspiciousPriceThreshold) continue;
      samples.add(
        _PriceSample(
          batch.ageInDaysAt(sale.date),
          unitPrice,
          LunarCalendar.lunarDateTimeToSolar(sale.date),
        ),
      );
    }
  }
  if (samples.isEmpty) return null;

  // Prefer rounds sold at a similar age; widen the window until enough of them
  // show up, and fall back to the whole history when none ever does.
  int? windowDays;
  var selected = samples;
  for (final window in _ageWindows) {
    final inWindow = samples
        .where((s) => (s.ageInDays - ageInDays).abs() <= window)
        .toList();
    if (inWindow.length >= _minSamplesInWindow) {
      windowDays = window;
      selected = inWindow;
      break;
    }
    // Even a single close round beats the whole history, but keep widening in
    // case a larger window gives a better-supported figure.
    if (inWindow.isNotEmpty && windowDays == null) {
      windowDays = window;
      selected = inWindow;
    }
  }

  final weights = selected.map((sample) {
    final ageWeight = 1 / (1 + (sample.ageInDays - ageInDays).abs() / 7);
    final daysAgo = today.difference(sample.dateSolar).inDays.abs();
    final recencyWeight = math.pow(0.5, daysAgo / _recencyHalfLifeDays);
    return ageWeight * recencyWeight;
  }).toList();

  final unitPrice = _weightedMedian(
    selected.map((s) => s.unitPrice).toList(),
    weights,
  );
  final prices = selected.map((s) => s.unitPrice).toList()..sort();

  return SalePriceSuggestion(
    // Round to 500 — a suggestion is a starting point, not a figure to the dong.
    unitPrice: (unitPrice / 500).round() * 500,
    minPrice: prices.first.round(),
    maxPrice: prices.last.round(),
    sampleCount: selected.length,
    ageInDays: ageInDays,
    windowDays: windowDays,
  );
}

/// Value where the sorted weights first reach half of their total.
double _weightedMedian(List<double> values, List<num> weights) {
  final indexes = List.generate(values.length, (i) => i)
    ..sort((a, b) => values[a].compareTo(values[b]));
  final total = weights.fold<double>(0, (sum, w) => sum + w);
  var running = 0.0;
  for (final index in indexes) {
    running += weights[index];
    if (running >= total / 2) return values[index];
  }
  return values[indexes.last];
}
