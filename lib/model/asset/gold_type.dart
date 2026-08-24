import 'package:do_x/model/fx/gold_model.dart';

enum GoldAssetType {
  sjcPiece("Vàng miếng SJC", "SJCSJCHCM"),
  sjcRing("Vàng nhẫn 9999 SJC", "RING9999SJCHCM"),
  privateRing("Vàng nhẫn 9999 (Tư nhân)", "PRIVATE");

  const GoldAssetType(this.label, this.code);
  final String label;
  final String code;

  static GoldAssetType? fromLabel(String? label) {
    return GoldAssetType.values.where((e) => e.label == label).firstOrNull;
  }
}

extension GoldPriceExtension on List<GoldSymbol> {
  double? findPrice(GoldAssetType type) {
    if (type == GoldAssetType.privateRing) {
      // Private ring is usually ~10m cheaper than SJC Ring (per tael)
      final sjcRingPrice = findPrice(GoldAssetType.sjcRing);
      return sjcRingPrice != null ? sjcRingPrice - 10000000 : null;
    }

    // Try to find by exact code match first
    final byCode = firstWhereOrNull((s) => s.code == type.code);
    return byCode?.bid;
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
