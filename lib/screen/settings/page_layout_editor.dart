import 'dart:async';

import 'package:do_x/constants/dimens.dart';
import 'package:do_x/constants/enum/app_page.dart';
import 'package:do_x/extensions/app_page_extensions.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/utils/device_type.dart';
import 'package:do_x/view_model/app_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

/// Lets the user arrange which pages sit in the bottom bar and which stay in
/// the menu, by dragging.
///
/// The two groups are rendered as **one** [ReorderableListView] with a section
/// header between them, rather than a list each: a list can only reorder within
/// itself, which is why moving a page across used to need its own up/down
/// button. Here the header is just another row to drag past, so the same drag
/// that reorders a page also moves it between the groups.
///
/// A TV remote cannot drag, so there each row is a focus stop instead: OK picks
/// the page up, up and down walk it one row at a time through the same
/// flattened list — past a header into the other group — and OK or back puts
/// it down.
class PageLayoutEditor extends StatefulWidget {
  const PageLayoutEditor({super.key});

  @override
  State<PageLayoutEditor> createState() => _PageLayoutEditorState();
}

class _PageLayoutEditorState extends State<PageLayoutEditor> {
  /// The page the remote has picked up, moved by up and down until dropped.
  AppPage? _held;

  /// One node per page, owned here rather than by the tile: the list keys each
  /// row by its index as well, so a moved row is rebuilt from scratch and its
  /// focus has to be handed back to it.
  final _focusNodes = <AppPage, FocusNode>{};

  FocusNode _focusNodeOf(AppPage page) =>
      _focusNodes.putIfAbsent(page, () => FocusNode(debugLabel: page.name));

  @override
  void dispose() {
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final appVm = context.watch<AppViewModel>();
    final rows = _buildRows(appVm);

    return ReorderableListView.builder(
      shrinkWrap: true,
      // The whole settings page is already one scroll view.
      physics: const NeverScrollableScrollPhysics(),
      // Headers must not be draggable, so each page row installs its own
      // listeners instead.
      buildDefaultDragHandles: false,
      itemCount: rows.length,
      onReorderItem: (oldIndex, newIndex) =>
          _onReorder(context, appVm, l10n, rows, oldIndex, newIndex),
      itemBuilder: (context, index) =>
          _buildRow(context, l10n, appVm, rows, index),
    );
  }

  // -------------------------------------------------------------------------
  // Rows
  // -------------------------------------------------------------------------

  List<_Row> _buildRows(AppViewModel appVm) {
    return [
      const _Row.header(_LayoutGroup.tabs),
      for (final page in appVm.tabPages) _Row.page(_LayoutGroup.tabs, page),
      // Keeps an emptied group tall enough to drop a page back into.
      if (appVm.tabPages.isEmpty) const _Row.placeholder(_LayoutGroup.tabs),
      const _Row.header(_LayoutGroup.menu),
      for (final page in appVm.menuPages) _Row.page(_LayoutGroup.menu, page),
      if (appVm.menuPages.isEmpty) const _Row.placeholder(_LayoutGroup.menu),
    ];
  }

  Widget _buildRow(
    BuildContext context,
    AppLocalizations l10n,
    AppViewModel appVm,
    List<_Row> rows,
    int index,
  ) {
    final theme = Theme.of(context);
    final row = rows[index];

    switch (row.kind) {
      case _RowKind.header:
        final label = row.group == _LayoutGroup.tabs
            ? "${l10n.bottomTabs} (${appVm.tabPages.length}/${AppPage.maxTabs})"
            : l10n.menu;
        return Padding(
          key: ValueKey('header-${row.group.name}'),
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
          child: Text(
            label.toUpperCase(),
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 0.6,
            ),
          ),
        );

      case _RowKind.placeholder:
        return Padding(
          key: ValueKey('placeholder-${row.group.name}'),
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
          child: Text(l10n.noPagesHere, style: theme.textTheme.bodySmall),
        );

      case _RowKind.page:
        final page = row.page!;
        final isTv = deviceType.isTv;
        final isHeld = _held == page;
        // Long press anywhere on the row picks it up; the handle picks it up
        // straight away, for a user who has spotted it.
        return ReorderableDelayedDragStartListener(
          key: ValueKey(page),
          index: index,
          child: Focus(
            // Not a stop of its own: the tile is that. This one listens, so a
            // held page answers the arrows instead of letting focus walk off.
            canRequestFocus: false,
            skipTraversal: true,
            onKeyEvent: isTv
                ? (node, event) => _onKey(context, appVm, l10n, page, event)
                : null,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 14),
              leading: Icon(page.icon, size: 20),
              title: Text(page.label(l10n)),
              focusNode: isTv ? _focusNodeOf(page) : null,
              selected: isHeld,
              selectedTileColor: theme.colorScheme.primaryContainer,
              // Only the remote needs the row to be a button; on a touchscreen
              // a tap would just flash a ripple over a row that does nothing.
              onTap: isTv
                  ? () => setState(() => _held = isHeld ? null : page)
                  : null,
              trailing: ReorderableDragStartListener(
                index: index,
                child: Icon(
                  isHeld
                      ? Icons.unfold_more_rounded
                      : Icons.drag_handle_rounded,
                  color: isHeld
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        );
    }
  }

  // -------------------------------------------------------------------------
  // Remote
  // -------------------------------------------------------------------------

  KeyEventResult _onKey(
    BuildContext context,
    AppViewModel appVm,
    AppLocalizations l10n,
    AppPage page,
    KeyEvent event,
  ) {
    if (_held != page) return KeyEventResult.ignored;
    if (event is KeyUpEvent) return KeyEventResult.handled;

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.goBack || key == LogicalKeyboardKey.escape) {
      setState(() => _held = null);
      return KeyEventResult.handled;
    }
    final step = switch (key) {
      LogicalKeyboardKey.arrowUp => -1,
      LogicalKeyboardKey.arrowDown => 1,
      _ => 0,
    };
    // Left and right are swallowed too: letting focus leave would drop the
    // page somewhere the user did not choose.
    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight) {
      return KeyEventResult.handled;
    }
    if (step == 0) return KeyEventResult.ignored;

    // One row either way in the flattened list, in `onReorderItem` terms (an
    // index into the list with the page lifted out), so stepping past a header
    // is what carries the page into the other group.
    final rows = _buildRows(appVm);
    final index = rows.indexWhere((row) => row.page == page);
    _onReorder(context, appVm, l10n, rows, index, index + step);

    // The moved row is a new element, so once it is built the focus is put
    // back on it and the list scrolled to keep it in view.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final node = _focusNodes[page];
      final rowContext = node?.context;
      if (!mounted || node == null || rowContext == null) return;
      node.requestFocus();
      unawaited(
        Scrollable.ensureVisible(
          rowContext,
          alignment: Dimens.tvFocusScrollAlignment,
          duration: Dimens.tvFocusScrollDuration,
        ),
      );
    });
    return KeyEventResult.handled;
  }

  // -------------------------------------------------------------------------
  // Reorder
  // -------------------------------------------------------------------------

  void _onReorder(
    BuildContext context,
    AppViewModel appVm,
    AppLocalizations l10n,
    List<_Row> rows,
    int oldIndex,
    int newIndex,
  ) {
    final page = rows[oldIndex].page;
    if (page == null) return;

    // `onReorderItem` hands over an index that already accounts for the row
    // being lifted out, so the drop position is read against the list without
    // it. Which group the page lands in is decided by the last header above
    // that position, and its rank by how many of that group's pages precede it.
    final rest = List.of(rows)..removeAt(oldIndex);
    final dropIndex = newIndex.clamp(0, rest.length);
    var group = _LayoutGroup.tabs;
    var indexInGroup = 0;
    for (var i = 0; i < dropIndex; i++) {
      final row = rest[i];
      if (row.kind == _RowKind.header) {
        group = row.group;
        indexInGroup = 0;
      } else if (row.kind == _RowKind.page) {
        indexInGroup++;
      }
    }

    final wasTab = appVm.tabPages.contains(page);
    if (group == _LayoutGroup.tabs) {
      if (wasTab) {
        appVm.reorderTabPages(appVm.tabPages.indexOf(page), indexInGroup);
      } else if (!appVm.movePageToTabs(page, index: indexInGroup)) {
        context.showToast(l10n.maxTabsReached(AppPage.maxTabs), isError: true);
      }
    } else {
      if (wasTab) {
        appVm.movePageToMenu(page, index: indexInGroup);
      } else {
        appVm.reorderMenuPages(appVm.menuPages.indexOf(page), indexInGroup);
      }
    }
  }
}

enum _LayoutGroup { tabs, menu }

enum _RowKind { header, page, placeholder }

/// One row of the flattened two-group list.
class _Row {
  const _Row.header(this.group) : kind = _RowKind.header, page = null;
  const _Row.placeholder(this.group) : kind = _RowKind.placeholder, page = null;
  const _Row.page(this.group, AppPage this.page) : kind = _RowKind.page;

  final _RowKind kind;
  final _LayoutGroup group;
  final AppPage? page;
}
