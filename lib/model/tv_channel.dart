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
    required this.urls,
    this.logo,
    this.groups = const [],
    this.quality,
    this.isGeoBlocked = false,
    this.isIntermittent = false,
    this.headers = const {},
  });

  /// One row of the `tv_channels` table.
  ///
  /// The run's list is already sorted, deduplicated and checked by then, so
  /// there is nothing to work out here — only the column names to read.
  factory TvChannel.fromRow(Map<String, dynamic> row) {
    final headers = row['headers'];
    final categories = row['categories'];
    final primary = row['url'] as String? ?? '';
    final spares = row['urls'];
    final urls = [
      // `url` is the link the checker last saw playing, so it leads whatever
      // order the column happens to be in.
      primary,
      if (spares is List)
        for (final spare in spares.whereType<String>())
          if (spare != primary) spare,
    ].where((url) => url.isNotEmpty).toList(growable: false);
    return TvChannel(
      id: row['slug'] as String? ?? primary,
      name: row['name'] as String? ?? '',
      urls: urls,
      logo: row['logo'] as String?,
      groups: categories is List
          ? categories.whereType<String>().toList()
          : const [],
      quality: row['quality'] as String?,
      isGeoBlocked: row['is_geo_blocked'] as bool? ?? false,
      isIntermittent: row['is_intermittent'] as bool? ?? false,
      headers: headers is Map
          ? {
              for (final entry in headers.entries)
                entry.key.toString(): entry.value.toString(),
            }
          : const {},
    );
  }

  /// `tvg-id` when the playlist has one, the stream URL otherwise — a playlist
  /// is free to repeat an empty id, so it can never be the key on its own.
  final String id;

  /// Channel name with the parenthesised quality and the bracketed flags
  /// already stripped off; those live in [quality], [isGeoBlocked] and
  /// [isIntermittent] instead.
  final String name;

  /// Every stream known for this channel, the one most likely to play first.
  ///
  /// A live link dies without warning and without telling anybody — the CDN
  /// stops serving segments and the picture simply never starts — so a
  /// channel carries its spares and the player works down them.
  final List<String> urls;

  /// The stream a channel is opened on, and the empty string for a channel
  /// with no link at all — which the sources this reads never produce, but
  /// which a caller must not have to prove before reading a URL.
  String get url => urls.isEmpty ? '' : urls.first;

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
  bool matches(String query) => matchesNormalized(normalizeName(query));

  /// [matches] for a query already put through [normalizeName], so a filter
  /// running down a whole playlist folds the query once rather than once per
  /// channel.
  bool matchesNormalized(String needle) {
    if (needle.isEmpty) return true;
    return searchKey.contains(needle);
  }

  /// [name] as [normalizeName] folds it, worked out on the first search and
  /// kept: the search box asks every channel on every keystroke.
  ///
  /// Kept beside the channel rather than in it, because a channel is a
  /// constant and a constant cannot carry a field that fills in later.
  String get searchKey => _searchKeys[this] ??= normalizeName(name);

  static final _searchKeys = Expando<String>('TvChannel.searchKey');

  /// [value] lowercased and stripped of its Vietnamese accents, so two
  /// playlists spelling one station differently still read as one name.
  static String normalizeName(String value) => _normalize(value);

  /// One pass over the text: every playlist entry goes through here while it
  /// is being read and sorted, and a replace per vowel family walked each
  /// name seven times over.
  static String _normalize(String value) {
    final text = value.toLowerCase().trim();
    StringBuffer? folded;
    for (var i = 0; i < text.length; i++) {
      final unit = text.codeUnitAt(i);
      // Plain ASCII has no accent to fold, and it is most of every name.
      final base = unit < 0x80 ? null : _foldedUnits[unit];
      if (base == null) {
        folded?.writeCharCode(unit);
        continue;
      }
      folded ??= StringBuffer(text.substring(0, i));
      folded.writeCharCode(base);
    }
    return folded?.toString() ?? text;
  }

  /// [_accents] turned round: each accented vowel's code unit to the code
  /// unit of the letter it is built from.
  static final Map<int, int> _foldedUnits = {
    for (final entry in _accents.entries)
      for (final unit in entry.value.codeUnits) unit: entry.key.codeUnitAt(0),
  };

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
