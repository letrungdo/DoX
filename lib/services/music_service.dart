import 'dart:async';

import 'package:dio/dio.dart';
import 'package:do_x/constants/env.dart';
import 'package:do_x/model/music_shelf.dart';
import 'package:do_x/model/music_track.dart';
import 'package:do_x/services/music_auth_service.dart';
import 'package:do_x/services/music_web_session.dart';
import 'package:do_x/utils/logger.dart';

/// Thrown when the service refused a write, with the status it refused it
/// with — the music page has no use for the number, but a log does.
class MusicRequestFailed implements Exception {
  const MusicRequestFailed(this.status);

  final int status;

  @override
  String toString() => 'MusicRequestFailed(HTTP $status)';
}

/// Thrown by an endpoint that only answers for a signed-in account. The music
/// page turns it into an invitation to sign in, which is the one thing that
/// makes the call work.
class MusicSignInRequired implements Exception {
  const MusicSignInRequired();
}

class MusicService {
  MusicService() {
    // Likes belong to the account that fetched them, so a sign-out has to take
    // them with it or the next account inherits the wrong hearts.
    musicAuth.addListener(() {
      if (!musicAuth.isSignedIn) {
        _localLikedIds.clear();
        unawaited(musicWebSession.reset());
      }
    });
  }

  static const String _clientId = MusicAuthService.clientId;
  static const String _baseUrl = 'https://api-v2.${Envs.musicApiDomain}';

  final _dio =
      Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 20),
            headers: {
              'User-Agent':
                  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
              'Accept': 'application/json',
              // The API only ever sees requests from its own web player, and
              // answers some of them by where they claim to come from.
              'Origin': 'https://${Envs.musicApiDomain}',
              'Referer': 'https://${Envs.musicApiDomain}/',
            },
          ),
        )
        ..interceptors.add(
          // Read per request rather than baked into the options: the token arrives
          // when the user signs in, long after this client was built.
          InterceptorsWrapper(
            onRequest: (options, handler) {
              final account = musicAuth.account;
              if (account != null) {
                options.headers['Authorization'] = account.authorizationHeader;
              }
              handler.next(options);
            },
          ),
        );

  final Set<String> _localLikedIds = {};

  bool isTrackLiked(String trackId) => _localLikedIds.contains(trackId);

  /// Likes or unlikes [track] for the signed-in account.
  ///
  /// The local set is only updated once the service has accepted the change: a
  /// heart that fills in on a request that failed is a lie the user finds out
  /// about on the next refresh.
  /// Likes or unlikes [track] for the signed-in account.
  ///
  /// Sent from the web view the user signed in with, because the service's bot
  /// protection answers `403` to a like sent by an HTTP client of ours — see
  /// [MusicWebSession]. Plain HTTP stays as the way back for a platform with
  /// no web view, where the delete still goes through.
  ///
  /// The local set is only updated once the service has accepted the change: a
  /// heart that fills in on a request that failed is a lie the user finds out
  /// about on the next refresh.
  Future<void> toggleLikeTrack(MusicTrack track) async {
    final userId = musicAuth.account?.userId;
    if (userId == null) throw const MusicSignInRequired();

    final like = !_localLikedIds.contains(track.id);
    final method = like ? 'PUT' : 'DELETE';
    final url =
        '$_baseUrl/users/$userId/track_likes/${track.id}'
        '?client_id=$_clientId';

    final status = await musicWebSession.send(method: method, url: url);
    if (status == null) {
      await _writeLikeOverHttp(userId, track.id, like: like);
    } else if (status == 401) {
      throw const MusicSignInRequired();
    } else if (status < 200 || status >= 300) {
      throw MusicRequestFailed(status);
    }

    if (like) {
      _localLikedIds.add(track.id);
    } else {
      _localLikedIds.remove(track.id);
    }
  }

  Future<void> _writeLikeOverHttp(
    String userId,
    String trackId, {
    required bool like,
  }) async {
    final url = '$_baseUrl/users/$userId/track_likes/$trackId';
    final query = {'client_id': _clientId};
    try {
      if (like) {
        // An empty body, declared as one: a `put` with no data at all sends
        // neither a body nor a length, and is refused for it.
        await _dio.put(
          url,
          data: '',
          queryParameters: query,
          options: Options(headers: {Headers.contentLengthHeader: 0}),
        );
      } else {
        await _dio.delete(url, queryParameters: query);
      }
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      // A token the service no longer accepts is not a failed like: the one
      // thing that fixes it is signing in again, so say so.
      if (status == 401) throw const MusicSignInRequired();
      logger.e(
        'MusicService like refused with HTTP $status: '
        '${_briefly(e.response?.data)}',
        error: e,
        stackTrace: e.stackTrace,
      );
      rethrow;
    }
  }

  /// Enough of a response body to tell one refusal from another, without
  /// filling the log with a page of HTML.
  String _briefly(Object? body) {
    final text = body?.toString() ?? '';
    return text.length <= 300 ? text : '${text.substring(0, 300)}…';
  }

  Future<List<MusicTrack>> getLikedTracks() async {
    final userId = musicAuth.account?.userId;
    if (userId == null) return [];
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_baseUrl/users/$userId/track_likes',
        queryParameters: {
          'client_id': _clientId,
          'limit': 30,
          'linked_partitioning': 1,
        },
      );

      final List<MusicTrack> tracks = [];
      final collection = response.data?['collection'];
      if (collection is List) {
        for (final item in collection) {
          final trackMap = item['track'];
          if (trackMap != null) {
            final track = _parseTrack(trackMap);
            if (track != null) {
              tracks.add(track);
              _localLikedIds.add(track.id);
            }
          }
        }
      }
      return tracks;
    } catch (e, st) {
      logger.e(
        'MusicService getLikedTracks API failure',
        error: e,
        stackTrace: st,
      );
      return [];
    }
  }

  Future<List<MusicTrack>> getHistoryTracks() async {
    if (!musicAuth.isSignedIn) return [];
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_baseUrl/me/play-history/tracks',
        queryParameters: {
          'client_id': _clientId,
          'limit': 30,
          'linked_partitioning': 1,
        },
      );

      final List<MusicTrack> tracks = [];
      final collection = response.data?['collection'];
      if (collection is List) {
        for (final item in collection) {
          final trackMap = item['track'];
          if (trackMap != null) {
            final track = _parseTrack(trackMap);
            if (track != null) tracks.add(track);
          }
        }
      }
      return tracks;
    } catch (e, st) {
      logger.e(
        'MusicService getHistoryTracks API failure',
        error: e,
        stackTrace: st,
      );
      return [];
    }
  }

  MusicTrack? _parseTrack(Map<String, dynamic> trackMap) {
    try {
      final id = trackMap['id']?.toString() ?? '';
      if (id.isEmpty) return null;

      final title = trackMap['title'] ?? 'Unknown Track';
      final username = trackMap['user']?['username'] ?? 'Independent Artist';

      String artwork =
          trackMap['artwork_url'] ?? trackMap['user']?['avatar_url'] ?? '';
      if (artwork.contains('-large.')) {
        artwork = artwork.replaceAll('-large.', '-t500x500.');
      }

      String streamUrl = '';
      final media = trackMap['media']?['transcodings'];
      if (media is List && media.isNotEmpty) {
        final progressiveTranscoding = media.firstWhere(
          (t) => t['format']?['protocol'] == 'progressive',
          orElse: () => media.first,
        );
        streamUrl = progressiveTranscoding['url'] ?? '';
      }

      if (streamUrl.isEmpty) return null;

      return MusicTrack(
        id: id,
        title: title,
        artist: username,
        artworkUrl: artwork,
        streamUrl: streamUrl,
        duration: Duration(milliseconds: trackMap['duration'] ?? 0),
        likesCount:
            trackMap['likes_count'] ?? trackMap['favoritings_count'] ?? 0,
        repostsCount: trackMap['reposts_count'] ?? 0,
      );
    } catch (e) {
      return null;
    }
  }

  Future<String> resolvePlayableStream(String transcodingUrl) async {
    if (transcodingUrl.isEmpty) return '';
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        transcodingUrl,
        queryParameters: {'client_id': _clientId},
      );
      return response.data?['url'] ?? '';
    } catch (e, st) {
      logger.e(
        'MusicService resolvePlayableStream failed',
        error: e,
        stackTrace: st,
      );
      return '';
    }
  }

  /// The Discover tab, as the service lays it out: a row per selection, each
  /// with the title it comes with ("More of what you like", "Trending by
  /// genre", …). Which rows arrive depends on the account and on the day,
  /// which is the point — the page no longer hard-codes two of them.
  ///
  /// A selection holds playlists, and a playlist holds nothing but track ids,
  /// so the ids from every row are collected and fetched in one go. A row
  /// whose playlists carry no ids at all — "Recently Played" sends only a
  /// track count — is left out rather than shown empty.
  Future<List<MusicShelf>> getDiscoverShelves({
    int limit = 10,
    int tracksPerShelf = 20,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_baseUrl/mixed-selections',
        queryParameters: {
          'client_id': _clientId,
          'limit': limit,
          'offset': 0,
          'linked_partitioning': 1,
        },
      );

      final selections = response.data?['collection'];
      if (selections is! List) return [];

      final idsByShelf = <String, List<String>>{};
      for (final selection in selections) {
        final title = selection['title']?.toString() ?? '';
        if (title.isEmpty) continue;
        final items = selection['items']?['collection'];
        if (items is! List) continue;

        final ids = <String>[];
        for (final item in items) {
          for (final track in (item['tracks'] as List?) ?? const []) {
            final id = track['id']?.toString();
            if (id != null && id.isNotEmpty && !ids.contains(id)) ids.add(id);
            if (ids.length >= tracksPerShelf) break;
          }
          if (ids.length >= tracksPerShelf) break;
        }
        if (ids.isNotEmpty) idsByShelf[title] = ids;
      }

      // One fetch for every row: the rows overlap, and a request per row would
      // be a dozen of them for a screen the user has not scrolled yet.
      final tracksById = await _fetchTracksByIds(
        {for (final ids in idsByShelf.values) ...ids}.toList(),
      );

      final shelves = <MusicShelf>[];
      for (final entry in idsByShelf.entries) {
        final tracks = entry.value
            .map((id) => tracksById[id])
            .nonNulls
            .toList();
        if (tracks.isNotEmpty) {
          shelves.add(MusicShelf(title: entry.key, tracks: tracks));
        }
      }
      return shelves;
    } catch (e, st) {
      logger.e(
        'MusicService getDiscoverShelves failed',
        error: e,
        stackTrace: st,
      );
      return [];
    }
  }

  /// Turns track ids into tracks, in batches the endpoint accepts.
  Future<Map<String, MusicTrack>> _fetchTracksByIds(List<String> ids) async {
    const batchSize = 50;
    final result = <String, MusicTrack>{};
    for (var start = 0; start < ids.length; start += batchSize) {
      final batch = ids.sublist(
        start,
        start + batchSize > ids.length ? ids.length : start + batchSize,
      );
      try {
        final response = await _dio.get<List<dynamic>>(
          '$_baseUrl/tracks',
          queryParameters: {'ids': batch.join(','), 'client_id': _clientId},
        );
        for (final item in response.data ?? const []) {
          final track = _parseTrack(item);
          if (track != null) result[track.id] = track;
        }
      } catch (e, st) {
        logger.e(
          'MusicService _fetchTracksByIds failed',
          error: e,
          stackTrace: st,
        );
      }
    }
    return result;
  }

  /// Seeds the hearts from the account itself, so a track already liked shows
  /// as liked on the Discover tab without the likes tab ever being opened.
  Future<void> loadLikedTrackIds({int limit = 200}) async {
    if (!musicAuth.isSignedIn) return;
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_baseUrl/me/track_likes/ids',
        queryParameters: {'client_id': _clientId, 'limit': limit},
      );
      final ids = response.data?['collection'];
      if (ids is List) {
        _localLikedIds.addAll(ids.map((id) => id.toString()));
      }
    } catch (e, st) {
      logger.e(
        'MusicService loadLikedTrackIds failed',
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<List<MusicTrack>> searchTracks(String query) async {
    try {
      final searchWord = query.isEmpty ? 'Remix Việt Nam' : query;
      final response = await _dio.get<Map<String, dynamic>>(
        '$_baseUrl/search',
        queryParameters: {
          'q': searchWord,
          'client_id': _clientId,
          'limit': 30,
          'offset': 0,
          'linked_partitioning': 1,
        },
      );

      final List<MusicTrack> tracks = [];
      final collection = response.data?['collection'];
      if (collection is List) {
        for (final item in collection) {
          final track = _parseTrack(item);
          if (track != null) tracks.add(track);
        }
      }

      tracks.sort((a, b) => b.likesCount.compareTo(a.likesCount));
      return tracks;
    } catch (e, st) {
      logger.e(
        'MusicService searchTracks API failure',
        error: e,
        stackTrace: st,
      );
      return [];
    }
  }
}

final musicService = MusicService();
