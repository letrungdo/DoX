import 'package:auto_route/auto_route.dart';
import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/view_model/app_view_model.dart';
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
          _buildSettingCard(
            icon: Icons.favorite_outline_rounded,
            color: Colors.pink,
            title: Text(l10n.showLocketTab),
            trailing: Switch.adaptive(
              value: appVm.showLocketTab,
              onChanged: appVm.setShowLocketTab,
            ),
            onTap: () => appVm.setShowLocketTab(!appVm.showLocketTab),
          ),
          const SizedBox(height: 10),
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
