import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:do_x/model/movie_model.dart';
import 'package:do_x/services/storage_service.dart';
import 'package:do_x/utils/logger.dart';
import 'package:html/parser.dart' as html_parser;

enum MovieSiteType { html, ophim }

class MovieService {
  static final MovieService _instance = MovieService._internal();
  factory MovieService() => _instance;
  MovieService._internal() {
    _initDio();
  }

  late String? baseUrl;
  late MovieSiteType _siteType;
  late Dio _dio;

  void _initDio() {
    baseUrl = storageService.getMovieBaseUrl();
    final typeStr = storageService.getMovieSiteType();
    _siteType = typeStr == 'ophim' ? MovieSiteType.ophim : MovieSiteType.html;

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
    if (formattedUrl.isEmpty) return;
    if (formattedUrl.endsWith('/')) {
      formattedUrl = formattedUrl.substring(0, formattedUrl.length - 1);
    }

    final servers = storageService.getMovieServers().toSet();
    if (servers.add(formattedUrl)) {
      await storageService.setMovieServers(servers.toList());
    }

    // Set as primary if none exists
    if (storageService.getPrimaryMovieServer() == null) {
      await storageService.setPrimaryMovieServer(formattedUrl);
    }

    await storageService.setMovieBaseUrl(formattedUrl);
    _initDio();
    await discoverConfig();
  }

  Future<void> deleteServer(String url) async {
    final primary = storageService.getPrimaryMovieServer();
    final servers = storageService.getMovieServers();
    servers.remove(url);
    await storageService.setMovieServers(servers);

    if (baseUrl == url) {
      if (servers.isNotEmpty) {
        await updateBaseUrl(servers.first);
      } else {
        await storageService.setMovieBaseUrl('');
        _initDio();
      }
    }

    if (primary == url) {
      await storageService.setPrimaryMovieServer(
        servers.isNotEmpty ? servers.first : '',
      );
    }
  }

  List<String> getServers() {
    return storageService.getMovieServers();
  }

  /// Discover Label and Categories from the current baseUrl
  Future<void> discoverConfig() async {
    if (baseUrl == null || baseUrl!.isEmpty) return;

    // Detect Ophim
    final primaryServer = storageService.getPrimaryMovieServer();
    final checkPrimary = primaryServer ?? '';

    final isPrimary = baseUrl == checkPrimary ||
        (baseUrl != null &&
            checkPrimary.isNotEmpty &&
            baseUrl!.contains(checkPrimary.replaceFirst('https://', '')));

    if (isPrimary) {
      await storageService.setMovieSiteType('ophim');
      _siteType = MovieSiteType.ophim;

      // Ensure we use the exact primary URL if it matches
      if (baseUrl != checkPrimary && checkPrimary.isNotEmpty) {
        await storageService.setMovieBaseUrl(checkPrimary);
        baseUrl = checkPrimary;
        _initDio();
      }
    } else {
      // Try to detect by fetching a common endpoint
      try {
        final check = await _dio.get('/danh-sach/phim-moi-cap-nhat?page=1');
        if (check.data is Map && check.data['status'] == true) {
          await storageService.setMovieSiteType('ophim');
          _siteType = MovieSiteType.ophim;
        } else {
          await storageService.setMovieSiteType('html');
          _siteType = MovieSiteType.html;
        }
      } catch (_) {
        await storageService.setMovieSiteType('html');
        _siteType = MovieSiteType.html;
      }
    }

    if (_siteType == MovieSiteType.ophim) {
      await _discoverOphimConfig();
      return;
    }

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

  Future<void> _discoverOphimConfig() async {
    try {
      await updateLabel('Ophim');

      final categories = <MovieCategory>[
        const MovieCategory(id: 'new', name: 'Mới cập nhật', path: '/danh-sach/phim-moi-cap-nhat'),
        const MovieCategory(id: 'phim-le', name: 'Phim lẻ', path: '/v1/api/danh-sach/phim-le'),
        const MovieCategory(id: 'phim-bo', name: 'Phim bộ', path: '/v1/api/danh-sach/phim-bo'),
        const MovieCategory(id: 'hoat-hinh', name: 'Hoạt hình', path: '/v1/api/danh-sach/hoat-hinh'),
        const MovieCategory(id: 'tv-shows', name: 'TV Shows', path: '/v1/api/danh-sach/tv-shows'),
      ];

      // Fetch genres
      try {
        final response = await _dio.get('/the-loai');
        if (response.data is Map && response.data['status'] == 'success') {
          final List<dynamic> items = response.data['data']['items'];
          for (final item in items) {
            final slug = item['slug'];
            categories.add(
              MovieCategory(
                id: 'genre_$slug',
                name: item['name'],
                path: '/v1/api/the-loai/$slug',
              ),
            );
          }
        }
      } catch (e) {
        logger.e('MovieService fetch genres failed', error: e);
      }

      // Fetch countries
      try {
        final response = await _dio.get('/quoc-gia');
        if (response.data is Map && response.data['status'] == 'success') {
          final List<dynamic> items = response.data['data']['items'];
          for (final item in items) {
            final slug = item['slug'];
            categories.add(
              MovieCategory(
                id: 'country_$slug',
                name: item['name'],
                path: '/v1/api/quoc-gia/$slug',
              ),
            );
          }
        }
      } catch (e) {
        logger.e('MovieService fetch countries failed', error: e);
      }

      await updateCategories(categories);
    } catch (e) {
      logger.e('MovieService discoverOphimConfig failed', error: e);
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

  String getLabelForUrl(String url) {
    final raw = storageService.getMovieServerLabels();
    if (raw == null) return url;
    try {
      final Map<String, dynamic> map = jsonDecode(raw);
      return map[url] as String? ?? url;
    } catch (_) {
      return url;
    }
  }

  Future<void> updateLabel(String label) async {
    await storageService.setMovieLabel(label);
    if (baseUrl != null) {
      final raw = storageService.getMovieServerLabels();
      Map<String, dynamic> map = {};
      if (raw != null) {
        try {
          map = jsonDecode(raw);
        } catch (_) {}
      }
      map[baseUrl!] = label;
      await storageService.setMovieServerLabels(jsonEncode(map));
    }
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

    if (_siteType == MovieSiteType.ophim) {
      return _getOphimMovies(categoryPath, page: page, cancelToken: cancelToken);
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

    if (_siteType == MovieSiteType.ophim) {
      return _searchOphimMovies(keyword, page: page, cancelToken: cancelToken);
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

  Future<MovieDetail?> getMovieDetail(
    String movieUrl,
    String movieId, {
    CancelToken? cancelToken,
    bool includeStream = true,
  }) async {
    if (baseUrl == null || baseUrl!.isEmpty) return null;

    final isOphim = _siteType == MovieSiteType.ophim;

    if (isOphim) {
      return _getOphimDetail(movieUrl, movieId, cancelToken: cancelToken);
    }

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

      final servers = <MovieEpisodeServer>[];
      for (int i = 1; i <= 6; i++) {
        servers.add(
          MovieEpisodeServer(
            name: 'Server $i',
            episodes: [
              MovieEpisode(
                name: 'Full',
                slug: movieId,
                // We'll fetch the actual stream URL when switching servers in UI
                m3u8Url: i == 1 ? streamUrl : null,
              ),
            ],
          ),
        );
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
        servers: servers,
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

  // --- Ophim JSON API Adapters ---

  Future<MovieResponse> _getOphimMovies(
    String path, {
    int page = 1,
    Map<String, dynamic>? extraParams,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        path,
        queryParameters: {'page': page, ...?extraParams},
        cancelToken: cancelToken,
      );
      var data = response.data;
      if (data is String) {
        try {
          data = jsonDecode(data);
        } catch (_) {}
      }
      if (data is! Map) return const MovieResponse(movies: [], total: 0);

      final List<dynamic> items = data['items'] ?? data['data']?['items'] ?? [];
      final cdnImage = data['data']?['APP_DOMAIN_CDN_IMAGE'] ?? '';

      final movies = items.map((item) {
        final slug = item['slug'];
        final thumb = item['thumb_url'] ?? '';

        return Movie(
          id: item['_id'] ?? slug,
          title: item['name'] ?? '',
          originalTitle: item['origin_name']?.toString(),
          quality: item['quality']?.toString(),
          language: item['lang']?.toString(),
          url: slug,
          poster: (thumb.startsWith('http') || cdnImage.isEmpty)
              ? thumb
              : '$cdnImage/$thumb',
          badge: item['year']?.toString(),
          hasVietsub: (item['lang'] ?? '')
              .toString()
              .toLowerCase()
              .contains('sub'),
        );
      }).toList();

      final pagination = data['pagination'] ??
          (data['data'] is Map ? data['data']['pagination'] : null) ??
          (data['data'] is Map && data['data']['params'] is Map
              ? data['data']['params']['pagination']
              : null);

      int totalCount = 0;
      if (pagination != null) {
        final rawTotal = pagination['totalItems'];
        totalCount = rawTotal is int
            ? rawTotal
            : int.tryParse(rawTotal?.toString() ?? '') ?? 0;
      }

      return MovieResponse(
        movies: movies,
        total: totalCount > 0 ? totalCount : (page == 1 ? movies.length : 0),
      );
    } catch (e) {
      if (e is! DioException || e.type != DioExceptionType.cancel) {
        logger.e('MovieService _getOphimMovies failed', error: e);
      }
      return const MovieResponse(movies: [], total: 0);
    }
  }

  Future<MovieResponse> _searchOphimMovies(
    String keyword, {
    int page = 1,
    CancelToken? cancelToken,
  }) async {
    return _getOphimMovies(
      '/v1/api/tim-kiem',
      page: page,
      extraParams: {'keyword': keyword},
      cancelToken: cancelToken,
    );
  }

  Future<MovieDetail?> _getOphimDetail(
    String urlOrSlug,
    String movieId, {
    CancelToken? cancelToken,
  }) async {
    try {
      String slug = urlOrSlug;
      final uri = Uri.tryParse(urlOrSlug);
      if (uri != null && uri.host.isNotEmpty) {
        slug = uri.pathSegments.where((s) => s.isNotEmpty).last;
      }
      while (slug.startsWith('/')) {
        slug = slug.substring(1);
      }

      final response = await _dio.get('/phim/$slug', cancelToken: cancelToken);
      dynamic data = response.data;
      if (data is String) {
        try {
          data = jsonDecode(data);
        } catch (_) {}
      }
      if (data is! Map || data['status'] != true) return null;

      final movieData = data['movie'];
      final episodesData = data['episodes'] as List<dynamic>? ?? [];

      String poster = movieData['poster_url'] ?? movieData['thumb_url'] ?? '';
      if (poster.isNotEmpty && !poster.startsWith('http')) {
        // Many Ophim APIs provide relative paths. Check if CDN domain is in the response.
        final cdnImage = data['data']?['APP_DOMAIN_CDN_IMAGE'] ?? '';
        if (cdnImage.isNotEmpty) {
          poster = '$cdnImage/$poster';
        }
      }

      final servers = <MovieEpisodeServer>[];
      String? firstStreamUrl;

      for (final srv in episodesData) {
        final serverName = srv['server_name']?.toString() ?? 'Server';
        final serverData = srv['server_data'] as List<dynamic>? ?? [];
        final episodes = <MovieEpisode>[];

        for (final ep in serverData) {
          final epM3u8 = ep['link_m3u8']?.toString();
          final epEmbed = ep['link_embed']?.toString();
          firstStreamUrl ??= epM3u8;

          episodes.add(
            MovieEpisode(
              name: ep['name']?.toString() ?? 'Tập',
              slug: ep['slug']?.toString() ?? '',
              m3u8Url: epM3u8,
              embedUrl: epEmbed,
            ),
          );
        }
        if (episodes.isNotEmpty) {
          servers.add(MovieEpisodeServer(name: serverName, episodes: episodes));
        }
      }

      return MovieDetail(
        id: movieData['_id'] ?? slug,
        title: movieData['name'] ?? '',
        originalTitle: movieData['origin_name']?.toString(),
        quality: movieData['quality']?.toString(),
        language: movieData['lang']?.toString(),
        time: movieData['time']?.toString(),
        url: slug,
        poster: poster,
        description: movieData['content'] ?? '',
        views: movieData['view']?.toString(),
        hasVietsub: (movieData['lang'] ?? '')
            .toString()
            .toLowerCase()
            .contains('sub'),
        streamUrl: firstStreamUrl,
        tags:
            (movieData['category'] as List<dynamic>? ?? [])
                .map((e) => e['name'] as String)
                .toList(),
        actors:
            (movieData['actor'] as List<dynamic>? ?? [])
                .whereType<String>()
                .toList(),
        directors:
            (movieData['director'] as List<dynamic>? ?? [])
                .whereType<String>()
                .toList(),
        countries:
            (movieData['country'] as List<dynamic>? ?? [])
                .map((e) => e['name'] as String)
                .toList(),
        servers: servers,
      );
    } catch (e) {
      if (e is! DioException || e.type != DioExceptionType.cancel) {
        logger.e('MovieService _getOphimDetail failed', error: e);
      }
      return null;
    }
  }
}

final movieService = MovieService();
