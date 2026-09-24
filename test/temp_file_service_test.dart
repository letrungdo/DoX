import 'dart:io';

import 'package:do_x/services/temp_file_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory sandbox;
  late Directory cache;
  late TempFileService service;

  setUp(() {
    sandbox = Directory.systemTemp.createTempSync('temp_file_service_test');
    cache = Directory(p.join(sandbox.path, 'cache'))..createSync();
    service = TempFileService(roots: () async => [cache]);
  });

  tearDown(() => sandbox.deleteSync(recursive: true));

  File write(String relative, {Duration age = Duration.zero}) {
    final file = File(p.join(cache.path, relative))
      ..createSync(recursive: true)
      ..writeAsStringSync('x');
    file.setLastModifiedSync(DateTime.now().subtract(age));
    return file;
  }

  group('delete', () {
    test('removes a cached file and the picker directory it sat in', () async {
      final file = write('a1b2/clip.mp4');

      await service.delete(file.path);

      expect(file.existsSync(), isFalse);
      expect(file.parent.existsSync(), isFalse);
      expect(cache.existsSync(), isTrue);
    });

    test('never touches a file outside the cache', () async {
      final outside = File(p.join(sandbox.path, 'gallery.mp4'))
        ..writeAsStringSync('x');

      await service.delete(outside.path);

      expect(outside.existsSync(), isTrue);
    });

    test('keeps the cache root even when it is left empty', () async {
      final file = write('clip.mp4');

      await service.delete(file.path);

      expect(file.existsSync(), isFalse);
      expect(cache.existsSync(), isTrue);
    });
  });

  group('sweep', () {
    test('removes old media and keeps recent media and other files', () async {
      final old = write('trimmed_video_1.mp4', age: const Duration(days: 2));
      final oldPick = write('f00d/IMG_1.HEIC', age: const Duration(days: 2));
      final recent = write('cropped_video_2.mp4');
      final apk = write('dox_1.0.0_5.apk', age: const Duration(days: 2));

      await service.sweep();

      expect(old.existsSync(), isFalse);
      expect(oldPick.existsSync(), isFalse);
      expect(oldPick.parent.existsSync(), isFalse);
      expect(recent.existsSync(), isTrue);
      expect(apk.existsSync(), isTrue);
    });

    test('leaves the network image cache alone', () async {
      final image = write(
        'libCachedImageData/poster.jpg',
        age: const Duration(days: 2),
      );

      await service.sweep();

      expect(image.existsSync(), isTrue);
    });

    test('keeps an empty directory it did not empty itself', () async {
      final kept = Directory(p.join(cache.path, 'plugin_dir'))..createSync();

      await service.sweep();

      expect(kept.existsSync(), isTrue);
    });
  });
}
