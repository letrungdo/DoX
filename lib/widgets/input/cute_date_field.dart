import 'package:do_x/widgets/input/cute_input_decoration.dart';
import 'package:do_x/widgets/input/cute_text_field.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Date picker field styled consistently with [CuteTextField].
class CuteDateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onChanged;

  const CuteDateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        // When empty, the label sits inline and acts as the placeholder —
        // rendering a placeholder child too would draw both on top of each other.
        isEmpty: value == null,
        decoration: cuteInputDecoration(
          context,
          label,
          suffixIcon: const Icon(Icons.calendar_month_rounded, size: 20),
        ),
        child: value == null
            ? const SizedBox.shrink()
            : Text(DateFormat('dd/MM/yyyy').format(value!)),
      ),
    );
  }
}
