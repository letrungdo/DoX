import 'package:do_x/constants/dimens.dart';
import 'package:do_x/widgets/input/app_input_decoration.dart';
import 'package:do_x/widgets/input/app_text_field.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Date picker field styled consistently with [AppTextField].
class DateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onChanged;

  const DateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(Dimens.radiusControl),
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
        decoration: appInputDecoration(
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
