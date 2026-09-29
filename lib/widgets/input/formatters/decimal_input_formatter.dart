import 'package:flutter/services.dart';

/// Keeps a plain decimal field parseable by [double.tryParse]: digits and a
/// single '.', with a ',' turned into '.'. The decimal key on a Vietnamese
/// keyboard types ',', which [double.tryParse] would otherwise reject.
class DecimalInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    final buffer = StringBuffer();
    var seenDot = false;
    final end = newValue.selection.isValid
        ? newValue.selection.end
        : text.length;
    var cursor = end;
    for (var i = 0; i < text.length; i++) {
      var c = text[i];
      if (c == ',') c = '.';
      final isDigit = c.compareTo('0') >= 0 && c.compareTo('9') <= 0;
      if (isDigit || (c == '.' && !seenDot)) {
        if (c == '.') seenDot = true;
        buffer.write(c);
      } else if (i < end) {
        cursor--;
      }
    }
    final result = buffer.toString();
    if (result == text) return newValue;
    return TextEditingValue(
      text: result,
      selection: TextSelection.collapsed(
        offset: cursor.clamp(0, result.length),
      ),
    );
  }
}
