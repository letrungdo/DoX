import 'package:flutter/material.dart';

/// Rounded, soft-filled decoration shared by TextFields/Dropdowns in dialogs.
InputDecoration cuteInputDecoration(
  BuildContext context,
  String label, {
  String? hint,
  String? prefixText,
  String? suffixText,
  Widget? suffixIcon,
  String? errorText,
}) {
  final scheme = Theme.of(context).colorScheme;
  // Sunken fill, no resting outline: the recess is what marks the field as an
  // input, and only focus is worth a visible line.
  OutlineInputBorder border([BorderSide? side]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: side ?? BorderSide.none,
  );
  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixText: prefixText,
    suffixText: suffixText,
    suffixIcon: suffixIcon,
    errorText: errorText,
    filled: true,
    fillColor: scheme.surfaceContainerLow,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: border(const BorderSide(color: Colors.transparent)),
    enabledBorder: border(),
    focusedBorder: border(BorderSide(color: scheme.primary, width: 1.6)),
  );
}
