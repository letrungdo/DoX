import 'package:auto_route/auto_route.dart';
import 'package:do_x/constants/dimens.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/extensions/widget_extensions.dart';
import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/screen/electric_screen.dart';
import 'package:do_x/view_model/app_view_model.dart';
import 'package:do_x/view_model/electric_view_model.dart';
import 'package:do_x/widgets/app_bar/app_bar_base.dart';
import 'package:do_x/widgets/app_scaffold.dart';
import 'package:do_x/widgets/dialog/app_modal.dart';
import 'package:do_x/widgets/setting_card.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Settings for the electricity section.
///
/// [electricVm] is handed in rather than created here: the electricity view
/// model is owned by [ElectricScreen], and signing an account out has to act on
/// that same instance for the page behind this one to notice.
@RoutePage()
class ElectricSettingsScreen extends StatelessWidget
    implements AutoRouteWrapper {
  const ElectricSettingsScreen({super.key, required this.electricVm});

  final ElectricViewModel electricVm;

  @override
  Widget wrappedRoute(BuildContext context) =>
      ChangeNotifierProvider.value(value: electricVm, child: this);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final appVm = context.watch<AppViewModel>();

    return AppScaffold(
      appBar: DoAppBar(title: l10n.settings),
      body: SingleChildScrollView(
        child: Padding(
          padding: Dimens.screenPadding,
          child: Column(
            children: [
              SettingCard(
                icon: Icons.person_add_alt_1_rounded,
                color: Colors.blue,
                title: Text(l10n.addAccount),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => showElectricAddAccountDialog(context),
              ),
              const SizedBox(height: 14),
              SettingCard(
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
              Selector<ElectricViewModel, (ElectricStatus, bool)>(
                selector: (_, vm) => (vm.status, vm.isMergedView),
                builder: (context, state, _) {
                  final (status, mergedView) = state;
                  // The merged tab has no single account to sign out of.
                  if (status != ElectricStatus.loggedIn || mergedView) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: SettingCard(
                      icon: Icons.logout_rounded,
                      color: context.colors.danger,
                      title: Text(
                        l10n.logout,
                        style: TextStyle(color: context.colors.danger),
                      ),
                      subtitle: Text(
                        context
                                .read<ElectricViewModel>()
                                .activeAccount
                                ?.displayName ??
                            '',
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => _confirmRemoveAccount(context, l10n),
                    ),
                  );
                },
              ),
            ],
          ),
        ).contentConstrainedBox(),
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

  /// Signing out leaves nothing here to act on, so the page goes back to the
  /// electricity screen — which is now showing the login form.
  Future<void> _confirmRemoveAccount(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    final vm = context.read<ElectricViewModel>();
    final name = vm.activeAccount?.displayName ?? "";
    final confirmed = await showAppConfirmDialog(
      context,
      title: l10n.logout,
      message: l10n.removeAccountConfirm(name),
      confirmText: l10n.logout,
    );
    if (!confirmed) return;
    await vm.removeActiveAccount();
    if (context.mounted) context.router.maybePop();
  }
}
