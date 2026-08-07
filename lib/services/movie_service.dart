import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:do_x/model/movie_model.dart';
import 'package:do_x/services/storage_service.dart';
import 'package:do_x/utils/logger.dart';
import 'package:html/parser.dart' as html_parser;

class MovieService {
  static final MovieService _instance = MovieService._internal();
  factory MovieService() => _instance;
  MovieService._internal() {
    _initDio();
  }

  late String? baseUrl;
  late Dio _dio;

  void _initDio() {
    baseUrl = storageService.getMovieBaseUrl();
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl ?? '',
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept-Language': 'vi-VN,vi;q=0.9,en-US;q=0.8,en;q=0.7',
        },
      ),
    );
  }

  /// Update base URL manually, re-initialize Dio, and discover config
  Future<void> updateBaseUrl(String newUrl) async {
    String formattedUrl = newUrl.trim();
    if (formattedUrl.isEmpty) {
      await storageService.setMovieBaseUrl('');
      _initDio();
      return;
    }
    if (formattedUrl.endsWith('/')) {
      formattedUrl = formattedUrl.substring(0, formattedUrl.length - 1);
    }
    await storageService.setMovieBaseUrl(formattedUrl);
    _initDio();
    await discoverConfig();
  }

  /// Discover Label and Categories from the current baseUrl
  Future<void> discoverConfig() async {
    if (baseUrl == null || baseUrl!.isEmpty) return;

    try {
      final response = await _dio.get('/');
      final htmlStr = response.data.toString();
      final document = html_parser.parse(htmlStr);

      // 1. Discover Label
      String? label = document
          .querySelector('meta[property="og:site_name"]')
          ?.attributes['content'];
      label ??= document.querySelector('title')?.text.split('|').first.trim();
      label ??= document.querySelector('title')?.text.split('-').first.trim();
      if (label != null && label.isNotEmpty) {
        await updateLabel(label);
      }

      // 2. Discover Categories from Navigation
      final categories = <MovieCategory>[];
      final seenPaths = <String>{};

      // Common selectors for menus
      final navLinks = document.querySelectorAll(
        'nav a, .menu a, .navbar a, #main-menu a, .list-category a',
      );

      for (final link in navLinks) {
        final name = link.text.trim();
        final path = link.attributes['href'] ?? '';

        if (name.isEmpty || path.isEmpty) continue;
        if (path == '/' || path == baseUrl) continue;

        // Filter for interesting paths
        final isCategory =
            path.contains('/category/') ||
            path.contains('/trending/') ||
            path.contains('/video/') ||
            path.contains('/tag/');

        if (isCategory && !seenPaths.contains(path)) {
          final id = path
              .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')
              .toLowerCase();
          categories.add(
            MovieCategory(
              id: id,
              name: name,
              path: path.startsWith('http')
                  ? path.replaceFirst(baseUrl!, '')
                  : path,
            ),
          );
          seenPaths.add(path);
        }
      }

      if (categories.isNotEmpty) {
        await updateCategories(categories);
      }

      logger.d(
        'MovieService discoverConfig success: Label=$label, Cats=${categories.length}',
      );
    } catch (e) {
      logger.e('MovieService discoverConfig failed', error: e);
    }
  }

  List<MovieCategory> getCategories() {
    final raw = storageService.getMovieCategories();
    if (raw == null || raw.isEmpty) return [];
    try {
      final List<dynamic> list = jsonDecode(raw);
      return list.map((e) => MovieCategory.fromJson(e)).toList();
    } catch (e) {
      logger.e('MovieService getCategories failed', error: e);
      return [];
    }
  }

  Future<void> updateCategories(List<MovieCategory> categories) async {
    final raw = jsonEncode(categories.map((e) => e.toJson()).toList());
    await storageService.setMovieCategories(raw);
  }

  String getLabel() {
    return storageService.getMovieLabel() ?? 'Movie';
  }

  Future<void> updateLabel(String label) async {
    await storageService.setMovieLabel(label);
  }

  /// Helper to fix relative URLs
  String _fixUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    final base = baseUrl ?? '';
    if (url.startsWith('/')) return '$base$url';
    return '$base/$url';
  }

  String resolveServerPath(String path) => _fixUrl(path);

  String toServerPath(String url) {
    final value = url.trim();
    if (value.isEmpty) return '';
    final uri = Uri.tryParse(value);
    if (uri != null && uri.hasScheme && uri.host.isNotEmpty) {
      final path = uri.path.isEmpty ? '/' : uri.path;
      return uri.hasQuery ? '$path?${uri.query}' : path;
    }
    return value.startsWith('/') ? value : '/$value';
  }

  bool _isVietsub(String value) {
    return RegExp(
      r'viet\s*sub|việt\s*sub',
      caseSensitive: false,
    ).hasMatch(value);
  }

  /// Helper to extract movie ID from URL slug (e.g. "...-3982.html" => "3982")
  String _extractId(String url) {
    final match = RegExp(r'-(\d+)\.html').firstMatch(url);
    if (match != null) {
      return match.group(1) ?? '';
    }
    return '';
  }

  /// Parse movie list items and total count from HTML document or JSON response
  MovieResponse _parseMovieResponse(dynamic data) {
    String htmlContent;
    if (data is Map && data.containsKey('movies')) {
      htmlContent = data['movies'].toString();
    } else {
      htmlContent = data.toString();
    }

    final document = html_parser.parse(htmlContent);
    final movies = <Movie>[];
    final seenIds = <String>{};

    // Extract total count if available (Search results)
    int total = 0;
    final recordEl = document.querySelector('.record');
    if (recordEl != null) {
      final match = RegExp(r'(\d+)').firstMatch(recordEl.text);
      if (match != null) {
        total = int.tryParse(match.group(1)!) ?? 0;
      }
    }

    // Fallback: estimate from pagination
    if (total == 0) {
      final navLinks = document.querySelectorAll('.navigation .page-numbers');
      if (navLinks.isNotEmpty) {
        int maxPage = 1;
        for (final link in navLinks) {
          final pageText = link.text.trim();
          final pageNum = int.tryParse(pageText);
          if (pageNum != null && pageNum > maxPage) {
            maxPage = pageNum;
          }
        }
        // Estimate: usually 20 items per page
        // If we are on page 1, we can see how many items are there
      }
    }

    // Selectors covering different sections (carousel, category grid, trending, sidebar)
    final mainContent = document.querySelector('#main-content');
    final container = mainContent ?? document;

    final items = container.querySelectorAll(
      '.movie-item, .movie-carousel-top-item, .trending-movie-item, .last-film-box li a',
    );

    for (final item in items) {
      final anchor =
          item.localName == 'a'
              ? item
              : item.querySelector('a') ?? item.parent;
      if (anchor == null || anchor.localName != 'a') continue;

      final href = anchor.attributes['href'] ?? '';
      if (!href.contains('.html')) continue;

      final id = _extractId(href);
      if (id.isEmpty || seenIds.contains(id)) continue;

      final title =
          anchor.attributes['title'] ??
          anchor
              .querySelector(
                '.movie-title-1, .movie-name-1, .trending-movie-name, .list-top-movie-item-vn',
              )
              ?.text
              .trim() ??
          '';

      if (title.isEmpty) continue;

      final imgEl = anchor.querySelector('img');
      String poster = '';
      if (imgEl != null) {
        poster = imgEl.attributes['src'] ?? imgEl.attributes['data-src'] ?? '';
      } else {
        final style =
            anchor
                .querySelector('.list-top-movie-item-thumb')
                ?.attributes['style'] ??
            '';
        final bgMatch = RegExp(r"url\('?([^'\)]+)'?\)").firstMatch(style);
        if (bgMatch != null) poster = bgMatch.group(1) ?? '';
      }

      final subtitle = anchor
          .querySelector('.meta-sub, .ribbon-sub')
          ?.text
          .trim();
      final badge =
          anchor.querySelector('.ribbon-sub, .ribbon')?.text.trim() ?? subtitle;
      final views = anchor
          .querySelector(
            '.meta-viewed, .ribbon-viewed, .list-top-movie-item-view',
          )
          ?.text
          .trim();
      final likes = anchor.querySelector('.meta-like')?.text.trim();
      final hasVietsub = _isVietsub(
        [title, subtitle, badge].whereType<String>().join(' '),
      );

      movies.add(
        Movie(
          id: id,
          title: title,
          url: _fixUrl(href),
          poster: _fixUrl(poster),
          badge: badge,
          views: views,
          likes: likes,
          hasVietsub: hasVietsub,
        ),
      );
      seenIds.add(id);
    }

    // Final total calculation if not found in .record
    if (total == 0) {
      final navLinks = document.querySelectorAll('.navigation .page-numbers');
      if (navLinks.isNotEmpty) {
        int maxPage = 1;
        for (final link in navLinks) {
          final pageNum = int.tryParse(link.text.trim());
          if (pageNum != null && pageNum > maxPage) maxPage = pageNum;
        }
        if (maxPage > 1) {
          // Approximate total = (maxPage - 1) * itemsPerPage + itemsOnLastPage
          // Here we assume itemsPerPage is movies.length if we are on page 1
          total = maxPage * movies.length;
        } else {
          total = movies.length;
        }
      } else {
        total = movies.length;
      }
    }

    return MovieResponse(movies: movies, total: total);
  }

  /// Get movies by category (trending, recent) with pagination
  Future<MovieResponse> getMoviesByCategory(
    String categoryPath, {
    int page = 1,
    CancelToken? cancelToken,
  }) async {
    if (baseUrl == null || baseUrl!.isEmpty) {
      return const MovieResponse(movies: [], total: 0);
    }
    try {
      String path = categoryPath;
      if (page > 1) {
        if (path == '/' || path == '') {
          // Home page AJAX pagination
          path = '/movies?page=${page - 1}';
        } else if (path.endsWith('/')) {
          path = '${path}page/$page/';
        } else {
          path = '$path/page/$page/';
        }
      }

      final response = await _dio.get(path, cancelToken: cancelToken);
      return _parseMovieResponse(response.data);
    } catch (e) {
      if (e is! DioException || e.type != DioExceptionType.cancel) {
        logger.e('MovieService getMoviesByCategory failed', error: e);
      }
      return const MovieResponse(movies: [], total: 0);
    }
  }

  /// Search movies by keyword with pagination
  Future<MovieResponse> searchMovies(
    String keyword, {
    int page = 1,
    CancelToken? cancelToken,
  }) async {
    if (baseUrl == null || baseUrl!.isEmpty) {
      return const MovieResponse(movies: [], total: 0);
    }
    try {
      final cleanKeyword = keyword.trim().toLowerCase().replaceAll(' ', '+');
      String path = '/search/$cleanKeyword/';
      if (page > 1) {
        path = '$path/page/$page/';
      }

      final response = await _dio.get(path, cancelToken: cancelToken);
      return _parseMovieResponse(response.data.toString());
    } catch (e) {
      if (e is! DioException || e.type != DioExceptionType.cancel) {
        logger.e('MovieService searchMovies failed', error: e);
      }
      return const MovieResponse(movies: [], total: 0);
    }
  }

  /// Fetch detail page HTML and extract metadata & stream
  Future<MovieDetail?> getMovieDetail(
    String movieUrl,
    String movieId, {
    CancelToken? cancelToken,
    bool includeStream = true,
  }) async {
    if (baseUrl == null || baseUrl!.isEmpty) return null;
    try {
      final response = await _dio.get(movieUrl, cancelToken: cancelToken);
      final htmlStr = response.data.toString();
      final document = html_parser.parse(htmlStr);

      final title =
          document.querySelector('h1.header-title')?.text.trim() ??
          document
              .querySelector('meta[property="og:title"]')
              ?.attributes['content'] ??
          '';

      final description =
          document.querySelector('#film-content-wrapper p')?.text.trim() ??
          document
              .querySelector('meta[name="description"]')
              ?.attributes['content'] ??
          '';

      final poster = _fixUrl(
        document
                .querySelector('meta[property="og:image"]')
                ?.attributes['content'] ??
            document.querySelector('img.thumb')?.attributes['src'],
      );

      final tagElements = document.querySelectorAll('.tag-list .tag-link');
      final tags = tagElements
          .map((e) => e.text.trim())
          .where((t) => t.isNotEmpty)
          .toList();
      final views = document.querySelector('.icon-view')?.text.trim();
      final likes = document.querySelector('.icon-like')?.text.trim();
      final hasVietsub = _isVietsub([title, description, ...tags].join(' '));

      final relatedMovies = _parseMovieResponse(
        htmlStr,
      ).movies.where((m) => m.id != movieId).toList();

      String? streamUrl;
      if (includeStream) {
        // Attempt to extract direct stream URL from inline script first.
        final atobMatch = RegExp(
          r'window\.atob\("([^"]+)"\)',
        ).firstMatch(htmlStr);
        if (atobMatch != null) {
          final b64 = atobMatch.group(1);
          if (b64 != null) {
            try {
              streamUrl = utf8.decode(base64.decode(b64));
            } catch (_) {}
          }
        }

        // If inline script didn't contain stream or failed, call AJAX server 1.
        if (streamUrl == null || streamUrl.isEmpty) {
          streamUrl = await getStreamUrl(
            movieId,
            movieUrl: movieUrl,
            server: 1,
            cancelToken: cancelToken,
          );
        }
      }

      final thumbnailTrackMatch = RegExp(
        r'''["']([^"']+\.vtt)["']''',
        caseSensitive: false,
      ).firstMatch(htmlStr);
      final thumbnailTrackUrl = _fixUrl(thumbnailTrackMatch?.group(1));

      return MovieDetail(
        id: movieId,
        title: title,
        url: movieUrl,
        poster: poster,
        description: description,
        views: views,
        likes: likes,
        hasVietsub: hasVietsub,
        streamUrl: streamUrl,
        thumbnailTrackUrl: thumbnailTrackUrl.isEmpty ? null : thumbnailTrackUrl,
        tags: tags,
        relatedMovies: relatedMovies,
      );
    } catch (e) {
      if (e is! DioException || e.type != DioExceptionType.cancel) {
        logger.e('MovieService getMovieDetail failed', error: e);
      }
      return null;
    }
  }

  /// Call POST /ajax API to get player HTML snippet, then decode base64 m3u8 stream
  Future<String?> getStreamUrl(
    String movieId, {
    String? movieUrl,
    int server = 1,
    CancelToken? cancelToken,
  }) async {
    if (baseUrl == null || baseUrl!.isEmpty) return null;
    try {
      final response = await _dio.post(
        '/ajax',
        data: {'id': movieId, 'server': server},
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Referer': movieUrl ?? '$baseUrl/',
            'Origin': baseUrl ?? '',
            'X-Requested-With': 'XMLHttpRequest',
          },
        ),
        cancelToken: cancelToken,
      );

      final data = response.data;
      if (data is Map && data.containsKey('player')) {
        final playerHtml = data['player'].toString();
        final match = RegExp(
          r'window\.atob\("([^"]+)"\)',
        ).firstMatch(playerHtml);
        if (match != null) {
          final b64 = match.group(1);
          if (b64 != null) {
            return utf8.decode(base64.decode(b64));
          }
        }
      }
    } catch (e) {
      if (e is! DioException || e.type != DioExceptionType.cancel) {
        logger.e('MovieService getStreamUrl server $server failed', error: e);
      }
    }
    return null;
  }

  Future<List<MovieStreamVariant>> getStreamVariants(
    String masterUrl, {
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get<String>(
        masterUrl,
        options: Options(
          responseType: ResponseType.plain,
          headers: {'Referer': '${baseUrl ?? ''}/'},
        ),
        cancelToken: cancelToken,
      );
      final source = response.data ?? '';
      final lines = source.split(RegExp(r'\r?\n'));
      final variantsByHeight = <int, MovieStreamVariant>{};

      for (var index = 0; index < lines.length; index++) {
        final metadata = lines[index].trim();
        if (!metadata.startsWith('#EXT-X-STREAM-INF:')) continue;

        final resolution = RegExp(
          r'RESOLUTION=(\d+)x(\d+)',
          caseSensitive: false,
        ).firstMatch(metadata);
        if (resolution == null) continue;

        var urlIndex = index + 1;
        while (urlIndex < lines.length &&
            (lines[urlIndex].trim().isEmpty ||
                lines[urlIndex].trim().startsWith('#'))) {
          urlIndex++;
        }
        if (urlIndex >= lines.length) continue;

        final width = int.parse(resolution.group(1)!);
        final height = int.parse(resolution.group(2)!);
        final bandwidth =
            int.tryParse(
              RegExp(
                    r'(?:AVERAGE-)?BANDWIDTH=(\d+)',
                    caseSensitive: false,
                  ).firstMatch(metadata)?.group(1) ??
                  '',
            ) ??
            0;
        final variant = MovieStreamVariant(
          label: '${height}p',
          url: Uri.parse(masterUrl).resolve(lines[urlIndex].trim()).toString(),
          width: width,
          height: height,
          bandwidth: bandwidth,
        );
        final existing = variantsByHeight[height];
        if (existing == null || bandwidth > existing.bandwidth) {
          variantsByHeight[height] = variant;
        }
      }

      final variants = variantsByHeight.values.toList()
        ..sort((a, b) => b.height.compareTo(a.height));
      return variants;
    } catch (error) {
      if (error is! DioException || error.type != DioExceptionType.cancel) {
        logger.e('MovieService get stream variants failed', error: error);
      }
      return [];
    }
  }
}

final movieService = MovieService();
