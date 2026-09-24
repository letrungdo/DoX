import 'dart:io';

import 'package:do_x/utils/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Removes the media files the app's plugins leave in the cache.
///
/// Nothing cleans up after them on its own: `image_picker` copies every picked
/// photo or video into the cache (on Android into a directory of its own per
/// pick), and `easy_video_editor` writes each normalise, trim and re-export
/// there as a new file. A single MyLife video post leaves several copies of
/// the clip behind, so the cache grows with every use.
///
/// Files are removed as soon as the flow that made them is done
/// ([delete]), and anything missed — a flow cut short, an app killed midway —
/// is swept on the next launch ([sweep]).
class TempFileService {
  TempFileService({Future<List<Directory>> Function()? roots})
    : _roots = roots ?? _platformRoots;

  final Future<List<Directory>> Function() _roots;

  /// Extensions of the files the pickers and the video editor write.
  static const _mediaExtensions = {
    '.mp4',
    '.mov',
    '.m4v',
    '.3gp',
    '.jpg',
    '.jpeg',
    '.png',
    '.heic',
    '.heif',
    '.webp',
    '.gif',
  };

  /// Directories owned by something that manages its own size — the network
  /// image cache and the web views — and so left alone by the sweep.
  static const _managedDirectories = {
    'libCachedImageData',
    'WebKit',
    'WebView',
  };

  /// The cache directory, plus the separate `tmp` directory on Apple
  /// platforms, where the pickers and the video editor write instead.
  static Future<List<Directory>> _platformRoots() async {
    if (kIsWeb) return const [];
    final roots = <Directory>[await getTemporaryDirectory()];
    if (Platform.isIOS || Platform.isMacOS) roots.add(Directory.systemTemp);
    return roots;
  }

  /// Deletes the file at [path] when it lies in the cache, along with the
  /// directory the picker made for it once that is empty.
  ///
  /// A path outside the cache is never touched: on some platforms the picker
  /// hands back the original file rather than a copy.
  Future<void> delete(String? path) async {
    if (path == null || kIsWeb) return;
    try {
      final target = await _resolve(path);
      final root = await _rootOf(target);
      if (root == null) return;
      final file = File(target);
      if (await file.exists()) await file.delete();
      final parent = file.parent;
      if (p.isWithin(root, parent.path) && await parent.list().isEmpty) {
        await parent.delete();
      }
    } on Object catch (e) {
      logger.d('TempFileService could not delete $path', error: e);
    }
  }

  /// Deletes every media file in the cache last written before
  /// [olderThan] ago. Run at launch, when no flow is using one.
  Future<void> sweep({Duration olderThan = const Duration(hours: 1)}) async {
    if (kIsWeb) return;
    final cutoff = DateTime.now().subtract(olderThan);
    try {
      for (final root in await _roots()) {
        if (!await root.exists()) continue;
        await _sweepDirectory(root, root, cutoff);
      }
    } on Object catch (e) {
      logger.d('TempFileService sweep failed', error: e);
    }
  }

  /// Returns whether anything was deleted, so that only a directory the sweep
  /// itself emptied is removed — an empty one some plugin keeps is left be.
  Future<bool> _sweepDirectory(
    Directory directory,
    Directory root,
    DateTime cutoff,
  ) async {
    var deleted = false;
    await for (final entity in directory.list(followLinks: false)) {
      try {
        if (entity is Directory) {
          if (_managedDirectories.contains(p.basename(entity.path))) continue;
          if (await _sweepDirectory(entity, root, cutoff)) {
            deleted = true;
            await _deleteIfEmpty(entity, root);
          }
        } else if (entity is File &&
            _mediaExtensions.contains(p.extension(entity.path).toLowerCase()) &&
            (await entity.lastModified()).isBefore(cutoff)) {
          await entity.delete();
          deleted = true;
        }
      } on Object catch (e) {
        logger.d('TempFileService skipped ${entity.path}', error: e);
      }
    }
    return deleted;
  }

  /// The resolved path of the cache root the resolved [target] lies in, or
  /// null when it lies in none.
  ///
  /// Paths are resolved before they are compared: on iOS the same directory
  /// is handed out as both `/var/...` and `/private/var/...`.
  Future<String?> _rootOf(String target) async {
    for (final root in await _roots()) {
      final resolved = await _resolve(root.path);
      if (p.isWithin(resolved, target)) return resolved;
    }
    return null;
  }

  static Future<String> _resolve(String path) async {
    try {
      return await FileSystemEntity.isDirectory(path)
          ? await Directory(path).resolveSymbolicLinks()
          : await File(path).resolveSymbolicLinks();
    } on FileSystemException {
      return p.canonicalize(path);
    }
  }

  /// Deletes [directory] when it is empty and not [root] itself.
  Future<void> _deleteIfEmpty(Directory directory, Directory root) async {
    if (p.equals(directory.path, root.path)) return;
    if (_managedDirectories.contains(p.basename(directory.path))) return;
    if (await directory.list().isEmpty) await directory.delete();
  }
}

final tempFileService = TempFileService();
