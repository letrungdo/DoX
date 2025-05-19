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

    final formatValue = DecimalFormatter(NumberFormat.decimalPatternDigits(decimalDigits: digit)).format(value);

    if (hasPlus && value > Decimal.zero) {
      return "+$formatValue";
    }
    return formatValue;
  }
}
