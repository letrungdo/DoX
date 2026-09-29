import 'package:do_x/widgets/input/formatters/decimal_input_formatter.dart';
import 'package:do_x/widgets/input/formatters/thousands_separator_input_formatter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

TextEditingValue _value(String text) => TextEditingValue(
  text: text,
  selection: TextSelection.collapsed(offset: text.length),
);

TextEditingValue _type(
  TextInputFormatter formatter,
  String before,
  String key,
) => formatter.formatEditUpdate(_value(before), _value('$before$key'));

void main() {
  group('DecimalInputFormatter', () {
    final formatter = DecimalInputFormatter();

    test('turns the Vietnamese decimal comma into a dot', () {
      expect(_type(formatter, '1', ',').text, '1.');
      expect(double.tryParse(_type(formatter, '0,2', '5').text), 0.25);
    });

    test('keeps only digits and a single separator', () {
      expect(_type(formatter, '1.5.', '2').text, '1.52');
      expect(_type(formatter, '1,5', ',').text, '1.5');
      expect(_type(formatter, 'a1 ', '2').text, '12');
    });

    test('leaves the cursor at the end of the cleaned text', () {
      final value = _type(formatter, '1,5', 'x');
      expect(value.text, '1.5');
      expect(value.selection.end, 3);
    });
  });

  group('ThousandsSeparatorInputFormatter', () {
    test('groups thousands and drops a typed comma for đồng', () {
      const formatter = ThousandsSeparatorInputFormatter();
      expect(_type(formatter, '1,234', '5').text, '12,345');
      expect(_type(formatter, '12', ',').text, '12');
    });

    test('reads a typed comma as the decimal point for dollars', () {
      const formatter = ThousandsSeparatorInputFormatter(decimalComma: true);
      expect(_type(formatter, '1,234', ',').text, '1,234.');
      expect(_type(formatter, '1,234.', '5').text, '1,234.5');
      expect(_type(formatter, '0', ',').text, '0.');
    });
  });
}
