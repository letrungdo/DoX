import 'package:do_x/widgets/input/cute_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Money input: "đ" unit on the right, thousands separators added while typing.
class CuteMoneyField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? errorText;
  final ValueChanged<String>? onChanged;

  const CuteMoneyField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.errorText,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return CuteTextField(
      controller: controller,
      label: label,
      hint: hint,
      errorText: errorText,
      suffixText: "đ",
      keyboardType: TextInputType.number,
      inputFormatters: [ThousandsSeparatorInputFormatter()],
      onChanged: onChanged,
    );
  }
}

/// Inserts thousands separators while typing, keeping the cursor in place.
class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;

    // Keep digits and at most one decimal point.
    final raw = StringBuffer();
    var seenDot = false;
    var rawCharsBeforeCursor = 0;
    for (var i = 0; i < text.length; i++) {
      final c = text[i];
      final isDigit = c.compareTo('0') >= 0 && c.compareTo('9') <= 0;
      if (isDigit || (c == '.' && !seenDot)) {
        if (c == '.') seenDot = true;
        raw.write(c);
        if (i < newValue.selection.end) rawCharsBeforeCursor++;
      }
    }
    final rawText = raw.toString();
    if (rawText.isEmpty) return const TextEditingValue(text: '');

    final dotIndex = rawText.indexOf('.');
    final intPart = dotIndex < 0 ? rawText : rawText.substring(0, dotIndex);
    final decPart = dotIndex < 0 ? '' : rawText.substring(dotIndex);
    final formattedInt = StringBuffer();
    for (var i = 0; i < intPart.length; i++) {
      if (i > 0 && (intPart.length - i) % 3 == 0) formattedInt.write(',');
      formattedInt.write(intPart[i]);
    }
    final formatted = '$formattedInt$decPart';

    var cursor = 0;
    var seen = 0;
    while (cursor < formatted.length && seen < rawCharsBeforeCursor) {
      if (formatted[cursor] != ',') seen++;
      cursor++;
    }
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: cursor),
    );
  }
}
