/// Why a record carries a badge in the lists.
enum RecordChange {
  /// Created recently (a later edit keeps this: "new" is the stronger label).
  added,

  /// Created a while ago, but edited recently.
  updated,
}

/// A record that carries the server's create/update timestamps, so the lists
/// can badge what changed lately.
///
/// The badge is derived from the stored row rather than from a local log of
/// what this device did: the same "new"/"edited" marks then show up for
/// everyone reading the data, including a viewer of shared data, and they
/// survive a reinstall.
mixin TimestampedRecord<T> {
  /// How long a badge stays visible after the change.
  static const retention = Duration(days: 3);

  DateTime? get createdAt;
  DateTime? get updatedAt;

  /// Copy of this record carrying the given stamps (a plain `copyWith`).
  T stamped({DateTime? createdAt, DateTime? updatedAt});

  /// The badge this record should show, or null when nothing changed lately.
  /// Null timestamps (a row written before the columns existed) show nothing.
  RecordChange? get changeBadge {
    final now = DateTime.now();
    bool isRecent(DateTime? at) =>
        at != null && now.difference(at) <= retention;
    if (isRecent(createdAt)) return RecordChange.added;
    if (isRecent(updatedAt)) return RecordChange.updated;
    return null;
  }
}
