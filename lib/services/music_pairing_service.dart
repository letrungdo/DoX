import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:do_x/model/music_account.dart';
import 'package:do_x/utils/logger.dart';
import 'package:flutter/foundation.dart';

/// Signs a television in to the music service with the account a phone is
/// already signed in with, the way a TV app shows a code for the phone to scan.
///
/// A television cannot be trusted to get through the service's own sign-in
/// page: its bot check asks for a challenge a remote cannot answer, and the
/// user is stuck on it. The phone gets through it fine. So the television
/// shows a QR code, the phone scans it and hands over its token, and the
/// television never opens the sign-in page at all.
///
/// The hand-over stays on the home network: the television listens on a port
/// of its own, and the QR code carries its address plus a one-off secret. The
/// token is sealed with that secret before it leaves the phone, so another
/// device on the same Wi-Fi sees neither the token nor a way to push one.
///
/// The code is an `http` address so that a phone's own camera app, which opens
/// it in a browser, lands on a page explaining where to scan it instead.
class MusicPairingCode {
  const MusicPairingCode({
    required this.host,
    required this.port,
    required this.secret,
  });

  static const _path = '/music/pair';
  static const _secretParam = 'key';

  final String host;
  final int port;
  final Uint8List secret;

  Uri get uri => Uri(
    scheme: 'http',
    host: host,
    port: port,
    path: _path,
    queryParameters: {_secretParam: _base64(secret)},
  );

  /// The code read back from what a scanner saw, or `null` when it is some
  /// other QR code.
  static MusicPairingCode? tryParse(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null || uri.scheme != 'http' || uri.path != _path) return null;
    if (uri.host.isEmpty || !uri.hasPort) return null;
    final encoded = uri.queryParameters[_secretParam] ?? '';
    try {
      final secret = _unbase64(encoded);
      if (secret.length != MusicPairingCipher.secretLength) return null;
      return MusicPairingCode(host: uri.host, port: uri.port, secret: secret);
    } on FormatException {
      return null;
    }
  }
}

/// Seals the token for the trip from phone to television.
///
/// Built from HMAC-SHA256 alone, which is all the `crypto` package offers: the
/// keystream is HMAC over a random nonce and a block counter (a PRF in counter
/// mode), and a second HMAC under a separate key authenticates the nonce and
/// the ciphertext together. Encrypt-then-MAC, keys split from one secret.
class MusicPairingCipher {
  const MusicPairingCipher(this.secret);

  static const secretLength = 32;
  static const _nonceLength = 16;

  final Uint8List secret;

  static Uint8List newSecret() => _randomBytes(secretLength);

  Map<String, String> seal(String plaintext) {
    final nonce = _randomBytes(_nonceLength);
    final data = utf8.encode(plaintext);
    final cipher = _xorKeystream(nonce, data);
    return {
      'nonce': _base64(nonce),
      'data': _base64(cipher),
      'mac': _base64(_mac(nonce, cipher)),
    };
  }

  /// The plaintext, or `null` when the envelope was not sealed with this
  /// secret or has been tampered with.
  String? open(Map<String, dynamic> envelope) {
    try {
      final nonce = _unbase64(envelope['nonce']?.toString() ?? '');
      final cipher = _unbase64(envelope['data']?.toString() ?? '');
      final mac = _unbase64(envelope['mac']?.toString() ?? '');
      if (nonce.length != _nonceLength) return null;
      if (!_constantTimeEquals(mac, _mac(nonce, cipher))) return null;
      return utf8.decode(_xorKeystream(nonce, cipher));
    } on FormatException {
      return null;
    }
  }

  Uint8List _subKey(String label) => Uint8List.fromList(
    Hmac(sha256, secret).convert(utf8.encode(label)).bytes,
  );

  Uint8List _xorKeystream(Uint8List nonce, List<int> input) {
    final hmac = Hmac(sha256, _subKey('do-x music pairing enc'));
    final output = Uint8List(input.length);
    var offset = 0;
    for (var counter = 0; offset < input.length; counter++) {
      final block = hmac.convert([
        ...nonce,
        (counter >> 24) & 0xff,
        (counter >> 16) & 0xff,
        (counter >> 8) & 0xff,
        counter & 0xff,
      ]).bytes;
      for (var i = 0; i < block.length && offset < input.length; i++) {
        output[offset] = input[offset] ^ block[i];
        offset++;
      }
    }
    return output;
  }

  Uint8List _mac(Uint8List nonce, List<int> cipher) {
    final hmac = Hmac(sha256, _subKey('do-x music pairing mac'));
    return Uint8List.fromList(hmac.convert([...nonce, ...cipher]).bytes);
  }

  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}

/// Why the phone's hand-over did not sign the television in.
enum MusicPairingError {
  /// The television could not be reached — another network, or it has since
  /// left the pairing screen.
  unreachable,

  /// The television took the token but the music service would not.
  rejected,
  unknown,
}

class MusicPairingException implements Exception {
  const MusicPairingException(this.kind, [this.detail]);

  final MusicPairingError kind;
  final String? detail;

  @override
  String toString() => 'MusicPairingException($kind, $detail)';
}

/// The television's side: listens for one phone, and hands the token it
/// brings to [onToken], which answers with the signed-in account's name — or
/// `null` when the token is no good, which the phone is told about.
class MusicPairingHost {
  MusicPairingHost({required this.onToken, required this.browserMessage});

  final Future<String?> Function(String accessToken) onToken;

  /// What a phone's browser is shown if the code is opened there rather than
  /// in the app's scanner. Already translated: this is the one piece of the
  /// television's pairing that is read on a page of its own.
  final String browserMessage;

  HttpServer? _server;
  MusicPairingCode? _code;
  bool _busy = false;

  MusicPairingCode? get code => _code;

  /// Opens the port and returns the code to show, or `null` when the
  /// television has no address on a home network to be reached at.
  ///
  /// [address] stands in for the home-network address in tests, which have
  /// none to count on.
  Future<MusicPairingCode?> start({@visibleForTesting String? address}) async {
    await stop();
    final host = address ?? await _lanAddress();
    if (host == null) return null;
    final server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    _server = server;
    final code = MusicPairingCode(
      host: host,
      port: server.port,
      secret: MusicPairingCipher.newSecret(),
    );
    _code = code;
    server.listen(
      (request) => unawaited(_handle(request, code)),
      onError: (Object e, StackTrace st) =>
          logger.e('MusicPairingHost server error', error: e, stackTrace: st),
    );
    return code;
  }

  Future<void> stop() async {
    final server = _server;
    _server = null;
    _code = null;
    await server?.close(force: true);
  }

  Future<void> _handle(HttpRequest request, MusicPairingCode code) async {
    final response = request.response;
    try {
      if (request.uri.path != MusicPairingCode._path) {
        response.statusCode = HttpStatus.notFound;
        return;
      }
      // Somebody opened the code with the phone's camera app: point them at
      // the scanner that can use it.
      if (request.method == 'GET') {
        response.headers.contentType = ContentType.html;
        response.write(_browserPage);
        return;
      }
      if (request.method != 'POST') {
        response.statusCode = HttpStatus.methodNotAllowed;
        return;
      }

      final body = await utf8.decoder.bind(request).join();
      final envelope = jsonDecode(body);
      final plaintext = envelope is Map<String, dynamic>
          ? MusicPairingCipher(code.secret).open(envelope)
          : null;
      if (plaintext == null) {
        response.statusCode = HttpStatus.forbidden;
        return;
      }
      final token =
          (jsonDecode(plaintext) as Map<String, dynamic>)['accessToken']
              ?.toString() ??
          '';
      if (token.isEmpty || _busy) {
        response.statusCode = _busy
            ? HttpStatus.conflict
            : HttpStatus.badRequest;
        return;
      }

      _busy = true;
      final String? name;
      try {
        name = await onToken(token);
      } finally {
        _busy = false;
      }
      response.headers.contentType = ContentType.json;
      if (name == null) {
        response.statusCode = HttpStatus.unprocessableEntity;
        return;
      }
      response.write(jsonEncode({'name': name}));
    } on Object catch (e, st) {
      logger.e('MusicPairingHost request failed', error: e, stackTrace: st);
      response.statusCode = HttpStatus.badRequest;
    } finally {
      await response.close();
    }
  }

  /// The television's address on the home network, Wi-Fi or Ethernet —
  /// whichever the phone is most likely to share with it.
  static Future<String?> _lanAddress() async {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
    );
    String? fallback;
    for (final interface in interfaces) {
      final name = interface.name.toLowerCase();
      final preferred = name.startsWith('wlan') || name.startsWith('eth');
      for (final address in interface.addresses) {
        if (!_isPrivate(address.address)) continue;
        if (preferred) return address.address;
        fallback ??= address.address;
      }
    }
    return fallback;
  }

  static bool _isPrivate(String ip) {
    final parts = ip.split('.').map(int.tryParse).toList();
    if (parts.length != 4 || parts.any((p) => p == null)) return false;
    final a = parts[0]!;
    final b = parts[1]!;
    return a == 10 ||
        (a == 172 && b >= 16 && b <= 31) ||
        (a == 192 && b == 168);
  }

  String get _browserPage {
    final message = const HtmlEscape().convert(browserMessage);
    return '<!doctype html><html><head><meta charset="utf-8">'
        '<meta name="viewport" content="width=device-width, initial-scale=1">'
        '<title>Do X</title></head>'
        '<body style="font-family:sans-serif;padding:24px;text-align:center">'
        '<h2>Do X</h2><p>$message</p></body></html>';
  }
}

/// The phone's side: hands [account]'s token to the television behind
/// [code], and returns the name the television signed in as.
Future<String> sendMusicAccountToTv(
  MusicPairingCode code,
  MusicAccount account,
) async {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      // The television checks the token with the music service before it
      // answers, so it gets the same patience a sign-in does.
      receiveTimeout: const Duration(seconds: 25),
    ),
  );
  final envelope = MusicPairingCipher(
    code.secret,
  ).seal(jsonEncode({'accessToken': account.accessToken}));
  try {
    final response = await dio.postUri<Map<String, dynamic>>(
      code.uri.replace(queryParameters: const {}),
      data: jsonEncode(envelope),
      options: Options(contentType: Headers.jsonContentType),
    );
    return response.data?['name']?.toString() ?? '';
  } on DioException catch (e) {
    logger.e(
      'Music pairing hand-over failed',
      error: e,
      stackTrace: e.stackTrace,
    );
    final status = e.response?.statusCode;
    if (status == null) {
      throw MusicPairingException(MusicPairingError.unreachable, e.message);
    }
    if (status == HttpStatus.unprocessableEntity) {
      throw MusicPairingException(MusicPairingError.rejected, 'HTTP $status');
    }
    throw MusicPairingException(MusicPairingError.unknown, 'HTTP $status');
  } finally {
    dio.close();
  }
}

Uint8List _randomBytes(int length) {
  final random = Random.secure();
  return Uint8List.fromList(List.generate(length, (_) => random.nextInt(256)));
}

String _base64(List<int> bytes) => base64Url.encode(bytes).replaceAll('=', '');

Uint8List _unbase64(String value) =>
    base64Url.decode(base64Url.normalize(value));
