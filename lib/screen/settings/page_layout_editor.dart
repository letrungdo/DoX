import 'package:do_x/constants/enum/app_page.dart';
import 'package:do_x/extensions/app_page_extensions.dart';
import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/view_model/app_view_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Lets the user arrange which pages sit in the bottom bar and which stay in
/// the menu, by dragging.
///
/// The two groups are rendered as **one** [ReorderableListView] with a section
/// header between them, rather than a list each: a list can only reorder within
/// itself, which is why moving a page across used to need its own up/down
/// button. Here the header is just another row to drag past, so the same drag
/// that reorders a page also moves it between the groups.
class PageLayoutEditor extends StatelessWidget {
  const PageLayoutEditor({super.key});

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
        // Long press anywhere on the row picks it up; the handle picks it up
        // straight away, for a user who has spotted it.
        return ReorderableDelayedDragStartListener(
          key: ValueKey(page),
          index: index,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14),
            leading: Icon(page.icon, size: 20),
            title: Text(page.label(l10n)),
            trailing: ReorderableDragStartListener(
              index: index,
              child: Icon(
                Icons.drag_handle_rounded,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        );
    }
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.maxTabsReached(AppPage.maxTabs))),
        );
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
