/// One Vietnamese bank as published by VietQR's public directory
/// (`https://api.vietqr.io/v2/banks`).
///
/// Only the fields a picker needs are kept: the directory also carries BIN,
/// SWIFT and transfer-support flags, none of which a savings record cares
/// about.
class Bank {
  const Bank({
    required this.code,
    required this.name,
    required this.shortName,
    this.logo,
  });

  /// The short code VietQR keys the bank by, e.g. "VCB". Unique, so it doubles
  /// as this bank's identity in the picker.
  final String code;

  /// The full registered name, e.g. "Ngân hàng TMCP Ngoại Thương Việt Nam".
  final String name;

  /// The name people actually use, e.g. "Vietcombank". This is what a savings
  /// record stores.
  final String shortName;

  final String? logo;

  static Bank? fromJson(Map<String, dynamic> json) {
    final code = json['code'] as String?;
    final shortName = json['shortName'] as String?;
    // A row missing either is unusable in a picker, and the directory is a
    // third party's — better to drop the row than to render a blank one.
    if (code == null || shortName == null) return null;

    return Bank(
      code: code,
      name: json['name'] as String? ?? shortName,
      shortName: shortName,
      logo: json['logo'] as String?,
    );
  }

  /// Everything a search should look through: people type "vcb", "vietcom" or
  /// "ngoại thương" and expect the same row.
  String get searchIndex => '$shortName $name $code'.toLowerCase();

  @override
  bool operator ==(Object other) => other is Bank && other.code == code;

  @override
  int get hashCode => code.hashCode;
}
