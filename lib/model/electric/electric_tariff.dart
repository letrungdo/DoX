/// Retail tariff for residential use ("giá bán điện sinh hoạt"), used to price
/// the hypothetical "everything on one household meter" bill.
///
/// Only the residential ladder is needed: the real bills of the other meters
/// come from the API, so their own tariffs never have to be modelled.
class ElectricTariff {
  /// Progressive tiers for one household allowance ("1 định mức"), in order.
  /// [widthKwh] is null for the open-ended top tier.
  ///
  /// Prices are pre-VAT đ/kWh, per EVN's schedule effective 2025-05-10. Bills
  /// are never priced with these numbers alone — [pricePerMonth] is always
  /// scaled by the ratio implied by the real residential bill (see
  /// `ElectricMergedMonth`), so a tariff change only shifts the tier
  /// *proportions*, not the level.
  static const tiers = <({int? widthKwh, num pricePerKwh})>[
    (widthKwh: 50, pricePerKwh: 1984), // bậc 1: 0–50
    (widthKwh: 50, pricePerKwh: 2050), // bậc 2: 51–100
    (widthKwh: 100, pricePerKwh: 2380), // bậc 3: 101–200
    (widthKwh: 100, pricePerKwh: 2998), // bậc 4: 201–300
    (widthKwh: 100, pricePerKwh: 3350), // bậc 5: 301–400
    (widthKwh: null, pricePerKwh: 3460), // bậc 6: 401+
  ];

  /// VAT on electricity, used only when there is no real residential bill to
  /// calibrate against.
  static const vatRate = 0.08;

  /// Pre-VAT cost of [kwh] consumed in one billing month on a single
  /// residential meter.
  static num pricePerMonth(num kwh) {
    if (kwh <= 0) return 0;
    var remaining = kwh;
    num total = 0;
    for (final tier in tiers) {
      final width = tier.widthKwh;
      final used = width == null || remaining < width ? remaining : width;
      total += used * tier.pricePerKwh;
      remaining -= used;
      if (remaining <= 0) break;
    }
    return total;
  }
}
