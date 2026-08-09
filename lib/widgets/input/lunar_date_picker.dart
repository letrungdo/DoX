import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/utils/lunar_calendar.dart';
import 'package:do_x/widgets/dialog/app_modal.dart';
import 'package:do_x/widgets/lunar_calendar_grid.dart';
import 'package:do_x/widgets/neu/neu_button.dart';
import 'package:do_x/widgets/dialog/dialog_action_button.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Shows a month-grid date picker where every cell shows the solar day with
/// its lunar date underneath (like the Lunar tab). [initialDate] and the
/// returned value are solar dates. Returns null on cancel.
Future<DateTime?> showLunarDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  int firstYear = 2000,
  int lastYear = 2100,
}) {
  return showAppModal<DateTime>(
    context,
    builder: (_) => _LunarCalendarPickerDialog(
      initialSolar: initialDate,
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
    return AppDialog(
      titleWidget: Text(l10n.lunarDatePickerTitle, textAlign: TextAlign.center),
      // Tighter than the usual dialog padding so the calendar grid gets the
      // width; the dialog's own margins stay the shared ones.
      contentPadding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
      // Scrolls if the larger grid doesn't fit the dialog's height on short
      // screens, avoiding a RenderFlex overflow — landscape especially.
      content: SizedBox(
        // Fills the panel, which `AppDialog` has already capped.
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(context),
              const SizedBox(height: 4),
              _buildCalendar(context),
            ],
          ),
        ),
      ),
      actions: [
        DialogActionButton(
          text: materialL10n.cancelButtonLabel,
          kind: DialogActionKind.cancel,
          onPressed: () => Navigator.pop(context),
        ),
        DialogActionButton(
          text: materialL10n.okButtonLabel,
          onPressed: () => Navigator.pop(context, _selected),
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
        NeuIconButton(
          icon: Icons.chevron_left_rounded,
          onPressed: () => _shiftMonth(-1),
        ),
        Expanded(
          child: Column(
            children: [
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '${l10n.yearPrefix} $canChiYear',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        NeuIconButton(
          icon: Icons.chevron_right_rounded,
          onPressed: () => _shiftMonth(1),
        ),
      ],
    );
  }

  Widget _buildCalendar(BuildContext context) {
    return LunarCalendarGrid(
      firstDay: widget.firstDay,
      lastDay: widget.lastDay,
      focusedDay: _focusedDay,
      selectedDay: _selected,
      onDaySelected: (selected, focused) {
        setState(() {
          _selected = DateTime(selected.year, selected.month, selected.day);
          _focusedDay = focused;
        });
      },
      onPageChanged: (focused) => setState(() => _focusedDay = focused),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
