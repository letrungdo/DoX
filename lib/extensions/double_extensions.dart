import 'package:decimal/decimal.dart';
import 'package:decimal/intl.dart';
import 'package:do_x/constants/app_const.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

extension DoubleNullableExtensions on double? {
  double? celsiusToFahrenheit() {
    final value = this;
    if (value == null) return null;
    return (value * 9 / 5) + 32;
  }

  Decimal toDecimal() => Decimal.parse('$this');

  /// Support #,###.0{N}, N is digit
  /// if digit = -1 => keep all decimal from api
  String formatUnit({int? digit, bool hasPlus = false}) {
    final value = this;
    if (value == null) return AppConst.dash;
    return value.toDecimal().formatUnit(digit: digit, hasPlus: hasPlus);
  }

  /// Market caps and turnovers run to twelve digits, which no stat row has the
  /// width for — shortened to a K/M/B/T suffix, which reads the same in both of
  /// the app's languages. Anything under a thousand keeps the plain format.
  String formatCompact({int digit = 2}) {
    final value = this;
    if (value == null) return AppConst.dash;
    const units = [(1e12, 'T'), (1e9, 'B'), (1e6, 'M'), (1e3, 'K')];
    final magnitude = value.abs();
    for (final (size, suffix) in units) {
      if (magnitude >= size) {
        return '${(value / size).toStringAsFixed(digit)}$suffix';
      }
    }
    return formatUnit();
  }

  Color? getColor() {
    final valueNumber = this;

    if (valueNumber == null || valueNumber == 0) return null;

    if (valueNumber > 0) return Colors.green;
    return Colors.red;
  }
}

extension DecimalCanBeNullExtension on Decimal? {
  int? get toInt => this?.toBigInt().toInt();

  /// Support ±#,###.0{N}, N is digit
  String formatUnit({int? digit, bool hasPlus = false}) {
    final value = this;
    if (value == null) return AppConst.dash;

    final formatValue = DecimalFormatter(
      NumberFormat.decimalPatternDigits(decimalDigits: digit),
    ).format(value);

    if (hasPlus && value > Decimal.zero) {
      return "+$formatValue";
    }
    return formatValue;
  }
}
