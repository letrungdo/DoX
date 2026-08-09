import 'package:auto_route/auto_route.dart';
import 'package:do_x/constants/enum/app_page.dart';
import 'package:do_x/extensions/app_page_extensions.dart';
import 'package:do_x/extensions/widget_extensions.dart';
import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/view_model/app_view_model.dart';
import 'package:do_x/view_model/chicken_view_model.dart';
import 'package:do_x/widgets/app_bar/app_bar_base.dart';
import 'package:do_x/widgets/app_scaffold.dart';
import 'package:do_x/widgets/neu/neu_card.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

@RoutePage()
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final appVm = context.watch<AppViewModel>();

    return AppScaffold(
      appBar: DoAppBar(title: l10n.settings),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _buildSettingCard(
            icon: Icons.language_rounded,
            color: Colors.blue,
            title: Text(l10n.language),
            trailing: DropdownButtonHideUnderline(
              child: DropdownButton<Locale>(
                value: appVm.locale ?? AppLocalizations.supportedLocales.first,
                isDense: true,
                borderRadius: BorderRadius.circular(14),
                onChanged: (newLocale) {
                  if (newLocale != null) appVm.setLocale(newLocale);
                },
                items: [
                  DropdownMenuItem(
                    value: const Locale('en'),
                    child: Text(l10n.english),
                  ),
                  DropdownMenuItem(
                    value: const Locale('vi'),
                    child: Text(l10n.vietnamese),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          _buildSettingCard(
            icon: Icons.palette_outlined,
            color: Theme.of(context).colorScheme.primary,
            title: Text(l10n.themeMode),
            trailing: DropdownButtonHideUnderline(
              child: DropdownButton<ThemeMode>(
                value: appVm.themeMode,
                isDense: true,
                borderRadius: BorderRadius.circular(14),
                onChanged: (newMode) {
                  if (newMode != null) appVm.setThemeMode(newMode);
                },
                items: [
                  DropdownMenuItem(
                    value: ThemeMode.system,
                    child: Text(l10n.system),
                  ),
                  DropdownMenuItem(
                    value: ThemeMode.light,
                    child: Text(l10n.light),
                  ),
                  DropdownMenuItem(
                    value: ThemeMode.dark,
                    child: Text(l10n.dark),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Selector<ChickenViewModel, bool>(
            selector: (_, vm) => vm.vaccinationNotificationsEnabled,
            builder: (context, enabled, _) => _buildSettingCard(
              icon: Icons.notifications_active_outlined,
              color: Colors.green.shade700,
              title: Text(l10n.vaccinationNotifications),
              trailing: Switch.adaptive(
                value: enabled,
                onChanged: (value) =>
                    _setVaccinationReminder(context, l10n, value),
              ),
              onTap: () => _setVaccinationReminder(context, l10n, !enabled),
            ),
          ),
          const SizedBox(height: 14),
          Selector<ChickenViewModel, bool>(
            selector: (_, vm) => vm.useLunarCalendar,
            builder: (context, useLunar, _) => _buildSettingCard(
              icon: Icons.calendar_month_rounded,
              color: Colors.deepPurple,
              title: Text(l10n.chickenLunarCalendar),
              trailing: Switch.adaptive(
                value: useLunar,
                onChanged: (value) =>
                    context.read<ChickenViewModel>().setUseLunarCalendar(value),
              ),
              onTap: () => context.read<ChickenViewModel>().setUseLunarCalendar(
                !useLunar,
              ),
            ),
          ),
          const SizedBox(height: 14),
          _buildSettingCard(
            icon: Icons.electric_bolt_rounded,
            color: Colors.amber.shade700,
            title: Text(l10n.electricReminder),
            trailing: Switch.adaptive(
              value: appVm.electricReminderEnabled,
              onChanged: (value) =>
                  _setElectricReminder(context, l10n, appVm, value),
            ),
            onTap: () => _setElectricReminder(
              context,
              l10n,
              appVm,
              !appVm.electricReminderEnabled,
            ),
          ),
          const SizedBox(height: 14),
          _buildLayoutCard(context, l10n, appVm),
        ],
      ),
    );
  }

  Future<void> _setElectricReminder(
    BuildContext context,
    AppLocalizations l10n,
    AppViewModel appVm,
    bool value,
  ) async {
    final changed = await appVm.setElectricReminderEnabled(value);
    if (value && !changed && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.notificationPermissionDenied)),
      );
    }
  }

  Future<void> _setVaccinationReminder(
    BuildContext context,
    AppLocalizations l10n,
    bool value,
  ) async {
    final chickenVm = context.read<ChickenViewModel>();
    chickenVm.setCurrentContext(context);
    final changed = await chickenVm.setVaccinationNotificationsEnabled(value);
    if (value && !changed && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.notificationPermissionDenied)),
      );
    }
  }

  /// Lets the user decide what the app looks like: drag to reorder within a
  /// section, or use the move button to send a page from the bottom bar to the
  /// menu and back.
  Widget _buildLayoutCard(
    BuildContext context,
    AppLocalizations l10n,
    AppViewModel appVm,
  ) {
    return NeuCard(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.swap_vert_rounded,
                    color: Colors.teal,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.pageLayout,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        l10n.menuTabAlwaysPinned,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _buildSectionHeader(
            context,
            "${l10n.bottomTabs} (${appVm.tabPages.length}/${AppPage.maxTabs})",
          ),
          _buildPageList(
            context,
            l10n,
            pages: appVm.tabPages,
            onReorder: appVm.reorderTabPages,
            moveIcon: Icons.arrow_downward_rounded,
            moveTooltip: l10n.moveToMenu,
            onMove: appVm.movePageToMenu,
            emptyLabel: l10n.noPagesHere,
          ),
          _buildSectionHeader(context, l10n.menu),
          _buildPageList(
            context,
            l10n,
            pages: appVm.menuPages,
            onReorder: appVm.reorderMenuPages,
            moveIcon: Icons.arrow_upward_rounded,
            moveTooltip: l10n.moveToBottomTabs,
            onMove: (page) {
              if (appVm.movePageToTabs(page)) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.maxTabsReached(AppPage.maxTabs))),
              );
            },
            emptyLabel: l10n.noPagesHere,
          ),
          const SizedBox(height: 8),
        ],
      ).contentConstrainedBox(),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _buildPageList(
    BuildContext context,
    AppLocalizations l10n, {
    required List<AppPage> pages,
    required void Function(int oldIndex, int newIndex) onReorder,
    required IconData moveIcon,
    required String moveTooltip,
    required void Function(AppPage page) onMove,
    required String emptyLabel,
  }) {
    if (pages.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
        child: Text(emptyLabel, style: Theme.of(context).textTheme.bodySmall),
      );
    }
    return ReorderableListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      onReorderItem: onReorder,
      children: [
        for (var i = 0; i < pages.length; i++)
          ListTile(
            key: ValueKey(pages[i]),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14),
            leading: ReorderableDragStartListener(
              index: i,
              child: Icon(
                Icons.drag_handle_rounded,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            title: Row(
              children: [
                Icon(pages[i].icon, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(pages[i].label(l10n))),
              ],
            ),
            trailing: IconButton(
              icon: Icon(moveIcon),
              tooltip: moveTooltip,
              onPressed: () => onMove(pages[i]),
            ),
          ),
      ],
    );
  }

  Widget _buildSettingCard({
    required IconData icon,
    required Color color,
    required Widget title,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    return NeuCard(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        onTap: onTap,
        leading: Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color),
        ),
        title: DefaultTextStyle.merge(
          style: const TextStyle(fontWeight: FontWeight.w600),
          child: title,
        ),
        trailing: trailing,
      ),
    );
  }
}
