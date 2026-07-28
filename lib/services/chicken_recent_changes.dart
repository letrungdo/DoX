import 'dart:convert';

import 'package:do_x/services/storage_service.dart';
import 'package:do_x/utils/logger.dart';

/// Why a record carries a badge in the lists.
enum RecordChange {
  /// Created recently (a later edit keeps this: "new" is the stronger label).
  added,

  /// Created a while ago, but edited recently.
  updated,
}

/// Remembers which chicken records were added or edited recently so the lists
/// can badge them.
///
/// The timestamps live here instead of on the models because the server rows
/// carry no created/updated columns: a refresh rebuilds every model from those
/// rows and would wipe anything stored on them. This store is keyed by record
/// id, kept on disk, and survives both a refresh and an app restart (on this
/// device — it is not synced).
class ChickenRecentChanges {
  ChickenRecentChanges({this.retention = const Duration(days: 3)});

  static const _version = 1;

  /// How long a badge stays visible after the change.
  final Duration retention;

  final Map<String, _Entry> _entries = {};

  bool _restored = false;

  /// Loads the stored timestamps. Safe to call more than once; only the first
  /// call reads from disk.
  void restore() {
    if (_restored) return;
    _restored = true;
    final raw = storageService.getChickenRecentChanges();
    if (raw == null) return;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      if (data['version'] != _version) {
        _clearStored();
        return;
      }
      final records = (data['records'] as Map?) ?? const {};
      records.forEach((id, value) {
        final entry = _Entry.tryParse(value);
        if (entry != null) _entries[id as String] = entry;
      });
      _prune();
    } catch (e) {
      logger.e('restore chicken recent changes failed', error: e);
      _clearStored();
    }
  }

  /// The badge a record should show, or null when there is nothing recent.
  RecordChange? statusOf(String id) {
    final entry = _entries[id];
    if (entry == null) return null;
    if (_isExpired(entry)) {
      _entries.remove(id);
      return null;
    }
    return entry.change;
  }

  void markAdded(String id) => _mark(id, RecordChange.added);

  /// Marks an edit. A record still badged as new stays new, only its timer is
  /// refreshed — editing something right after adding it should not downgrade
  /// the label.
  void markUpdated(String id) {
    final existing = _entries[id];
    final stillNew =
        existing != null &&
        existing.change == RecordChange.added &&
        !_isExpired(existing);
    _mark(id, stillNew ? RecordChange.added : RecordChange.updated);
  }

  /// Drops a deleted record, so a new record reusing the id cannot inherit its
  /// badge.
  void forget(String id) {
    if (_entries.remove(id) != null) _save();
  }

  void clear() {
    _entries.clear();
    _clearStored();
  }

  void _mark(String id, RecordChange change) {
    _entries[id] = _Entry(change, DateTime.now());
    _prune();
    _save();
  }

  bool _isExpired(_Entry entry) =>
      DateTime.now().difference(entry.at) > retention;

  void _prune() => _entries.removeWhere((_, entry) => _isExpired(entry));

  void _save() {
    final payload = jsonEncode({
      'version': _version,
      'records': {
        for (final entry in _entries.entries) entry.key: entry.value.toJson(),
      },
    });
    storageService.setChickenRecentChanges(payload).ignore();
  }

  void _clearStored() => storageService.clearChickenRecentChanges().ignore();
}

class _Entry {
  _Entry(this.change, this.at);

  final RecordChange change;
  final DateTime at;

  static _Entry? tryParse(dynamic value) {
    if (value is! Map) return null;
    final at = DateTime.tryParse(value['at'] as String? ?? '');
    if (at == null) return null;
    final change = RecordChange.values.firstWhere(
      (e) => e.name == value['change'],
      orElse: () => RecordChange.updated,
    );
    return _Entry(change, at);
  }

  Map<String, dynamic> toJson() => {
    'change': change.name,
    'at': at.toIso8601String(),
  };
}
