import 'package:flutter/services.dart';

/// Inserts thousands separators while typing, keeping the cursor in place.
class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  /// Whether a ',' the user just typed is the decimal point. The decimal key
  /// on a Vietnamese keyboard types ',', which would otherwise be dropped as a
  /// thousands separator.
  final bool decimalComma;

  const ThousandsSeparatorInputFormatter({this.decimalComma = false});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = newValue.text;
    if (text.isEmpty) return newValue;

    final end = newValue.selection.end;
    final typedComma =
        decimalComma &&
        newValue.selection.isCollapsed &&
        text.length == oldValue.text.length + 1 &&
        end > 0 &&
        text[end - 1] == ',';
    if (typedComma) {
      text = '${text.substring(0, end - 1)}.${text.substring(end)}';
    }

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
    final rawInt = dotIndex < 0 ? rawText : rawText.substring(0, dotIndex);
    final decPart = dotIndex < 0 ? '' : rawText.substring(dotIndex);
    // Drop leading zeros: "01" -> "1", "00" -> "0" (keep a single leading 0 so
    // "0.5" still works). Shift the cursor back past any zeros we removed.
    final intPart = rawInt.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    final removedZeros = rawInt.length - intPart.length;
    if (removedZeros > 0) {
      rawCharsBeforeCursor = rawCharsBeforeCursor > removedZeros
          ? rawCharsBeforeCursor - removedZeros
          : 0;
    }
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
