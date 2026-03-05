import 'package:intl/intl.dart';

extension NumberExtensions on num {
  String toCurrency() {
    return NumberFormat('#,###.##').format(this);
  }
}
