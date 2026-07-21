import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/utils/lunar_calendar.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

/// Shows a month-grid date picker where every cell shows the solar day with
/// its lunar date underneath (like the Lunar tab). [initialLunar] and the
/// returned value are lunar-valued [DateTime]s. Returns null on cancel.
Future<DateTime?> showLunarDatePicker({
  required BuildContext context,
  required DateTime initialLunar,
  int firstYear = 2000,
  int lastYear = 2100,
}) {
  final initialSolar = LunarCalendar.lunarDateTimeToSolar(initialLunar);
  return showDialog<DateTime>(
    context: context,
    builder: (_) => _LunarCalendarPickerDialog(
      initialSolar: initialSolar,
      firstDay: DateTime(firstYear),
      lastDay: DateTime(lastYear, 12, 31),
    ),
  );
}

class _LunarCalendarPickerDialog extends StatefulWidget {
  final DateTime initialSolar;
  final DateTime firstDay;
  final DateTime lastDay;

  const _LunarCalendarPickerDialog({
    required this.initialSolar,
    required this.firstDay,
    required this.lastDay,
  });

  @override
  State<_LunarCalendarPickerDialog> createState() =>
      _LunarCalendarPickerDialogState();
}

class _LunarCalendarPickerDialogState
    extends State<_LunarCalendarPickerDialog> {
  late DateTime _selected;
  late DateTime _focusedDay;

  @override
  void initState() {
    super.initState();
    final s = widget.initialSolar;
    _selected = DateTime(s.year, s.month, s.day);
    _focusedDay = _selected;
  }

  void _shiftMonth(int delta) {
    final target = DateTime(_focusedDay.year, _focusedDay.month + delta);
    setState(() {
      _focusedDay = target.isBefore(widget.firstDay)
          ? widget.firstDay
          : (target.isAfter(widget.lastDay) ? widget.lastDay : target);
    });
  }

  @override
  Widget build(BuildContext context) {
    final materialL10n = MaterialLocalizations.of(context);
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      title: Text(l10n.lunarDatePickerTitle, textAlign: TextAlign.center),
      contentPadding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(context),
            const SizedBox(height: 4),
            _buildCalendar(context),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(materialL10n.cancelButtonLabel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(
            context,
            LunarCalendar.solarToLunarDateTime(_selected),
          ),
          child: Text(materialL10n.okButtonLabel),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final localeName = Localizations.localeOf(context).toString();
    final title = _capitalize(DateFormat.yMMMM(localeName).format(_focusedDay));
    final lunar = LunarCalendar.solarToLunar(
      1,
      _focusedDay.month,
      _focusedDay.year,
    );
    final canChiYear = LunarCalendar.canChiOfYear(lunar.year);

    return Row(
      children: [
        IconButton(
          onPressed: () => _shiftMonth(-1),
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Expanded(
          child: Column(
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '${l10n.yearPrefix} $canChiYear',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => _shiftMonth(1),
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }

  Widget _buildCalendar(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final localeName = Localizations.localeOf(context).toString();

    return TableCalendar(
      locale: localeName,
      firstDay: widget.firstDay,
      lastDay: widget.lastDay,
      focusedDay: _focusedDay,
      currentDay: DateTime.now(),
      rowHeight: 50,
      daysOfWeekHeight: 20,
      startingDayOfWeek: StartingDayOfWeek.monday,
      headerVisible: false,
      availableGestures: AvailableGestures.horizontalSwipe,
      selectedDayPredicate: (day) => isSameDay(_selected, day),
      onDaySelected: (selectedDay, focusedDay) {
        setState(() {
          _selected = DateTime(
            selectedDay.year,
            selectedDay.month,
            selectedDay.day,
          );
          _focusedDay = focusedDay;
        });
      },
      onPageChanged: (focusedDay) => setState(() => _focusedDay = focusedDay),
      calendarBuilders: CalendarBuilders(
        dowBuilder: (context, day) {
          final label = _capitalize(DateFormat.E(localeName).format(day));
          return Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
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
    final scheme = Theme.of(context).colorScheme;
    final isSunday = date.weekday == DateTime.sunday;

    final lunar = LunarCalendar.solarToLunar(date.day, date.month, date.year);
    final showLunarMonth = lunar.day == 1;
    final lunarText = showLunarMonth
        ? '${lunar.day}/${lunar.month}'
        : '${lunar.day}';

    final baseColor = isSunday ? scheme.error : scheme.onSurface;
    final solarColor = isOutside ? baseColor.withValues(alpha: 0.3) : baseColor;
    final isSpecialLunar = lunar.day == 1 || lunar.day == 15;
    final lunarColor = isSpecialLunar ? scheme.error : scheme.onSurfaceVariant;

    return Container(
      margin: const EdgeInsets.all(2),
      width: double.infinity,
      decoration: BoxDecoration(
        color: isSelected ? scheme.primaryContainer : null,
        border: Border.all(
          color: isToday ? scheme.primary : Colors.transparent,
          width: 1.4,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${date.day}',
            style: TextStyle(
              fontSize: 15,
              fontWeight: isToday || isSelected
                  ? FontWeight.w700
                  : FontWeight.w500,
              color: isSelected ? scheme.onPrimaryContainer : solarColor,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            lunarText,
            style: TextStyle(
              fontSize: 9.5,
              color: (isSelected ? scheme.onPrimaryContainer : lunarColor)
                  .withValues(alpha: isOutside ? 0.4 : 1),
              fontWeight: showLunarMonth || isSpecialLunar
                  ? FontWeight.w700
                  : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
