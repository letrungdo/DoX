import 'dart:async';
import 'dart:convert';

import 'package:auto_route/auto_route.dart';
import 'package:do_x/constants/dimens.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/extensions/widget_extensions.dart';
import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/screen/core/screen_state.dart';
import 'package:do_x/view_model/chicken_view_model.dart';
import 'package:do_x/widgets/app_bar/app_bar_base.dart';
import 'package:do_x/widgets/app_scaffold.dart';
import 'package:do_x/widgets/dialog/app_modal.dart';
import 'package:do_x/widgets/dialog/password_confirm_dialog.dart';
import 'package:do_x/widgets/setting_card.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Everything that configures the chicken section, kept here rather than in the
/// app-wide settings page: these switches only mean anything to someone using
/// the chicken pages, and the data actions belong next to them.
@RoutePage()
class ChickenSettingsScreen extends StatefulScreen implements AutoRouteWrapper {
  const ChickenSettingsScreen({super.key});

  @override
  State<ChickenSettingsScreen> createState() => _ChickenSettingsScreenState();

  @override
  Widget wrappedRoute(BuildContext context) => this;
}

class _ChickenSettingsScreenState
    extends ScreenState<ChickenSettingsScreen, ChickenViewModel> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AppScaffold(
      appBar: DoAppBar(title: l10n.settings),
      body: Consumer<ChickenViewModel>(
        builder: (context, vm, child) => SingleChildScrollView(
          child: Padding(
            padding: Dimens.screenPadding,
            child: Column(
              children: [
                SettingCard(
                  icon: Icons.notifications_active_outlined,
                  color: Colors.green.shade700,
                  title: Text(l10n.vaccinationNotifications),
                  trailing: Switch.adaptive(
                    value: vm.vaccinationNotificationsEnabled,
                    onChanged: _setVaccinationReminder,
                  ),
                  onTap: () => _setVaccinationReminder(
                    !vm.vaccinationNotificationsEnabled,
                  ),
                ),
                const SizedBox(height: 14),
                SettingCard(
                  icon: Icons.calendar_month_rounded,
                  color: Colors.deepPurple,
                  title: Text(l10n.chickenLunarCalendar),
                  subtitle: Text(l10n.chickenLunarCalendarDesc),
                  trailing: Switch.adaptive(
                    value: vm.useLunarCalendar,
                    onChanged: vm.setUseLunarCalendar,
                  ),
                  onTap: () => vm.setUseLunarCalendar(!vm.useLunarCalendar),
                ),
                // Importing is a one-off bootstrap: once there is anything in the
                // account it would merge into existing records instead.
                if (!vm.isReadOnly && vm.batches.isEmpty) ...[
                  const SizedBox(height: 14),
                  SettingCard(
                    icon: Icons.file_upload_outlined,
                    color: Colors.blue,
                    title: Text(l10n.importData),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: _importFromJsonFile,
                  ),
                ],
                if (!vm.isReadOnly) ...[
                  const SizedBox(height: 14),
                  SettingCard(
                    icon: Icons.delete_forever_outlined,
                    color: context.colors.danger,
                    title: Text(
                      l10n.deleteAllChickenData,
                      style: TextStyle(color: context.colors.danger),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: _confirmDeleteAllData,
                  ),
                ],
              ],
            ),
          ).contentConstrainedBox(),
        ),
      ),
    );
  }

  Future<void> _setVaccinationReminder(bool value) async {
    final l10n = AppLocalizations.of(context);
    vm.setCurrentContext(context);
    final changed = await vm.setVaccinationNotificationsEnabled(value);
    if (value && !changed && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.notificationPermissionDenied)),
      );
    }
  }

  Future<void> _importFromJsonFile() async {
    final l10n = AppLocalizations.of(context);
    const jsonTypeGroup = XTypeGroup(
      label: 'JSON',
      extensions: ['json'],
      mimeTypes: ['application/json'],
      uniformTypeIdentifiers: ['public.json'],
    );

    BuildContext? progressDialogContext;
    try {
      final file = await openFile(acceptedTypeGroups: [jsonTypeGroup]);
      if (file == null) return;

      var jsonString = utf8.decode(await file.readAsBytes());
      if (jsonString.startsWith('\uFEFF')) {
        jsonString = jsonString.substring(1);
      }

      progressDialogContext = await _showImportProgressDialog();
      final count = await vm.importFromJson(jsonString);
      if (progressDialogContext.mounted) Navigator.pop(progressDialogContext);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.importedRecords(count, file.name))),
      );
    } catch (e) {
      final dialogContext = progressDialogContext;
      if (dialogContext != null && dialogContext.mounted) {
        Navigator.pop(dialogContext);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        context.errorSnackBar(l10n.importFileFailed(e.toString())),
      );
    }
  }

  Future<BuildContext> _showImportProgressDialog() {
    final shown = Completer<BuildContext>();
    showAppModal<void>(
      context,
      barrierDismissible: false,
      builder: (dialogContext) {
        if (!shown.isCompleted) shown.complete(dialogContext);
        return PopScope(
          canPop: false,
          child: Consumer<ChickenViewModel>(
            builder: (context, vm, child) {
              final percent = (vm.importProgress * 100).round();
              return AppDialog(
                title: AppLocalizations.of(context).importingData,
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LinearProgressIndicator(value: vm.importProgress),
                    const SizedBox(height: 12),
                    Text("$percent%"),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
    return shown.future;
  }

  /// Wiping every record is final and cannot be synced back, so the password
  /// — not a second tap — is what unlocks it.
  Future<void> _confirmDeleteAllData() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showPasswordConfirmDialog(
      context,
      title: l10n.confirmDeleteAllChickenData,
      message: l10n.deleteAllChickenDataWarning,
      confirmText: l10n.deleteData,
    );
    if (!confirmed || !mounted) return;
    await _deleteAllData();
  }

  Future<void> _deleteAllData() async {
    final l10n = AppLocalizations.of(context);
    final shown = Completer<BuildContext>();
    showAppModal<void>(
      context,
      barrierDismissible: false,
      builder: (dialogContext) {
        if (!shown.isCompleted) shown.complete(dialogContext);
        return PopScope(
          canPop: false,
          child: AppDialog(
            title: l10n.deletingData,
            content: Row(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(width: 20),
                Expanded(child: Text(l10n.pleaseWait)),
              ],
            ),
          ),
        );
      },
    );
    final dialogContext = await shown.future;

    try {
      final count = await vm.deleteAllData();
      if (dialogContext.mounted) Navigator.pop(dialogContext);
      if (!mounted) return;
      final message = count == 0
          ? l10n.noDataToDelete
          : l10n.deletedAllData(count);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (dialogContext.mounted) Navigator.pop(dialogContext);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        context.errorSnackBar(l10n.deleteDataFailed(e.toString())),
      );
    }
  }
}
