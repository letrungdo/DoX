import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/utils/lunar_calendar.dart';
import 'package:intl/intl.dart';

/// Formatting helpers for chicken dates.
///
/// All chicken dates are stored as *solar* (Gregorian) dates. The lunar
/// calendar is a display layer: depending on the user's setting a date is
/// shown either as itself or converted to its lunar date. Keeping storage
/// solar is what makes the conversion safe — a lunar date needs a leap-month
/// flag that a [DateTime] has nowhere to put, so a stored lunar value cannot
/// tell a leap month from the ordinary month of the same number.
class ChickenDate {
  ChickenDate._();

  static final DateFormat _format = DateFormat('dd/MM/yyyy');

  /// Formats a stored (solar) [date] for display. When [useLunar] is true it is
  /// converted to its lunar date and marked "ÂL", with an "N" after the month
  /// in a leap month (e.g. `08/06N/2025 ÂL`); otherwise it is shown as is.
  static String format(DateTime date, {required bool useLunar}) {
    if (!useLunar) return _format.format(date);
    final lunar = LunarCalendar.solarToLunar(date.day, date.month, date.year);
    final day = lunar.day.toString().padLeft(2, '0');
    final month = lunar.month.toString().padLeft(2, '0');
    return '$day/$month${lunar.isLeap ? 'N' : ''}/${lunar.year} ÂL';
  }

  /// Formats an age in [days] for display. Below a month it is shown in days;
  /// from one month up it is shown as months (using 30-day months) plus the
  /// leftover days, e.g. 63 days → "2 tháng 3 ngày tuổi".
  static String formatAge(AppLocalizations l10n, int days) {
    if (days < 30) return l10n.statusDaysOld(days);
    final months = days ~/ 30;
    final remainingDays = days % 30;
    return remainingDays == 0
        ? l10n.statusMonthsOld(months)
        : l10n.statusMonthsDaysOld(months, remainingDays);
  }
}
