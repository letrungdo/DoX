import 'package:do_x/constants/dimens.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/utils/lunar_calendar.dart';
import 'package:do_x/widgets/neu/neu_surface.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

/// The month grid shared by the Lunar tab and the lunar date picker: each cell
/// carries the solar day with its lunar date underneath.
///
/// Both surfaces used to carry their own copy of this, which is how their row
/// spacing drifted apart. Keep the metrics here and they stay in step.
class LunarCalendarGrid extends StatelessWidget {
  const LunarCalendarGrid({
    super.key,
    required this.focusedDay,
    required this.selectedDay,
    required this.firstDay,
    required this.lastDay,
    required this.onDaySelected,
    required this.onPageChanged,
  });

  final DateTime focusedDay;
  final DateTime selectedDay;
  final DateTime firstDay;
  final DateTime lastDay;

  /// `(selectedDay, focusedDay)`, both solar.
  final void Function(DateTime selected, DateTime focused) onDaySelected;
  final ValueChanged<DateTime> onPageChanged;

  /// A cell needs ~40dp for its two numbers; the rest is breathing room. Kept
  /// tight so six rows plus the header still fit a dialog on a short screen.
  static const rowHeight = 52.0;
  static const daysOfWeekHeight = 24.0;

  /// Horizontal gap between cells is wider than the vertical one: the columns
  /// need telling apart, the rows read as rows on their own.
  static const _cellMargin = EdgeInsets.symmetric(horizontal: 2, vertical: 1);

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colorScheme;
    final localeName = Localizations.localeOf(context).toString();

    return TableCalendar(
      locale: localeName,
      firstDay: firstDay,
      lastDay: lastDay,
      focusedDay: focusedDay,
      currentDay: DateTime.now(),
      rowHeight: rowHeight,
      daysOfWeekHeight: daysOfWeekHeight,
      startingDayOfWeek: StartingDayOfWeek.monday,
      headerVisible: false,
      availableGestures: AvailableGestures.horizontalSwipe,
      selectedDayPredicate: (day) => isSameDay(selectedDay, day),
      onDaySelected: onDaySelected,
      onPageChanged: onPageChanged,
      calendarBuilders: CalendarBuilders(
        dowBuilder: (context, day) {
          final label = _capitalize(DateFormat.E(localeName).format(day));
          return Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: day.weekday == DateTime.sunday
                    ? scheme.error
                    : scheme.onSurfaceVariant,
              ),
            ),
          );
        },
        defaultBuilder: (context, day, _) => _cell(context, day),
        outsideBuilder: (context, day, _) =>
            _cell(context, day, isOutside: true),
        todayBuilder: (context, day, _) => _cell(context, day, isToday: true),
        selectedBuilder: (context, day, _) => _cell(
          context,
          day,
          isSelected: true,
          isToday: isSameDay(day, DateTime.now()),
        ),
      ),
    );
  }

  Widget _cell(
    BuildContext context,
    DateTime date, {
    bool isToday = false,
    bool isSelected = false,
    bool isOutside = false,
  }) {
    final scheme = context.theme.colorScheme;
    final isSunday = date.weekday == DateTime.sunday;

    final lunar = LunarCalendar.solarToLunar(date.day, date.month, date.year);
    // Show the month only every other day to reduce clutter; odd lunar days
    // (which include mùng 1 & rằm) carry the month, even days show just the day.
    final showLunarMonth = lunar.day.isOdd;

    final baseColor = isSunday ? scheme.error : scheme.onSurface;
    final solarColor = isOutside ? baseColor.withValues(alpha: 0.3) : baseColor;
    // Mùng 1 & rằm stand out in red, like paper almanacs.
    final isSpecialLunar = lunar.day == 1 || lunar.day == 15;
    final lunarColor = isSpecialLunar ? scheme.error : scheme.onSurfaceVariant;

    return Container(
      margin: _cellMargin,
      width: double.infinity,
      decoration: BoxDecoration(
        // Selected is the strong fill, today a soft tint of the same colour —
        // the outline it used to carry was the only border on the screen.
        color: isSelected
            ? scheme.primaryContainer
            : isToday
            ? context.neuTint(scheme.primary, amount: 0.14)
            : null,
        borderRadius: BorderRadius.circular(Dimens.radiusControlSmall),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${date.day}',
            style: TextStyle(
              fontSize: 20,
              // Tight line box on both numbers, no gap widget: most of what
              // used to separate solar from lunar was the fonts' own leading.
              height: 1.05,
              fontWeight: isToday || isSelected
                  ? FontWeight.w700
                  : FontWeight.w500,
              color: isSelected ? scheme.onPrimaryContainer : solarColor,
            ),
          ),
          Text.rich(
            TextSpan(
              children: [
                // Lunar day is emphasised; the month reads lighter beside it.
                TextSpan(
                  text: '${lunar.day}',
                  style: TextStyle(
                    fontWeight: isSpecialLunar
                        ? FontWeight.w700
                        : FontWeight.w600,
                  ),
                ),
                if (showLunarMonth)
                  TextSpan(
                    // "N" marks a leap month, so the two month sixes of a leap
                    // year are told apart at a glance.
                    text: '/${lunar.month}${lunar.isLeap ? 'N' : ''}',
                    style: const TextStyle(fontWeight: FontWeight.w400),
                  ),
              ],
            ),
            style: TextStyle(
              fontSize: 14,
              height: 1.05,
              color: (isSelected ? scheme.onPrimaryContainer : lunarColor)
                  .withValues(alpha: isOutside ? 0.4 : 1),
            ),
          ),
        ],
      ),
    );
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
