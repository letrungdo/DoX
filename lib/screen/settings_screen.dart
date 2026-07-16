import 'package:auto_route/auto_route.dart';
import 'package:do_x/extensions/string_extensions.dart';
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
        children: [
          ListTile(
            title: Text(l10n.themeMode),
            trailing: DropdownButton<ThemeMode>(
              value: appVm.themeMode,
              onChanged: (ThemeMode? newMode) {
                if (newMode != null) {
                  // We can update the AppViewModel to support setting theme directly or just toggle until it matches.
                  // But it's better to add a setThemeMode method.
                  appVm.setThemeMode(newMode);
                }
              },
              items: [
                DropdownMenuItem(value: ThemeMode.system, child: Text(l10n.system)),
                DropdownMenuItem(value: ThemeMode.light, child: Text(l10n.light)),
                DropdownMenuItem(value: ThemeMode.dark, child: Text(l10n.dark)),
              ],
            ),
          ),
          const Divider(),
          SwitchListTile(
            title: Text(l10n.showLocketTab),
            value: appVm.showLocketTab,
            onChanged: (value) {
              appVm.setShowLocketTab(value);
            },
          ),
          const Divider(),
          ListTile(
            title: Text(l10n.language),
            trailing: DropdownButton<Locale>(
              value: appVm.locale ?? AppLocalizations.supportedLocales.first,
              onChanged: (Locale? newLocale) {
                if (newLocale != null) {
                  appVm.setLocale(newLocale);
                }
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
        ],
      ),
    );
  }
}
