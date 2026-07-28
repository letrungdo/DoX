import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/view_model/chicken_view_model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

/// What the banner is currently saying, so [Selector] can tell two identical
/// states apart from one that changed.
typedef _BannerState = ({
  int pending,
  bool syncing,
  int discarded,
  bool refreshFailed,
  DateTime? syncedAt,
});

/// Slim strip under the app bar that tells the user when what they are looking
/// at is not what the server holds:
///
/// * changes made offline are still waiting to be pushed,
/// * queued changes were rejected when they were finally replayed,
/// * the last refresh failed, so this is the cached copy.
///
/// Without it those states are invisible — the data just sits there looking
/// current, which matters most when the same account is used on two devices.
/// Renders nothing when everything is in sync.
class ChickenStaleBanner extends StatelessWidget {
  const ChickenStaleBanner({super.key, required this.selector});

  /// Which section's freshness to watch, e.g. `(vm) => vm.batchesSync`.
  final ChickenSyncStatus Function(ChickenViewModel vm) selector;

  static String _formatSyncedAt(DateTime time) {
    final now = DateTime.now();
    final isToday =
        now.year == time.year && now.month == time.month && now.day == time.day;
    return DateFormat(isToday ? 'HH:mm' : 'HH:mm dd/MM').format(time);
  }

  @override
  Widget build(BuildContext context) {
    return Selector<ChickenViewModel, _BannerState>(
      selector: (_, vm) {
        final status = selector(vm);
        return (
          pending: vm.pendingChangeCount,
          syncing: vm.isSyncing,
          discarded: vm.discardedChangeCount,
          refreshFailed: status.refreshFailed,
          syncedAt: status.syncedAt,
        );
      },
      builder: (context, state, _) {
        final l10n = AppLocalizations.of(context);
        final isDark = Theme.of(context).brightness == Brightness.dark;

        // Most actionable first: something went wrong, then work in progress,
        // then the merely-stale case.
        if (state.discarded > 0) {
          return _Bar(
            icon: Icons.error_outline_rounded,
            color: isDark ? Colors.red[300]! : Colors.red[900]!,
            message: l10n.changesDiscarded(state.discarded),
            onDismiss: context
                .read<ChickenViewModel>()
                .acknowledgeDiscardedChanges,
          );
        }
        if (state.pending > 0) {
          return _Bar(
            icon: state.syncing
                ? Icons.cloud_sync_rounded
                : Icons.cloud_off_rounded,
            color: isDark ? Colors.orange[300]! : Colors.orange[900]!,
            message: state.syncing
                ? l10n.syncingChanges(state.pending)
                : l10n.pendingChanges(state.pending),
          );
        }
        if (!state.refreshFailed) return const SizedBox.shrink();
        return _Bar(
          icon: Icons.cloud_off_rounded,
          color: isDark ? Colors.orange[300]! : Colors.orange[900]!,
          message: state.syncedAt == null
              ? l10n.refreshFailedNoData
              : l10n.dataAsOf(_formatSyncedAt(state.syncedAt!)),
        );
      },
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.icon,
    required this.color,
    required this.message,
    this.onDismiss,
  });

  final IconData icon;
  final Color color;
  final String message;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, 6, onDismiss == null ? 16 : 4, 6),
      color: color.withValues(alpha: 0.12),
      child: Row(
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(message, style: TextStyle(fontSize: 12, color: color)),
          ),
          if (onDismiss != null)
            IconButton(
              icon: Icon(Icons.close_rounded, size: 16, color: color),
              onPressed: onDismiss,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.all(8),
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            ),
        ],
      ),
    );
  }
}
