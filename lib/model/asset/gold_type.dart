import 'package:do_x/model/fx/gold_model.dart';

/// The kinds of gold a record can hold, each pinned to the `gold_prices.code`
/// that quotes it. A plain ring from a private jeweller is recorded as a plain
/// ring: it tracks the PNJ quote closely enough that a separate type only made
/// the picker longer.
enum GoldAssetType {
  sjcPiece("Vàng miếng SJC", "SJC_HCM"),
  ring9999("Vàng nhẫn 9999", "PNJ_RING_9999");

  const GoldAssetType(this.label, this.code);
  final String label;
  final String code;

  static GoldAssetType? fromLabel(String? label) {
    return GoldAssetType.values.where((e) => e.label == label).firstOrNull;
  }
}

extension GoldPriceExtension on List<GoldSymbol> {
  /// What the holding is worth today: the price a shop buys back at (`bid`),
  /// not the one it sells at.
  double? findPrice(GoldAssetType type) {
    return firstWhereOrNull((s) => s.code == type.code)?.bid;
  }
}

extension _ListExt<T> on List<T> {
  T? firstWhereOrNull(bool Function(T element) test) {
    for (var element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}
