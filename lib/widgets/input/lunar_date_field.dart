import 'package:do_x/utils/chicken_date.dart';
import 'package:do_x/utils/lunar_calendar.dart';
import 'package:do_x/widgets/input/lunar_date_picker.dart';
import 'package:do_x/widgets/input/cute_input_decoration.dart';
import 'package:flutter/material.dart';

/// Date field for chicken dates. [value] is always the canonical lunar-valued
/// date. When [useLunar] is true the user picks on the lunar calendar; when
/// false a normal solar picker is shown and its result is converted back to a
/// lunar value before [onChanged] fires, so storage stays lunar in both modes.
class LunarDateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final bool useLunar;
  final ValueChanged<DateTime> onChanged;

  const LunarDateField({
    super.key,
    required this.label,
    required this.value,
    required this.useLunar,
    required this.onChanged,
  });

  Future<void> _pick(BuildContext context) async {
    // The picker's month grid shows both the solar day and its lunar date, so
    // it serves both display modes; only the field's own text differs.
    final initial = value ?? LunarCalendar.solarToLunarDateTime(DateTime.now());
    final picked = await showLunarDatePicker(
      context: context,
      initialLunar: initial,
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _pick(context),
      child: InputDecorator(
        isEmpty: value == null,
        decoration: cuteInputDecoration(
          context,
          label,
          suffixIcon: const Icon(Icons.calendar_month_rounded, size: 20),
        ),
        child: value == null
            ? const SizedBox.shrink()
            : Text(ChickenDate.format(value!, useLunar: useLunar)),
      ),
    );
  }
}
