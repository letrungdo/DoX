import 'package:do_x/utils/lunar_calendar.dart';
import 'package:intl/intl.dart';

/// Formatting helpers for chicken dates.
///
/// All chicken dates are stored as *lunar* values (their day/month/year hold a
/// lunar date). Depending on the user's setting they are shown either as the
/// lunar date itself or converted to the solar (Gregorian) calendar.
class ChickenDate {
  ChickenDate._();

  static final DateFormat _format = DateFormat('dd/MM/yyyy');

  /// Formats a stored (lunar-valued) [date] for display. When [useLunar] is
  /// true the lunar date is shown with an "ÂL" marker; otherwise it is
  /// converted to the solar date.
  static String format(DateTime date, {required bool useLunar}) {
    if (useLunar) return '${_format.format(date)} ÂL';
    return _format.format(LunarCalendar.lunarDateTimeToSolar(date));
  }
}
