import 'package:intl/intl.dart';

extension NumberExtensions on num {
  String toCurrency() {
    return NumberFormat('#,###.##').format(this);
  }
}

extension MoneyStringExtensions on String {
  /// Parses a money string with thousands separators (e.g. "1,234,500").
  double? toMoney() => double.tryParse(replaceAll(',', ''));
}
