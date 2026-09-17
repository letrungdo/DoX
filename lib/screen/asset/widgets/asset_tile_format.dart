import 'package:intl/intl.dart';

/// Formatting shared by the asset tiles, so a figure reads the same whichever
/// list it appears in.
///
/// The tiles are two narrow columns on a phone, and a full "107.000.000 ₫"
/// forces every neighbouring string to shrink around it. Amounts inside a row
/// are therefore compact and carry no symbol ("107 Tr") — inside a tile whose
/// headline is already in đồng, repeating it only costs width. Only that
/// headline is written out in full.
class AssetFormat {
  AssetFormat(String locale)
    : _full = NumberFormat.currency(locale: locale, symbol: '₫'),
      _compact = NumberFormat.compact(locale: locale),
      _decimal = NumberFormat('#,##0.#', locale),
      _locale = locale;

  final NumberFormat _full;
  final NumberFormat _compact;
  final NumberFormat _decimal;
  final String _locale;

  /// The headline figure: "287.000.000 ₫".
  String money(double value) => _full.format(value);

  /// An in-row figure: "107 Tr".
  String compact(double value) => _compact.format(value);

  /// Signed, because whether a number is a gain or a loss is read before the
  /// number itself: "+107 Tr", "-8,4 Tr".
  String signedCompact(double value) => '${_sign(value)}${compact(value)}';

  String signedPercent(double value) {
    return '${_sign(value)}${_decimal.format(value)}%';
  }

  /// An interest rate as typed, without a trailing ".0": "7", "6,8".
  String rate(double value) => _decimal.format(value);

  /// A quantity as typed, without a trailing ".0": "2", "1,5".
  String quantity(double value) => _decimal.format(value);

  /// Dollars, which Vietnamese writes with the same grouping as đồng.
  String usd(double value) =>
      '\$${NumberFormat('#,##0.##', _locale).format(value)}';

  String _sign(double value) => value >= 0 ? '+' : '';
}
