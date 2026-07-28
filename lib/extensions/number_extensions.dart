import 'package:intl/intl.dart';

extension NumberExtensions on num {
  String toCurrency() {
    return NumberFormat('#,###.##').format(this);
  }

  /// Short form for chart axes and dense tiles ("12,5 Tr" in Vietnamese,
  /// "12.5M" in English). The full figure never fits where these are used.
  String toCompactCurrency({String? locale}) {
    return NumberFormat.compact(locale: locale).format(this);
  }
}

extension MoneyStringExtensions on String {
  /// Parses a money string with thousands separators (e.g. "1,234,500").
  double? toMoney() => double.tryParse(replaceAll(',', ''));
}
