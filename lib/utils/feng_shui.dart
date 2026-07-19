/// Feng-shui direction helpers: maps a compass bearing (0–360°, 0 = North,
/// clockwise) to the 8 trigrams (Bát quái) and the 24 mountains (Nhị thập tứ
/// sơn) used on a traditional geomancy compass (la bàn phong thủy).
class FengShui {
  FengShui._();

  /// 8 cardinal/intercardinal names, index 0 = North, clockwise.
  static const _directionNames = [
    'Bắc',
    'Đông Bắc',
    'Đông',
    'Đông Nam',
    'Nam',
    'Tây Nam',
    'Tây',
    'Tây Bắc',
  ];

  /// Trigrams aligned with [_directionNames].
  static const _trigrams = [
    'Khảm',
    'Cấn',
    'Chấn',
    'Tốn',
    'Ly',
    'Khôn',
    'Đoài',
    'Càn',
  ];

  /// Five-element (ngũ hành) of each trigram, aligned with [_trigrams].
  static const _elements = [
    'Thủy',
    'Thổ',
    'Mộc',
    'Mộc',
    'Hỏa',
    'Thổ',
    'Kim',
    'Kim',
  ];

  /// 24 mountains, index 0 centered at 0° (Tý), each spanning 15°, clockwise.
  static const _mountains = [
    'Tý',
    'Quý',
    'Sửu',
    'Cấn',
    'Dần',
    'Giáp',
    'Mão',
    'Ất',
    'Thìn',
    'Tốn',
    'Tỵ',
    'Bính',
    'Ngọ',
    'Đinh',
    'Mùi',
    'Khôn',
    'Thân',
    'Canh',
    'Dậu',
    'Tân',
    'Tuất',
    'Càn',
    'Hợi',
    'Nhâm',
  ];

  static double _normalize(double deg) {
    var d = deg % 360;
    if (d < 0) d += 360;
    return d;
  }

  static int _directionIndex(double heading) {
    // Shift by half a sector (22.5°) so North spans 337.5–22.5°.
    return (((_normalize(heading) + 22.5) % 360) / 45).floor();
  }

  /// Full feng-shui reading for a bearing.
  static FengShuiDirection of(double heading) {
    final h = _normalize(heading);
    final dirIndex = _directionIndex(h);
    final mountainIndex = ((h + 7.5) % 360 / 15).floor() % 24;
    return FengShuiDirection(
      bearing: h,
      name: _directionNames[dirIndex],
      trigram: _trigrams[dirIndex],
      element: _elements[dirIndex],
      mountain: _mountains[mountainIndex],
    );
  }
}

class FengShuiDirection {
  /// Normalized bearing in degrees (0 = North, clockwise).
  final double bearing;

  /// 8-point direction name, e.g. "Đông Nam".
  final String name;

  /// Trigram (Bát quái), e.g. "Tốn".
  final String trigram;

  /// Five-element of the trigram, e.g. "Mộc".
  final String element;

  /// One of the 24 mountains, e.g. "Tốn".
  final String mountain;

  const FengShuiDirection({
    required this.bearing,
    required this.name,
    required this.trigram,
    required this.element,
    required this.mountain,
  });

  /// Short compass abbreviation for the 8 directions (B, ĐB, Đ, ...).
  String get abbreviation {
    return switch (name) {
      'Bắc' => 'B',
      'Đông Bắc' => 'ĐB',
      'Đông' => 'Đ',
      'Đông Nam' => 'ĐN',
      'Nam' => 'N',
      'Tây Nam' => 'TN',
      'Tây' => 'T',
      'Tây Bắc' => 'TB',
      _ => '',
    };
  }
}
