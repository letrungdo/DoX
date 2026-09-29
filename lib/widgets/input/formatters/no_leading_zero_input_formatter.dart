import 'package:flutter/services.dart';

/// Strips leading zeros from a plain integer field: "01" -> "1", "00" -> "0".
/// Pair it after [FilteringTextInputFormatter.digitsOnly] on quantity inputs.
class NoLeadingZeroInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    final stripped = text.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    if (stripped == text) return newValue;
    final removed = text.length - stripped.length;
    var offset = newValue.selection.end - removed;
    offset = offset.clamp(0, stripped.length);
    return TextEditingValue(
      text: stripped,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}
