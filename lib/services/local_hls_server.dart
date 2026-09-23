import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:do_x/utils/logger.dart';

/// Hands AVPlayer an HLS master playlist the app has rewritten.
///
/// AVPlayer takes a master playlist only over HTTP — a `file://` one never
/// becomes ready — so the rewritten text is served from the loopback
/// interface. Only the master comes from here; the media playlists and the
/// segments it lists stay on YouTube's servers.
class LocalHlsServer {
  /// How many playlists are kept. A player reads its master once, as it
  /// opens, so only the last few can still be asked for.
  static const _kept = 8;

  HttpServer? _server;
  Future<HttpServer>? _starting;
  final _playlists = <String, String>{};
  var _next = 0;

  /// A `http://127.0.0.1` link that serves [playlist].
  Future<String> serve(String playlist) async {
    final server = await _bound();
    final name = '${_next++}.m3u8';
    _playlists[name] = playlist;
    while (_playlists.length > _kept) {
      _playlists.remove(_playlists.keys.first);
    }
    return 'http://${InternetAddress.loopbackIPv4.address}:${server.port}/$name';
  }

  Future<HttpServer> _bound() {
    final server = _server;
    if (server != null) return Future.value(server);
    return _starting ??= _start().whenComplete(() => _starting = null);
  }

  Future<HttpServer> _start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server = server;
    server.listen(
      _answer,
      // The system may close the socket while the app is away; the next
      // playlist binds a new one.
      onError: (Object e) => logger.d('[LocalHlsServer] $e'),
      onDone: () {
        if (identical(_server, server)) _server = null;
      },
    );
    return server;
  }

  Future<void> _answer(HttpRequest request) async {
    final name = request.uri.pathSegments.isEmpty
        ? ''
        : request.uri.pathSegments.last;
    final playlist = _playlists[name];
    final response = request.response;
    try {
      if (playlist == null) {
        response.statusCode = HttpStatus.notFound;
      } else {
        // As bytes: the subtitle groups carry names in every script, and a
        // response writes Latin-1 unless told otherwise.
        response.headers.contentType = ContentType(
          'application',
          'vnd.apple.mpegurl',
          charset: 'utf-8',
        );
        response.add(utf8.encode(playlist));
      }
      await response.close();
    } on Object catch (e) {
      // A player that hung up before its answer is no reason to stop serving.
      logger.d('[LocalHlsServer] $e');
    }
  }
}
