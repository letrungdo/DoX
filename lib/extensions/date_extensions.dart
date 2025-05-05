import 'package:do_x/constants/date_time.dart';
import 'package:intl/intl.dart';

extension DateExtensions on DateTime? {
  String toStringFormat([String pattern = DateTimeConst.yyyyMMddSolidus]) {
    if (this == null) return "-";

    return DateFormat(pattern).format(this!);
  }
}
