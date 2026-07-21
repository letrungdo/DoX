import 'package:auto_route/auto_route.dart';
import 'package:do_x/constants/enum/app_tab.dart';
import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/view_model/app_view_model.dart';
import 'package:do_x/view_model/chicken_view_model.dart';
import 'package:do_x/widgets/app_bar/app_bar_base.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

@RoutePage()
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final appVm = context.watch<AppViewModel>();

    return Scaffold(
      appBar: DoAppBar(title: l10n.settings),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
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
          const SizedBox(height: 10),
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
          const SizedBox(height: 10),
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
          const SizedBox(height: 10),
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
          const SizedBox(height: 10),
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
          const SizedBox(height: 10),
          _buildTabOrderCard(context, l10n, appVm),
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

  String _tabLabel(AppTab tab, AppLocalizations l10n) {
    return switch (tab) {
      AppTab.news => l10n.news,
      AppTab.chicken => l10n.chicken,
      AppTab.locket => l10n.locket,
      AppTab.electric => l10n.electricity,
      AppTab.lunar => l10n.lunarCalendar,
      AppTab.menu => l10n.menu,
    };
  }

  bool _tabVisible(AppTab tab, AppViewModel appVm) {
    return switch (tab) {
      AppTab.locket => appVm.showLocketTab,
      AppTab.electric => appVm.showElectricTab,
      AppTab.lunar => appVm.showLunarTab,
      _ => true,
    };
  }

  /// Drag to reorder the bottom tabs; hideable tabs get a visibility switch.
  Widget _buildTabOrderCard(
    BuildContext context,
    AppLocalizations l10n,
    AppViewModel appVm,
  ) {
    final tabs = appVm.tabOrder;
    return Card(
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
                Text(
                  l10n.tabOrder,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            onReorderItem: (oldIndex, newIndex) {
              final order = List.of(tabs);
              final tab = order.removeAt(oldIndex);
              order.insert(newIndex, tab);
              appVm.setTabOrder(order);
            },
            children: [
              for (var i = 0; i < tabs.length; i++)
                ListTile(
                  key: ValueKey(tabs[i]),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                  leading: ReorderableDragStartListener(
                    index: i,
                    child: Icon(
                      Icons.drag_handle_rounded,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  title: Text(_tabLabel(tabs[i], l10n)),
                  trailing: tabs[i].isHideable
                      ? Switch.adaptive(
                          value: _tabVisible(tabs[i], appVm),
                          onChanged: (value) {
                            switch (tabs[i]) {
                              case AppTab.locket:
                                appVm.setShowLocketTab(value);
                              case AppTab.electric:
                                appVm.setShowElectricTab(value);
                              case AppTab.lunar:
                                appVm.setShowLunarTab(value);
                              default:
                                break;
                            }
                          },
                        )
                      : null,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingCard({
    required IconData icon,
    required Color color,
    required Widget title,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    return Card(
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
