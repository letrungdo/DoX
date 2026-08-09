import 'dart:typed_data';

import 'package:do_x/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Reads and writes the signed-in account's profile picture.
///
/// The picture lives in the public `avatars` bucket under a folder named after
/// the owner's uid — which is what the storage policies key off — and its URL
/// is kept on the user's metadata, so no extra table and no extra round trip
/// to know whether someone has one.
class AvatarRepository {
  static const _bucket = 'avatars';

  /// Key the URL is stored under on `user_metadata`.
  static const metadataKey = 'avatar_url';

  SupabaseClient get _client => supabase;

  /// Uploads [bytes] as the current user's avatar and returns its public URL.
  ///
  /// Every upload gets its own name and the previous file is removed
  /// afterwards. Writing to one fixed path would be tidier, but the bucket is
  /// served through a CDN and every client that had already fetched the old
  /// picture would go on showing it.
  Future<String> upload(Uint8List bytes) async {
    final userId = _client.auth.currentUser!.id;
    final previous = await _list(userId);
    final path = '$userId/${DateTime.now().millisecondsSinceEpoch}.webp';

    await _client.storage
        .from(_bucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(contentType: 'image/webp'),
        );
    final url = _client.storage.from(_bucket).getPublicUrl(path);

    await _client.auth.updateUser(UserAttributes(data: {metadataKey: url}));
    // After the metadata points at the new file, so a failure here leaves a
    // stray object rather than an avatar the app cannot load.
    await _remove(previous);
    return url;
  }

  /// Drops the avatar: the metadata first, then the files behind it.
  Future<void> remove() async {
    final userId = _client.auth.currentUser!.id;
    await _client.auth.updateUser(UserAttributes(data: {metadataKey: null}));
    await _remove(await _list(userId));
  }

  Future<List<String>> _list(String userId) async {
    final files = await _client.storage.from(_bucket).list(path: userId);
    return files.map((file) => '$userId/${file.name}').toList();
  }

  Future<void> _remove(List<String> paths) async {
    if (paths.isEmpty) return;
    await _client.storage.from(_bucket).remove(paths);
  }
}
