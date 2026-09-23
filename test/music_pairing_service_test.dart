import 'dart:convert';
import 'dart:typed_data';

import 'package:do_x/model/music_account.dart';
import 'package:do_x/services/music_pairing_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const account = MusicAccount(accessToken: 'token-123', userId: '42');

  group('MusicPairingCipher', () {
    test('opens what it sealed', () {
      final cipher = MusicPairingCipher(MusicPairingCipher.newSecret());
      final text = 'x' * 100;
      expect(cipher.open(cipher.seal(text)), text);
    });

    test('refuses another secret and a tampered envelope', () {
      final cipher = MusicPairingCipher(MusicPairingCipher.newSecret());
      final envelope = cipher.seal('secret token');

      final stranger = MusicPairingCipher(MusicPairingCipher.newSecret());
      expect(stranger.open(envelope), isNull);

      final data = base64Url.decode(base64Url.normalize(envelope['data']!));
      data[0] ^= 1;
      final tampered = {
        ...envelope,
        'data': base64Url.encode(data).replaceAll('=', ''),
      };
      expect(cipher.open(tampered), isNull);
    });
  });

  group('MusicPairingCode', () {
    test('reads back its own uri', () {
      final secret = MusicPairingCipher.newSecret();
      final code = MusicPairingCode(
        host: '192.168.1.20',
        port: 40123,
        secret: secret,
      );
      final parsed = MusicPairingCode.tryParse(code.uri.toString());
      expect(parsed, isNotNull);
      expect(parsed!.host, '192.168.1.20');
      expect(parsed.port, 40123);
      expect(parsed.secret, secret);
    });

    test('ignores other QR codes', () {
      expect(MusicPairingCode.tryParse('https://example.com'), isNull);
      expect(MusicPairingCode.tryParse('hello'), isNull);
      expect(
        MusicPairingCode.tryParse('http://10.0.0.2:80/music/pair?key=abc'),
        isNull,
      );
    });
  });

  group('hand-over', () {
    late MusicPairingHost host;
    String? received;
    String? answer;

    setUp(() {
      received = null;
      answer = 'alice';
      host = MusicPairingHost(
        browserMessage: 'Open the app',
        onToken: (token) async {
          received = token;
          return answer;
        },
      );
    });

    tearDown(() => host.stop());

    test('signs the television in with the phone token', () async {
      final code = (await host.start(address: '127.0.0.1'))!;
      final name = await sendMusicAccountToTv(code, account);
      expect(received, 'token-123');
      expect(name, 'alice');
    });

    test('reports a token the television could not use', () async {
      answer = null;
      final code = (await host.start(address: '127.0.0.1'))!;
      await expectLater(
        sendMusicAccountToTv(code, account),
        throwsA(
          isA<MusicPairingException>().having(
            (e) => e.kind,
            'kind',
            MusicPairingError.rejected,
          ),
        ),
      );
    });

    test('turns away a phone without the secret', () async {
      final code = (await host.start(address: '127.0.0.1'))!;
      final forged = MusicPairingCode(
        host: code.host,
        port: code.port,
        secret: Uint8List(MusicPairingCipher.secretLength),
      );
      await expectLater(
        sendMusicAccountToTv(forged, account),
        throwsA(isA<MusicPairingException>()),
      );
      expect(received, isNull);
    });
  });
}
