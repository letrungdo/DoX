import 'package:do_x/constants/date_time.dart';
import 'package:intl/intl.dart';

extension DateOnlyExtensions on DateTime {
  /// The date with the time of day dropped. Chicken records hold whole days,
  /// so a value taken from [DateTime.now] goes through here first — otherwise
  /// the leftover time makes day counts (an age, "is it overdue") depend on
  /// what o'clock the record happened to be created.
  DateTime get dateOnly => DateTime(year, month, day);
}

extension DateExtensions on DateTime? {
  String toStringFormat([String pattern = DateTimeConst.yyyyMMddSolidus]) {
    if (this == null) return "-";

    return DateFormat(pattern).format(this!);
  }
}
