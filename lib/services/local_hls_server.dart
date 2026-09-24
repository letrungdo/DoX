import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:do_x/utils/logger.dart';

/// Hands the platform player HLS playlists the app has rewritten.
///
/// AVPlayer takes a master playlist only over HTTP — a `file://` one never
/// becomes ready — so the rewritten text is served from the loopback
/// interface. Only the playlists come from here; the segments they list stay
/// on the remote servers.
class LocalHlsServer {
  /// [kept] is how many playlists stay reachable. A player reads a master once,
  /// as it opens, but a media playlist it may ask for only when it switches to
  /// that variant, well into playback.
  LocalHlsServer({int kept = 8}) : _kept = kept;

  final int _kept;
  HttpServer? _server;
  Future<HttpServer>? _starting;
  final _playlists = <String, Future<String> Function()>{};
  var _next = 0;

  /// The port the last socket was bound to, asked for again when the system
  /// has closed it, so links handed out before still resolve.
  int? _lastPort;

  /// A `http://127.0.0.1` link that serves [playlist].
  Future<String> serve(String playlist) =>
      serveLazy(() => Future.value(playlist));

  /// A `http://127.0.0.1` link that serves whatever [load] produces, called
  /// each time a player asks for it. A [load] that throws answers
  /// `502 Bad Gateway`, which the player reports as a failed stream.
  Future<String> serveLazy(Future<String> Function() load) async {
    final server = await _bound();
    final name = '${_next++}.m3u8';
    _playlists[name] = load;
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
    final server = await _bind();
    _server = server;
    _lastPort = server.port;
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

  Future<HttpServer> _bind() async {
    final lastPort = _lastPort;
    if (lastPort != null) {
      try {
        return await HttpServer.bind(InternetAddress.loopbackIPv4, lastPort);
      } on SocketException {
        // Taken by now; any free port will do for the links still to come.
      }
    }
    return HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  }

  Future<void> _answer(HttpRequest request) async {
    final name = request.uri.pathSegments.isEmpty
        ? ''
        : request.uri.pathSegments.last;
    final load = _playlists[name];
    final response = request.response;
    try {
      String? playlist;
      if (load != null) {
        try {
          playlist = await load();
        } on Object catch (e) {
          logger.d('[LocalHlsServer] $name: $e');
          response.statusCode = HttpStatus.badGateway;
        }
      } else {
        response.statusCode = HttpStatus.notFound;
      }
      if (playlist != null) {
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
