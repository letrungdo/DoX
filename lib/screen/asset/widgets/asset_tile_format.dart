import 'package:intl/intl.dart';

/// Formatting shared by the asset tiles, so a figure reads the same whichever
/// list it appears in.
///
/// Numbers are grouped with commas and suffixed "đ", which is how the app
/// writes money everywhere else — `CuteMoneyField` types it that way and the
/// news page prints its rates that way — so a tile using Vietnamese dot
/// grouping was the odd one out. It also drops the space `NumberFormat`'s
/// currency mode puts before the symbol, which pushed the unit onto its own
/// cluster at the tile's edge.
///
/// The tiles are two narrow columns on a phone, and a full "107,000,000đ"
/// forces every neighbouring string to shrink around it. Amounts inside a row
/// are therefore compact and carry no unit ("107tr") — inside a tile whose
/// headline is already in đồng, repeating it only costs width. Only that
/// headline is written out in full.
class AssetFormat {
  /// Not localised, deliberately: see the note above.
  static final _grouped = NumberFormat('#,##0', 'en');
  static final _decimal = NumberFormat('#,##0.##', 'en');

  /// The headline figure: "200,920,548đ".
  String money(double value) => '${_grouped.format(value)}đ';

  /// An in-row figure: "107tr", "920.55k", "850".
  String compact(double value) {
    final magnitude = value.abs();
    if (magnitude >= 1000000000) return '${_decimal.format(value / 1e9)}ty';
    if (magnitude >= 1000000) return '${_decimal.format(value / 1e6)}tr';
    if (magnitude >= 1000) return '${_decimal.format(value / 1e3)}k';

    return _grouped.format(value);
  }

  /// Signed, because whether a number is a gain or a loss is read before the
  /// number itself: "+107tr", "-8.4tr".
  String signedCompact(double value) => '${_sign(value)}${compact(value)}';

  String signedPercent(double value) {
    return '${_sign(value)}${_decimal.format(value)}%';
  }

  /// An interest rate as typed, without a trailing ".0": "7", "6.8".
  String rate(double value) => _decimal.format(value);

  /// A quantity as typed, without a trailing ".0": "2", "1.5".
  String quantity(double value) => _decimal.format(value);

  /// Dollars, grouped the same way as đồng: "$3,600".
  String usd(double value) => '\$${_decimal.format(value)}';

  String _sign(double value) => value >= 0 ? '+' : '';
}
