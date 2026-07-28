/// What a [PendingOp] does to the server.
enum PendingOpAction { insert, update, delete, rpc }

/// A single write described as data instead of a method call, so the exact same
/// value can either be sent right now or parked on disk and replayed once the
/// server is reachable again.
///
/// Everything here is already in the server's shape (snake_case column names,
/// dates as `yyyy-MM-dd`) — the repository builds these and is the only place
/// that knows how to execute one.
class PendingOp {
  const PendingOp({
    required this.action,
    required this.target,
    this.payload = const {},
    this.rowId,
    this.globalRecord = false,
  });

  final PendingOpAction action;

  /// Table name, or the function name for [PendingOpAction.rpc].
  final String target;

  /// The row for an insert, the changed columns for an update, the arguments
  /// for an rpc. Unused by a delete.
  final Map<String, dynamic> payload;

  /// Which row an update or delete targets.
  final String? rowId;

  /// Whether this targets a record that belongs to no batch (a global sale or
  /// expense). Those writes are additionally scoped to the current user with
  /// `batch_id is null`, and must match a row or the write counts as failed.
  final bool globalRecord;

  /// How many records this op accounts for, used for progress reporting.
  int get recordCount => action == PendingOpAction.rpc
      ? 1 +
            (payload['p_vaccinations'] as List? ?? const []).length +
            (payload['p_expenses'] as List? ?? const []).length +
            (payload['p_cock_sales'] as List? ?? const []).length +
            (payload['p_batch_sales'] as List? ?? const []).length
      : 1;

  factory PendingOp.fromJson(Map<String, dynamic> json) => PendingOp(
    action: PendingOpAction.values.byName(json['action'] as String),
    target: json['target'] as String,
    payload: Map<String, dynamic>.from(json['payload'] as Map? ?? const {}),
    rowId: json['rowId'] as String?,
    globalRecord: json['globalRecord'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'action': action.name,
    'target': target,
    'payload': payload,
    if (rowId != null) 'rowId': rowId,
    if (globalRecord) 'globalRecord': true,
  };

  /// Whether [next] writes the same columns of the same row, making this op
  /// pointless. Only ever checked against the op right behind it in the queue,
  /// so nothing can slip in between and change the meaning.
  bool supersededBy(PendingOp next) =>
      action == PendingOpAction.update &&
      next.action == PendingOpAction.update &&
      target == next.target &&
      rowId == next.rowId &&
      globalRecord == next.globalRecord;

  @override
  String toString() =>
      '${action.name} $target${rowId == null ? '' : '/$rowId'}';
}
