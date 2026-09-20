import 'package:dio/dio.dart';
import 'package:do_x/model/tv_channel.dart';
import 'package:do_x/services/storage_service.dart';
import 'package:do_x/utils/logger.dart';
import 'package:flutter/foundation.dart';

/// Loads the list of Vietnamese live channels.
///
/// The catalogue is the community-maintained iptv-org playlist: one M3U file
/// per country, rebuilt daily, holding the stream URL and the logo of every
/// channel broadcasting there. Nothing is proxied through us — the app reads
/// the playlist and hands each URL straight to the platform player.
class _TvChannelService {
  /// The Vietnam playlist. Country file rather than the full index: the index
  /// is tens of megabytes and every entry outside Vietnam would be dropped
  /// again on this side.
  static const playlistUrl = 'https://iptv-org.github.io/iptv/countries/vn.m3u';

  /// How long a downloaded playlist is served before it is fetched again. The
  /// upstream list is rebuilt daily, and a stream URL that rotates faster than
  /// that fails at playback anyway, where pull-to-refresh is one gesture away.
  static const cacheTtl = Duration(hours: 12);

  final _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      // The playlist is plain text; without this Dio tries to decode it as JSON.
      responseType: ResponseType.plain,
    ),
  );

  List<TvChannel>? _channels;

  /// The channels already in memory, if the service has loaded any this run.
  List<TvChannel>? get cachedChannels => _channels;

  /// The channel list, from memory, from the stored copy, or from the network —
  /// in that order, unless [forceRefresh] sends it straight to the network.
  ///
  /// Throws only when there is nothing at all to show: a failed refresh with a
  /// stored copy behind it keeps serving that copy.
  Future<List<TvChannel>> getChannels({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final inMemory = _channels;
      if (inMemory != null) return inMemory;

      final stored = _readStoredPlaylist();
      if (stored != null) {
        final channels = parsePlaylist(stored);
        if (channels.isNotEmpty) {
          _channels = channels;
          return channels;
        }
      }
    }

    try {
      final response = await _dio.get<String>(playlistUrl);
      final body = response.data ?? '';
      final channels = parsePlaylist(body);
      if (channels.isEmpty) throw const FormatException('Empty TV playlist');
      _channels = channels;
      await storageService.setTvPlaylist(body);
      return channels;
    } catch (e, st) {
      logger.e('TvChannelService fetch failed', error: e, stackTrace: st);
      // Whatever is on disk beats an error screen: a day-old channel list still
      // plays, and the user asked to watch television, not to see a refresh fail.
      final fallback = _channels ?? _parseStoredPlaylist(ignoreExpiry: true);
      if (fallback != null && fallback.isNotEmpty) {
        _channels = fallback;
        return fallback;
      }
      rethrow;
    }
  }

  /// The stored playlist while it is still fresh enough to serve.
  String? _readStoredPlaylist() {
    final savedAt = storageService.getTvPlaylistSavedAt();
    if (savedAt == null) return null;
    if (DateTime.now().difference(savedAt) > cacheTtl) return null;
    return storageService.getTvPlaylist();
  }

  List<TvChannel>? _parseStoredPlaylist({bool ignoreExpiry = false}) {
    final raw = ignoreExpiry
        ? storageService.getTvPlaylist()
        : _readStoredPlaylist();
    if (raw == null || raw.isEmpty) return null;
    return parsePlaylist(raw);
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
  /// Public so the parser can be tested without a network round trip.
  List<TvChannel> parsePlaylist(String content) {
    final channels = <TvChannel>[];
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

      final logo = attributes['tvg-logo'];
      final group = attributes['group-title'] ?? '';
      channels.add(
        TvChannel(
          id: attributes['tvg-id']?.isNotEmpty == true
              ? attributes['tvg-id']!
              : line,
          name: _cleanName(name).isEmpty ? line : _cleanName(name),
          url: line,
          logo: logo == null || logo.isEmpty ? null : logo,
          groups: group
              .split(';')
              .map((value) => value.trim())
              .where((value) => value.isNotEmpty)
              .toList(),
          quality: _qualityExp.firstMatch(name)?.group(1),
          isGeoBlocked: name.contains('[Geo-blocked]'),
          isIntermittent: name.contains('[Not 24/7]'),
          headers: Map.unmodifiable(headers),
        ),
      );
    }

    channels.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return channels;
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
