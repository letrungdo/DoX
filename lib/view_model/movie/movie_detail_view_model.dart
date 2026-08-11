import 'dart:async';

import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:do_x/model/movie_model.dart';
import 'package:do_x/screen/movie/movie_thumbnail_track.dart';
import 'package:do_x/services/movie_library_service.dart';
import 'package:do_x/services/movie_service.dart';
import 'package:do_x/utils/logger.dart';
import 'package:do_x/view_model/core/core_view_model.dart';
import 'package:flutter/material.dart';

class MovieDetailViewModel extends CoreViewModel {
  MovieDetailViewModel();

  MovieDetail? _detail;
  MovieDetail? get detail => _detail;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  bool _isLoadingStream = false;
  bool get isLoadingStream => _isLoadingStream;

  MovieEpisodeServer? _selectedServer;
  MovieEpisodeServer? get selectedServer => _selectedServer;

  MovieEpisode? _selectedEpisode;
  MovieEpisode? get selectedEpisode => _selectedEpisode;

  List<MovieStreamVariant> _availableQualities = const [];
  List<MovieStreamVariant> get availableQualities => _availableQualities;

  String _selectedQuality = 'Auto';
  String get selectedQuality => _selectedQuality;

  String? _masterStreamUrl;
  String? get masterStreamUrl => _masterStreamUrl;

  bool _isFavorite = false;
  bool get isFavorite => _isFavorite;

  MovieLibraryState? _libraryState;
  MovieLibraryState? get libraryState => _libraryState;

  bool _isUpdatingFavorite = false;
  bool get isUpdatingFavorite => _isUpdatingFavorite;

  bool _isTransitioningEpisode = false;
  bool get isTransitioningEpisode => _isTransitioningEpisode;

  ThumbnailTrack? _thumbnailTrack;
  ThumbnailTrack? get thumbnailTrack => _thumbnailTrack;

  int _detailGeneration = 0;
  int _thumbnailGeneration = 0;
  int _qualityGeneration = 0;

  Future<void>? _libraryStateFuture;
  final _cancelToken = CancelToken();
  bool _hasRecordedWatch = false;

  @override
  void dispose() {
    _cancelToken.cancel();
    super.dispose();
  }

  Future<void> init(
    String movieUrl,
    String movieId, {
    Movie? initialMovie,
  }) async {
    _isLoading = true;
    notifyListenersSafe();
    await Future.wait([
      loadDetail(
        movieUrl,
        movieId,
        initialMovie: initialMovie,
        showLoading: false,
      ),
      loadLibraryState(movieId),
    ]);
    _isLoading = false;
    notifyListenersSafe();
  }

  Future<void> loadDetail(
    String movieUrl,
    String movieId, {
    Movie? initialMovie,
    bool showLoading = true,
    bool force = false,
  }) async {
    if (!force && _detail != null && _detail!.id == movieId) {
      if (showLoading) {
        _isLoading = false;
        notifyListenersSafe();
      }
      return;
    }

    final generation = ++_detailGeneration;
    if (showLoading) {
      _isLoading = true;
      notifyListenersSafe();
    }

    final detail = await movieService.getMovieDetail(
      movieUrl,
      movieId,
      cancelToken: _cancelToken,
    );

    if (isDispose || generation != _detailGeneration) return;

    await _libraryStateFuture;

    _detail = detail;
    _isLoading = false;
    _masterStreamUrl = detail?.streamUrl;
    _isLoadingStream = (detail?.streamUrl ?? '').isNotEmpty;
    _thumbnailTrack = null;

    _applyLibraryStateToSelection();
    notifyListenersSafe();

    final thumbnailTrackUrl = detail?.thumbnailTrackUrl;
    if (thumbnailTrackUrl != null && thumbnailTrackUrl.isNotEmpty) {
      unawaited(_loadThumbnailTrack(thumbnailTrackUrl, generation));
    }
  }

  void _applyLibraryStateToSelection() {
    final detail = _detail;
    if (detail == null || detail.servers.isEmpty) return;

    if (_selectedServer != null) {
      final matchingServer = detail.servers
          .cast<MovieEpisodeServer?>()
          .firstWhere(
            (s) => s?.name == _selectedServer!.name,
            orElse: () => null,
          );
      if (matchingServer != null) {
        _selectedServer = matchingServer;
        if (_selectedEpisode != null) {
          _selectedEpisode = matchingServer.episodes
              .cast<MovieEpisode?>()
              .firstWhere(
                (e) => e?.name == _selectedEpisode!.name,
                orElse: () => matchingServer.episodes.firstOrNull,
              );
        }
        return;
      }
    }

    final lastServerName = _libraryState?.lastServerName;
    final lastEpisodeName = _libraryState?.lastEpisodeName;

    if (lastServerName != null) {
      _selectedServer = detail.servers.firstWhere(
        (s) => s.name == lastServerName,
        orElse: () => detail.servers.first,
      );
    } else {
      _selectedServer = detail.servers.first;
    }

    if (_selectedServer!.episodes.isNotEmpty) {
      if (lastEpisodeName != null) {
        _selectedEpisode = _selectedServer!.episodes.firstWhere(
          (e) => e.name == lastEpisodeName,
          orElse: () => _selectedServer!.episodes.first,
        );
      } else {
        _selectedEpisode = _selectedServer!.episodes.first;
      }
    }
  }

  Future<void> loadLibraryState(String movieId) async {
    _libraryStateFuture = () async {
      try {
        final state = await movieLibraryService.getState(movieId);
        if (isDispose) return;
        _isFavorite = state.isFavorite;
        _libraryState = state;

        if (_detail != null) {
          _applyLibraryStateToSelection();
        }
        notifyListenersSafe();
      } catch (error, stackTrace) {
        logger.e(
          'MovieDetailViewModel: load library state failed',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }();
    return _libraryStateFuture;
  }

  Future<void> _loadThumbnailTrack(
    String trackUrl,
    int detailGeneration,
  ) async {
    final generation = ++_thumbnailGeneration;
    try {
      final response = await Dio().get<String>(
        trackUrl,
        options: Options(
          responseType: ResponseType.plain,
          headers: {
            'Referer': '${movieService.baseUrl}/',
            'User-Agent':
                'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
                'AppleWebKit/537.36 Chrome/120 Safari/537.36',
          },
        ),
      );
      final track = ThumbnailTrack.parse(trackUrl, response.data ?? '');
      if (isDispose ||
          generation != _thumbnailGeneration ||
          detailGeneration != _detailGeneration ||
          track == null) {
        return;
      }
      _thumbnailTrack = track;
      notifyListenersSafe();

      if (context.mounted) {
        unawaited(
          precacheImage(
            NetworkImage(
              track.spriteUrl,
              headers: {'Referer': '${movieService.baseUrl}/'},
            ),
            context,
          ).catchError((_) {}),
        );
      }
    } catch (error, stackTrace) {
      logger.e(
        'MovieDetailViewModel: thumbnail track unavailable',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<String?> getStreamUrlForMaster(String masterUrl) async {
    final generation = ++_qualityGeneration;
    _masterStreamUrl = masterUrl;
    _selectedQuality = 'Auto';
    _availableQualities = const [];

    // Fetch variants in the background.
    unawaited(() async {
      try {
        final variants = await movieService.getStreamVariants(masterUrl);
        if (isDispose ||
            generation != _qualityGeneration ||
            masterUrl != _masterStreamUrl) {
          return;
        }
        _availableQualities = variants;
        notifyListenersSafe();
      } catch (_) {}
    }());

    return masterUrl;
  }

  String? qualityUrlFor(String quality) {
    final masterUrl = _masterStreamUrl;
    if (masterUrl == null) return null;
    if (quality == 'Auto') return masterUrl;
    for (final variant in _availableQualities) {
      if (variant.label == quality) return variant.url;
    }
    return null;
  }

  void setSelectedQuality(String quality) {
    _selectedQuality = quality;
    notifyListenersSafe();
  }

  Movie get libraryMovie {
    // This is a bit tricky, maybe pass them to init
    return Movie(
      id: _detail?.id ?? '',
      title: _detail?.title ?? '',
      url: _detail?.url ?? '',
      poster: _detail?.poster ?? '',
      description: _detail?.description,
    );
  }

  Movie getLibraryMovie(String movieId, String movieUrl, Movie? initialMovie) {
    final detail = _detail;
    final title = detail?.title.isNotEmpty == true
        ? detail!.title
        : initialMovie?.title ?? '';
    final poster = detail?.poster.isNotEmpty == true
        ? detail!.poster
        : initialMovie?.poster ?? '';
    final description = detail?.description.isNotEmpty == true
        ? detail!.description
        : initialMovie?.description;
    return Movie(
      id: movieId,
      title: title,
      url: movieUrl,
      poster: poster,
      description: description,
    );
  }

  Future<void> recordWatched(
    Movie movie, {
    String? episodeName,
    String? serverName,
    int? positionSeconds,
    bool force = false,
  }) async {
    final currentHistory = _libraryState?.watchedAt;
    final isNewWatch = currentHistory == null;
    final pos = positionSeconds ?? 0;

    if (isNewWatch && pos < 20 && !force) {
      return;
    }

    if (_hasRecordedWatch && !force && positionSeconds == null) return;
    _hasRecordedWatch = true;

    try {
      await movieLibraryService.markWatched(
        movie,
        episodeName: episodeName ?? _selectedEpisode?.name,
        serverName: serverName ?? _selectedServer?.name,
        positionSeconds: pos,
      );
    } catch (error, stackTrace) {
      _hasRecordedWatch = false;
      logger.e(
        'MovieDetailViewModel: mark watched failed',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> toggleFavorite(Movie movie) async {
    if (_isUpdatingFavorite) return;
    final nextValue = !_isFavorite;
    _isUpdatingFavorite = true;
    notifyListenersSafe();
    try {
      await movieLibraryService.setFavorite(movie, nextValue);
      _isFavorite = nextValue;
    } catch (error, stackTrace) {
      logger.e(
        'MovieDetailViewModel: update favorite failed',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    } finally {
      _isUpdatingFavorite = false;
      notifyListenersSafe();
    }
  }

  Future<String?> prepareEpisode(
    MovieEpisode episode,
    String movieId,
    String movieUrl,
  ) async {
    _isTransitioningEpisode = true;
    _selectedEpisode = episode;
    _isLoadingStream = true;
    notifyListenersSafe();

    try {
      String? streamUrl = episode.m3u8Url;

      if (streamUrl == null && _selectedServer != null) {
        final match = RegExp(r'Server (\d+)').firstMatch(_selectedServer!.name);
        if (match != null) {
          final serverIndex = int.tryParse(match.group(1)!);
          if (serverIndex != null) {
            streamUrl = await movieService.getStreamUrl(
              movieId,
              movieUrl: movieUrl,
              server: serverIndex,
              cancelToken: _cancelToken,
            );
          }
        }
      }
      return streamUrl;
    } finally {
      _isTransitioningEpisode = false;
      notifyListenersSafe();
    }
  }

  void switchServer(MovieEpisodeServer server) {
    final currentEpisodeName = _selectedEpisode?.name;
    _selectedServer = server;
    if (server.episodes.isNotEmpty) {
      _selectedEpisode = server.episodes.firstWhere(
        (e) => e.name == currentEpisodeName,
        orElse: () => server.episodes.first,
      );
    }
    notifyListenersSafe();
  }

  bool get hasNextEpisode {
    final server = _selectedServer;
    final episode = _selectedEpisode;
    if (server == null || episode == null) return false;
    final index = server.episodes.indexOf(episode);
    return index >= 0 && index < server.episodes.length - 1;
  }

  bool get hasPreviousEpisode {
    final server = _selectedServer;
    final episode = _selectedEpisode;
    if (server == null || episode == null) return false;
    final index = server.episodes.indexOf(episode);
    return index > 0;
  }

  MovieEpisode? get nextEpisode {
    final server = _selectedServer;
    final episode = _selectedEpisode;
    if (server == null || episode == null) return null;
    final index = server.episodes.indexOf(episode);
    if (index >= 0 && index < server.episodes.length - 1) {
      return server.episodes[index + 1];
    }
    return null;
  }

  MovieEpisode? get previousEpisode {
    final server = _selectedServer;
    final episode = _selectedEpisode;
    if (server == null || episode == null) return null;
    final index = server.episodes.indexOf(episode);
    if (index > 0) {
      return server.episodes[index - 1];
    }
    return null;
  }

  void setStreamLoading(bool value) {
    _isLoadingStream = value;
    notifyListenersSafe();
  }

  void setTransitioningEpisode(bool value) {
    _isTransitioningEpisode = value;
    notifyListenersSafe();
  }
}
