import 'package:dio/dio.dart';
import 'package:do_x/constants/env.dart';
import 'package:do_x/model/music_track.dart';
import 'package:do_x/services/music_auth_service.dart';
import 'package:do_x/utils/logger.dart';

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
      if (!musicAuth.isSignedIn) _localLikedIds.clear();
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
  Future<void> toggleLikeTrack(MusicTrack track) async {
    final userId = musicAuth.account?.userId;
    if (userId == null) throw const MusicSignInRequired();

    final isLiked = _localLikedIds.contains(track.id);
    final url = '$_baseUrl/users/$userId/track_likes/${track.id}';

    if (isLiked) {
      await _dio.delete(url, queryParameters: {'client_id': _clientId});
      _localLikedIds.remove(track.id);
    } else {
      await _dio.put(url, queryParameters: {'client_id': _clientId});
      _localLikedIds.add(track.id);
    }
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

  Future<List<MusicTrack>> getTrendingTracks() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_baseUrl/mixed-selections',
        queryParameters: {
          'client_id': _clientId,
          'limit': 15,
          'offset': 0,
          'linked_partitioning': 1,
        },
      );

      final List<MusicTrack> tracks = [];
      final selections = response.data?['collection'];
      if (selections is List) {
        for (final selection in selections) {
          final items = selection['items']?['collection'];
          if (items is List) {
            for (final item in items) {
              if (item['kind'] == 'track') {
                final track = _parseTrack(item);
                if (track != null) tracks.add(track);
              }
            }
          }
        }
      }

      if (tracks.isEmpty) {
        return searchTracks('Remix Hot');
      }

      return tracks;
    } catch (e, st) {
      logger.e(
        'MusicService getTrendingTracks failed',
        error: e,
        stackTrace: st,
      );
      return searchTracks('Lofi Chill');
    }
  }

  Future<List<MusicTrack>> getMoreOfWhatYouLike() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_baseUrl/search',
        queryParameters: {
          'q': 'VinaHouse Electro EDM',
          'client_id': _clientId,
          'limit': 15,
          'offset': 0,
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
      return tracks;
    } catch (e, st) {
      logger.e(
        'MusicService getMoreOfWhatYouLike failed',
        error: e,
        stackTrace: st,
      );
      return [];
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
