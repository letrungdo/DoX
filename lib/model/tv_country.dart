import 'package:flutter/foundation.dart';

/// One country of the `iptv-org` catalogue — an entry of `api/countries.json`.
///
/// The catalogue is what the country picker lists and what tells the service
/// which playlist file to ask for: `countries/<code>.m3u`, lower-cased.
@immutable
class TvCountry {
  const TvCountry({required this.code, required this.name, this.flag = ''});

  factory TvCountry.fromJson(Map<String, dynamic> json) {
    return TvCountry(
      code: (json['code'] as String? ?? '').toUpperCase(),
      name: json['name'] as String? ?? '',
      flag: json['flag'] as String? ?? '',
    );
  }

  /// Where the page starts, and what it falls back to when the catalogue
  /// cannot be fetched at all — the app is Vietnamese first.
  static const vietnam = TvCountry(code: 'VN', name: 'Vietnam', flag: '🇻🇳');

  /// ISO 3166-1 alpha-2, upper case as the API writes it.
  final String code;

  /// English name from the catalogue; there is no translated list to use.
  final String name;

  /// The flag as an emoji, which is the only artwork the catalogue carries.
  final String flag;

  /// The file name the playlist is published under.
  String get playlistCode => code.toLowerCase();

  String get label => flag.isEmpty ? name : '$flag $name';

  /// What the picker's search box matches on: the name for someone who knows
  /// it, the code for someone who knows that instead.
  String get searchIndex => '$name $code'.toLowerCase();

  Map<String, dynamic> toJson() => {'code': code, 'name': name, 'flag': flag};

  @override
  bool operator ==(Object other) => other is TvCountry && other.code == code;

  @override
  int get hashCode => code.hashCode;
}
