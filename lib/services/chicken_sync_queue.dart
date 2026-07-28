import 'dart:convert';

import 'package:do_x/model/chicken/pending_op.dart';
import 'package:do_x/services/storage_service.dart';
import 'package:do_x/utils/logger.dart';

/// Writes made while the server was unreachable, kept in order on disk until
/// they can be replayed.
///
/// The queue is the reason an edit made offline is not a lie: the change is
/// already in the local lists and in the cache, and this holds the matching
/// server write so the two converge as soon as there is a connection again.
///
/// It is scoped to one user and deliberately survives sign-out — dropping it
/// would silently throw away work the user believes is saved. A queue left by
/// another account is discarded instead of replayed.
class ChickenSyncQueue {
  static const _version = 1;

  final List<PendingOp> _ops = [];

  String? _userId;

  int get length => _ops.length;
  bool get isEmpty => _ops.isEmpty;
  bool get isNotEmpty => _ops.isNotEmpty;

  /// Loads the stored queue for [userId]. A queue belonging to somebody else is
  /// dropped: those writes could never be replayed as this user anyway.
  void restore(String? userId) {
    _userId = userId;
    _ops.clear();
    final raw = storageService.getChickenSyncQueue();
    if (raw == null || userId == null) return;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      if (data['version'] != _version || data['userId'] != userId) {
        logger.d('discarding a chicken sync queue left by another account');
        _dropStored();
        return;
      }
      _ops.addAll(
        (data['ops'] as List).map(
          (e) => PendingOp.fromJson(e as Map<String, dynamic>),
        ),
      );
    } catch (e) {
      logger.e('restore chicken sync queue failed', error: e);
      _dropStored();
    }
  }

  /// [userId] is passed on every call rather than only on [restore] so a write
  /// that somehow beats the restore cannot be stored under a null owner — the
  /// next restore would take that for another account's queue and drop it.
  void add(Iterable<PendingOp> ops, String? userId) {
    _userId = userId;
    for (final op in ops) {
      // Editing the same record again before anything else is queued replaces
      // the earlier write instead of stacking on it — toggling a vaccination
      // ten times offline is one update, not ten.
      if (_ops.isNotEmpty && _ops.last.supersededBy(op)) {
        _ops[_ops.length - 1] = op;
        continue;
      }
      _ops.add(op);
    }
    _persist();
  }

  void _dropStored() {
    _ops.clear();
    storageService.clearChickenSyncQueue();
  }

  /// Replays the queued writes in order.
  ///
  /// Stops at the first write that cannot reach the server — that one and
  /// everything after it stay queued, order intact. A write the server actively
  /// rejects is dropped instead: replaying it would fail forever and block
  /// every later change behind it. The next refresh shows what the server
  /// really holds, which is the honest end state for a rejected write.
  /// Returns how many writes were dropped; whether anything is left is
  /// [isNotEmpty].
  Future<int> drain(
    Future<void> Function(PendingOp op) apply, {
    required bool Function(Object error) isOffline,
  }) async {
    var discarded = 0;
    while (_ops.isNotEmpty) {
      final op = _ops.first;
      try {
        await apply(op);
      } catch (e) {
        if (isOffline(e)) return discarded;
        logger.e('dropping rejected offline change ($op)', error: e);
        discarded++;
      }
      // Persist per op, not once at the end: if the app dies mid-drain the
      // queue on disk must not still hold writes the server already took.
      _ops.removeAt(0);
      _persist();
    }
    return discarded;
  }

  void _persist() {
    if (_ops.isEmpty) {
      storageService.clearChickenSyncQueue();
      return;
    }
    storageService.setChickenSyncQueue(
      jsonEncode({
        'version': _version,
        'userId': _userId,
        'ops': _ops.map((op) => op.toJson()).toList(),
      }),
    );
  }
}
