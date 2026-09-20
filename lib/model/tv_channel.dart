import 'package:flutter/foundation.dart';

/// One live channel from an IPTV playlist.
///
/// Everything here comes out of a single `#EXTINF` entry — the playlist is the
/// only source of truth, so the model carries what it says and nothing more.
@immutable
class TvChannel {
  const TvChannel({
    required this.id,
    required this.name,
    required this.url,
    this.logo,
    this.groups = const [],
    this.quality,
    this.isGeoBlocked = false,
    this.isIntermittent = false,
    this.headers = const {},
  });

  /// `tvg-id` when the playlist has one, the stream URL otherwise — a playlist
  /// is free to repeat an empty id, so it can never be the key on its own.
  final String id;

  /// Channel name with the parenthesised quality and the bracketed flags
  /// already stripped off; those live in [quality], [isGeoBlocked] and
  /// [isIntermittent] instead.
  final String name;

  final String url;
  final String? logo;

  /// `group-title`, split on `;` — a channel is often filed under several.
  final List<String> groups;

  /// Vertical resolution the playlist advertises, e.g. `1080p`.
  final String? quality;

  /// The source only serves this channel inside its own country.
  final bool isGeoBlocked;

  /// The channel does not broadcast around the clock (`[Not 24/7]`).
  final bool isIntermittent;

  /// Headers the stream needs — a `Referer` or a `User-Agent` some CDNs check
  /// before they hand over the playlist.
  final Map<String, String> headers;

  bool get hasLogo => logo != null && logo!.isNotEmpty;

  /// Whether the channel matches a search box's [query], accent-insensitively
  /// enough for the Vietnamese names in these playlists.
  bool matches(String query) {
    final needle = _normalize(query);
    if (needle.isEmpty) return true;
    return _normalize(name).contains(needle);
  }

  static String _normalize(String value) {
    var text = value.toLowerCase().trim();
    for (final entry in _accents.entries) {
      text = text.replaceAll(RegExp('[${entry.value}]'), entry.key);
    }
    return text;
  }

  /// Vietnamese vowels folded onto the letter they are built from, so typing
  /// `vinh long` finds `Vĩnh Long`.
  static const _accents = {
    'a': 'àáạảãâầấậẩẫăằắặẳẵ',
    'e': 'èéẹẻẽêềếệểễ',
    'i': 'ìíịỉĩ',
    'o': 'òóọỏõôồốộổỗơờớợởỡ',
    'u': 'ùúụủũưừứựửữ',
    'y': 'ỳýỵỷỹ',
    'd': 'đ',
  };
}
