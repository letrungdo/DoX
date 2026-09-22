import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:do_x/constants/env.dart';
import 'package:do_x/model/tv_channel.dart';
import 'package:do_x/services/storage_service.dart';
import 'package:do_x/services/supabase_service.dart';
import 'package:do_x/utils/logger.dart';
import 'package:flutter/foundation.dart';

/// Loads the list of live channels of one country.
///
/// Most countries come straight from iptv-org: one M3U file each, rebuilt
/// daily, holding the stream URL and the logo of every channel broadcasting
/// there. Nothing is proxied through us — the app reads the playlist and
/// hands each URL to the platform player.
///
/// Vietnam is different, because its iptv-org file is thin and because the
/// Vietnamese playlists that are not thin are scraped rather than curated:
/// full of dead links, of entries that are not channels, and of the same
/// station listed half a dozen ways. Sorting that out is work, and the part
/// that matters most — whether a stream is really playing — a phone can only
/// learn by making someone sit through a channel that never starts. So it
/// happens every other day in `refresh-tv-channels`, and here Vietnam is a
/// read.
class _TvChannelService {
  /// The playlist of one country. Country file rather than the full index: the
  /// index is tens of megabytes and every entry outside the picked country
  /// would be dropped again on this side.
  static String countryPlaylistUrl(String countryCode) =>
      '${Envs.tvApiUrl}/iptv/countries/${countryCode.toLowerCase()}.m3u';

  /// The country whose list is read from our own table rather than from the
  /// catalogue.
  static const curatedCountryCode = 'vn';

  final _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      // The playlist is plain text; without this Dio tries to decode it as JSON.
      responseType: ResponseType.plain,
    ),
  );

  /// Channels by country code, for the countries visited this run.
  final _channels = <String, List<TvChannel>>{};

  /// The channel list of [countryCode], from memory if this run has already
  /// read it and from the network otherwise.
  ///
  /// The first read of a country in an app run always goes out, so that
  /// closing the app and opening it again is all anyone has to do to get the
  /// list as it stands — a television has no pull-to-refresh, and a list a
  /// day old there is a list of channels that have since moved.
  ///
  /// Throws only when there is nothing at all to show: a fetch that fails
  /// with a stored copy behind it serves that copy.
  Future<List<TvChannel>> getChannels(
    String countryCode, {
    bool forceRefresh = false,
  }) async {
    final code = countryCode.toLowerCase();
    if (!forceRefresh) {
      final inMemory = _channels[code];
      if (inMemory != null) return inMemory;
    }

    try {
      final fetched = await _fetch(code);
      final channels = parseChannels(fetched.body);
      if (channels.isEmpty) throw const FormatException('Empty TV playlist');
      _channels[code] = channels;
      if (fetched.isWorthKeeping) {
        await storageService.setTvPlaylist(code, fetched.body);
      }
      return channels;
    } catch (e, st) {
      logger.e('TvChannelService fetch failed', error: e, stackTrace: st);
      // A country the catalogue lists but the playlist repository has no file
      // for is not a failure — it is a country with nothing on air, and the
      // grid says so rather than offering a retry that cannot help.
      if (e is DioException && e.response?.statusCode == 404) {
        return _channels[code] = const [];
      }
      // Whatever is on disk beats an error screen: a day-old channel list still
      // plays, and the user asked to watch television, not to see a refresh fail.
      final fallback = _channels[code] ?? _parseStoredPlaylist(code);
      if (fallback != null && fallback.isNotEmpty) {
        return _channels[code] = fallback;
      }
      rethrow;
    }
  }

  /// The last list of [countryCode] that reached the app, for the page to
  /// draw while this run's fetch is still out, or null when there is none.
  List<TvChannel>? storedChannels(String countryCode) {
    final code = countryCode.toLowerCase();
    return _channels[code] ?? _parseStoredPlaylist(code);
  }

  /// The last list of [countryCode] that reached the app, which is what it
  /// falls back on when this run's fetch does not.
  ///
  /// It is kept without a lifetime of its own: it is never served while the
  /// network can be reached, and when it cannot, how old it is changes
  /// nothing — it is still the only television there is.
  List<TvChannel>? _parseStoredPlaylist(String countryCode) {
    final raw = storageService.getTvPlaylist(countryCode);
    if (raw == null || raw.isEmpty) return null;
    return parseChannels(raw);
  }

  /// The channel list [countryCode] should be shown, and whether it is the
  /// one worth keeping.
  ///
  /// Vietnam's comes from our table. The catalogue stays behind it as a way
  /// out: the page could always show something without us, and a database
  /// that cannot be reached is no reason for that to stop. What comes back
  /// that way is not stored, though — it is the thin, unchecked list, and
  /// caching it would keep it on screen for half a day after the table came
  /// back.
  Future<({String body, bool isWorthKeeping})> _fetch(
    String countryCode,
  ) async {
    if (countryCode == curatedCountryCode) {
      try {
        return (
          body: await _fetchCuratedChannels(countryCode),
          isWorthKeeping: true,
        );
      } catch (e, st) {
        logger.d(
          'TvChannelService curated list failed',
          error: e,
          stackTrace: st,
        );
      }
    }
    final response = await _dio.get<String>(countryPlaylistUrl(countryCode));
    return (
      body: response.data ?? '',
      isWorthKeeping: countryCode != curatedCountryCode,
    );
  }

  /// The rows `refresh-tv-channels` last wrote, as the JSON they are stored
  /// and parsed as.
  Future<String> _fetchCuratedChannels(String countryCode) async {
    final rows = await supabase
        .from('tv_channels')
        .select()
        .eq('country_code', countryCode.toUpperCase())
        // The order is worked out when the list is built, so the grid draws
        // the rows in the order they arrive.
        .order('sort_order', ascending: true);
    if (rows.isEmpty) throw const FormatException('Empty TV channel table');
    return jsonEncode(rows);
  }

  /// The channels a stored or freshly fetched body holds.
  ///
  /// Two shapes reach this: the JSON rows of our own table, and the M3U of a
  /// country the catalogue serves. They are told apart by what a JSON array
  /// starts with, which no playlist ever does.
  ///
  /// Public so a stored copy of either shape can be tested.
  List<TvChannel> parseChannels(String body) {
    final trimmed = body.trimLeft();
    if (!trimmed.startsWith('[')) return parsePlaylist(body);
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is! List) return const [];
      return [
        for (final row in decoded)
          if (row is Map<String, dynamic>) TvChannel.fromRow(row),
      ];
    } on FormatException catch (e, st) {
      logger.e('TvChannelService row parse failed', error: e, stackTrace: st);
      return const [];
    }
  }

  /// Attributes on an `#EXTINF` line: `tvg-logo="…"`, `group-title="…"`, …
  static final _attributeExp = RegExp(r'([\w-]+)="([^"]*)"');

  /// The `(1080p)` / `(720p)` the playlist appends to a channel name.
  static final _qualityExp = RegExp(r'\((\d{3,4}p)\)');

  /// The `[Geo-blocked]` / `[Not 24/7]` markers, dropped from the name and kept
  /// as flags.
  static final _flagExp = RegExp(r'\[[^\]]*\]');

  /// Turns an M3U playlist into channels, skipping anything the platform player
  /// cannot open.
  ///
  /// A playlist lists the same station several times over — one line per
  /// mirror, and every one of them a link that can die on its own. They are
  /// folded into a single channel here, with the rest of the mirrors kept as
  /// the spares the player falls back on, rather than shown as a row each.
  ///
  /// Public so the parser can be tested without a network round trip.
  List<TvChannel> parsePlaylist(String content) {
    final drafts = <_ChannelDraft>[];
    final draftByKey = <String, _ChannelDraft>{};
    final seen = <String>{};

    Map<String, String> attributes = {};
    String name = '';
    var headers = <String, String>{};
    var inEntry = false;

    for (final rawLine in content.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      if (line.startsWith('#EXTINF:')) {
        attributes = {
          for (final match in _attributeExp.allMatches(line))
            match.group(1)!: match.group(2)!,
        };
        // The display name is whatever follows the last comma, after the
        // attributes — which may themselves contain commas (a user agent does).
        final comma = line.lastIndexOf(',');
        name = comma == -1 ? '' : line.substring(comma + 1).trim();
        headers = _headersFrom(attributes);
        inEntry = true;
        continue;
      }

      // Playback options VLC writes on their own line; the same two headers
      // some entries carry as attributes instead.
      if (line.startsWith('#EXTVLCOPT:')) {
        final option = line.substring('#EXTVLCOPT:'.length);
        final separator = option.indexOf('=');
        if (separator > 0 && inEntry) {
          final key = option.substring(0, separator).trim();
          final value = option.substring(separator + 1).trim();
          final header = _headerName(key);
          if (header != null && value.isNotEmpty) headers[header] = value;
        }
        continue;
      }

      if (line.startsWith('#')) continue;
      if (!inEntry) continue;

      inEntry = false;
      if (!_isPlayable(line)) continue;
      if (!seen.add(line)) continue;

      final tvgId = attributes['tvg-id'] ?? '';
      final cleanName = _cleanName(name).isEmpty ? line : _cleanName(name);

      // Two entries are the same station when the playlist gives them the
      // same `tvg-id`; without one, the name is all there is to go on.
      final key = tvgId.isNotEmpty
          ? 'id:$tvgId'
          : 'name:${TvChannel.normalizeName(cleanName)}';
      final existing = draftByKey[key];
      if (existing != null) {
        existing.urls.add(line);
        // A later entry may carry the logo the first one was missing.
        existing.logo ??= _logoOf(attributes);
        continue;
      }

      final group = attributes['group-title'] ?? '';
      final draft = _ChannelDraft(
        id: tvgId.isNotEmpty ? tvgId : line,
        name: cleanName,
        urls: [line],
        logo: _logoOf(attributes),
        groups: group
            .split(';')
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toList(),
        quality: _qualityExp.firstMatch(name)?.group(1),
        isGeoBlocked: name.contains('[Geo-blocked]'),
        isIntermittent: name.contains('[Not 24/7]'),
        headers: Map.unmodifiable(headers),
      );
      drafts.add(draft);
      draftByKey[key] = draft;
    }

    final channels = drafts.map((draft) => draft.build()).toList();
    channels.sort((a, b) => compareChannelNames(a.name, b.name));
    return channels;
  }

  String? _logoOf(Map<String, String> attributes) {
    final logo = attributes['tvg-logo'];
    return logo == null || logo.isEmpty ? null : logo;
  }

  /// Whether this platform's player can open [url] at all.
  ///
  /// Apple's player speaks HLS and nothing else, so a DASH manifest is a row
  /// that could only ever fail; ExoPlayer on Android plays both.
  bool _isPlayable(String url) {
    if (!url.startsWith('http')) return false;
    final isDash = url.split('?').first.toLowerCase().endsWith('.mpd');
    if (!isDash) return true;
    return !kIsWeb &&
        defaultTargetPlatform != TargetPlatform.iOS &&
        defaultTargetPlatform != TargetPlatform.macOS;
  }

  Map<String, String> _headersFrom(Map<String, String> attributes) {
    final headers = <String, String>{};
    for (final entry in attributes.entries) {
      final header = _headerName(entry.key);
      if (header != null && entry.value.isNotEmpty) {
        headers[header] = entry.value;
      }
    }
    return headers;
  }

  /// The HTTP header an M3U option name stands for, or null when it is one of
  /// the many options that says nothing about the request.
  String? _headerName(String key) => switch (key.toLowerCase()) {
    'http-referrer' || 'http-referer' => 'Referer',
    'http-user-agent' => 'User-Agent',
    'http-origin' => 'Origin',
    _ => null,
  };

  String _cleanName(String rawName) {
    return rawName
        .replaceAll(_flagExp, '')
        .replaceAll(_qualityExp, '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}

final tvChannelService = _TvChannelService();

/// Orders two channel names the way a viewer reads them, which means the
/// digits in them count as numbers: plain text ordering puts `VTV10` between
/// `VTV1` and `VTV2`, and the national channels come out shuffled.
///
/// What is compared is not the name as written but the name reduced to what
/// a viewer would say out loud. A playlist spells one family of channels
/// every which way — `Vinh Long TV 4` beside `Vĩnh Long 5` — and both the
/// accents and the stray `TV` would otherwise break the family apart: every
/// accented letter sorts after `z` in code unit order, which files
/// `Vĩnh Long 5` and `Đà Nẵng` past the end of the list, and the `TV` puts
/// whatever carries it after every number.
///
/// Public so the ordering can be tested on names alone.
int compareChannelNames(String first, String second) {
  final byReading = _compareText(_sortKey(first), _sortKey(second));
  if (byReading != 0) return byReading;
  // Two names that read the same still have to have an order between them.
  return _compareText(
    TvChannel.normalizeName(first),
    TvChannel.normalizeName(second),
  );
}

/// The words a channel name carries without them saying which channel it is,
/// so that `Vĩnh Long 5` and `Vinh Long TV 4` sort as one run of numbers.
final _sortNoiseExp = RegExp(r'\b(tv|kenh|channel|hd|sd|fhd|uhd|4k)\b');

String _sortKey(String name) => TvChannel.normalizeName(
  name,
).replaceAll(_sortNoiseExp, ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

int _compareText(String left, String right) {
  var i = 0;
  var j = 0;
  while (i < left.length && j < right.length) {
    if (_isDigit(left.codeUnitAt(i)) && _isDigit(right.codeUnitAt(j))) {
      var leftEnd = i;
      while (leftEnd < left.length && _isDigit(left.codeUnitAt(leftEnd))) {
        leftEnd++;
      }
      var rightEnd = j;
      while (rightEnd < right.length && _isDigit(right.codeUnitAt(rightEnd))) {
        rightEnd++;
      }

      // Leading zeros say nothing about the value, so `07` and `7` are the
      // same number and the longer run is only the bigger one after them.
      final leftNumber = _withoutLeadingZeros(left.substring(i, leftEnd));
      final rightNumber = _withoutLeadingZeros(right.substring(j, rightEnd));
      if (leftNumber.length != rightNumber.length) {
        return leftNumber.length - rightNumber.length;
      }
      final byNumber = leftNumber.compareTo(rightNumber);
      if (byNumber != 0) return byNumber;

      i = leftEnd;
      j = rightEnd;
      continue;
    }

    final byCharacter = left[i].compareTo(right[j]);
    if (byCharacter != 0) return byCharacter;
    i++;
    j++;
  }

  // One name ran out first: it is the shorter of two that read the same so
  // far, and shorter comes first.
  return (left.length - i) - (right.length - j);
}

bool _isDigit(int codeUnit) => codeUnit >= 0x30 && codeUnit <= 0x39;

String _withoutLeadingZeros(String digits) {
  final trimmed = digits.replaceFirst(RegExp(r'^0+'), '');
  return trimmed.isEmpty ? '0' : trimmed;
}

/// One channel while its mirrors are still being collected off the playlist.
class _ChannelDraft {
  _ChannelDraft({
    required this.id,
    required this.name,
    required this.urls,
    required this.logo,
    required this.groups,
    required this.quality,
    required this.isGeoBlocked,
    required this.isIntermittent,
    required this.headers,
  });

  final String id;
  final String name;
  final List<String> urls;
  String? logo;
  final List<String> groups;
  final String? quality;
  final bool isGeoBlocked;
  final bool isIntermittent;
  final Map<String, String> headers;

  TvChannel build() => TvChannel(
    id: id,
    name: name,
    urls: rankStreamUrls(urls),
    logo: logo,
    groups: groups,
    quality: quality,
    isGeoBlocked: isGeoBlocked,
    isIntermittent: isIntermittent,
    headers: headers,
  );
}

/// How many mirrors of one channel are worth carrying.
///
/// A viewer waiting on a dead link waits the whole of each attempt, so the
/// list is short enough that working down all of it still ends before they
/// give up on the channel themselves.
const maxStreamUrls = 4;

/// [urls] best first, deduplicated and cut to [maxStreamUrls].
///
/// The same order the scheduled refresh ranks Vietnam's mirrors by, so a channel
/// read off a playlist opens on the same kind of link as one read off our
/// table.
List<String> rankStreamUrls(Iterable<String> urls) {
  final ordered = {...urls}.toList();
  final ranked =
      [for (var i = 0; i < ordered.length; i++) (url: ordered[i], index: i)]
        ..sort((a, b) {
          final byHost = _streamRank(a.url) - _streamRank(b.url);
          if (byHost != 0) return byHost;
          final byRendition = _renditionRank(a.url) - _renditionRank(b.url);
          return byRendition != 0 ? byRendition : a.index - b.index;
        });
  return [for (final entry in ranked.take(maxStreamUrls)) entry.url];
}

/// How good a picture a link says it serves, lowest first.
///
/// A CDN often publishes one link per rendition beside the adaptive master —
/// `playlist1080p.m3u8` next to `playlist480p.m3u8`. All of them play, so
/// nothing else tells them apart, and the channel then opens on whichever
/// the playlist wrote first.
///
/// The master is left in the middle rather than on top: the player climbing
/// and falling with the line is the better stream in principle, but a master
/// lists its renditions smallest first, and a player that knows nothing
/// about the line yet starts on the first of them.
int _renditionRank(String url) {
  final named = RegExp(
    r"(\d{3,4})p(?![a-z0-9])",
    caseSensitive: false,
  ).firstMatch(url.split('?').first);
  if (named == null) return 1;
  return int.parse(named.group(1)!) >= 720 ? 0 : 2;
}

/// How much a link is worth trying, lowest first.
int _streamRank(String url) {
  final host = Uri.tryParse(url)?.host.toLowerCase();
  if (host == null || host.isEmpty) return 3;
  // A playlist committed to a repository is a copy of a link, taken on the
  // day someone ran the scraper; the origin it was copied from outlives it.
  if (host.endsWith('.github.io')) return 2;
  // `play.m3u8?vid=51` is a proxy that looks the channel up rather than a
  // stream, and it lasts as long as whoever runs it keeps paying.
  if (url.contains('?')) return 1;
  return 0;
}
