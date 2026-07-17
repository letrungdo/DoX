import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:do_x/extensions/widget_extensions.dart';
import 'package:do_x/gen/assets.gen.dart';
import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/router/app_router.gr.dart';
import 'package:do_x/screen/core/screen_state.dart';
import 'package:do_x/services/google_sync_service.dart';
import 'package:do_x/services/supabase_service.dart';
import 'package:do_x/utils/app_info.dart';
import 'package:do_x/view_model/chicken_view_model.dart';
import 'package:do_x/view_model/menu_view_model.dart';
import 'package:do_x/widgets/app_bar/app_bar_base.dart';
import 'package:do_x/widgets/button/button.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

@RoutePage()
class MenuScreen extends StatefulScreen implements AutoRouteWrapper {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();

  @override
  Widget wrappedRoute(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => MenuViewModel(), //
      child: this,
    );
  }
}

class _MenuScreenState<V extends MenuViewModel>
    extends ScreenState<MenuScreen, V> {
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _authSubscription = supabase.auth.onAuthStateChange.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: DoAppBar(
        title: l10n.menu,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            tooltip: l10n.settings,
            onPressed: () => context.pushRoute(const SettingsRoute()),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        height: 40,
        alignment: Alignment.center, //
        child: Text("© letrungdo. Ver ${appInfo.version}"),
      ),
      body: CustomScrollView(
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 20),
              child: Column(
                children: [
                  _buildMainActions(l10n).webConstrainedBox(),
                  const Spacer(),
                  _buildBottomActions(l10n).webConstrainedBox(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainActions(AppLocalizations l10n) {
    return ElevatedButtonTheme(
      data: _buttonTheme(),
      child: Column(
        spacing: 8,
        children: [
          _buildGoogleSyncControl(l10n),
          DoButton(
            onPressed: () {
              context.pushRoute(const WifiManagementRoute());
            },
            child: _buildMenuAction(Icons.wifi_rounded, l10n.wifiManagement),
          ),
          DoButton(
            onPressed: () {
              showAboutDialog(
                applicationVersion: appInfo.version, //
                applicationIcon: Assets.images.appIcon.image(),
                context: context,
              );
            },
            child: _buildMenuAction(Icons.info_outline_rounded, l10n.about),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions(AppLocalizations l10n) {
    return ElevatedButtonTheme(
      data: _buttonTheme(),
      child: _buildSupabaseAccountControl(l10n),
    );
  }

  ElevatedButtonThemeData _buttonTheme() {
    return ElevatedButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStatePropertyAll(
          BeveledRectangleBorder(borderRadius: BorderRadius.circular(5)), //
        ),
        padding: WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        ),
        minimumSize: WidgetStatePropertyAll(Size(double.infinity, 45)),
        alignment: Alignment.center,
        textStyle: WidgetStatePropertyAll(const TextStyle(fontSize: 16)),
      ),
    );
  }

  Widget _buildSupabaseAccountControl(AppLocalizations l10n) {
    final user = supabase.auth.currentUser;
    if (user == null) {
      return DoButton(
        onPressed: () => context.pushRoute(const AppLoginRoute()),
        child: _buildMenuAction(Icons.login_rounded, l10n.loginDoX),
      );
    }
    return DoButton(
      onPressed: () => _confirmSignOut(l10n),
      child: _buildMenuAction(
        Icons.logout_rounded,
        "${l10n.logout} (${user.email})",
      ),
    );
  }

  void _confirmSignOut(AppLocalizations l10n) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.confirmLogout),
        content: Text(l10n.confirmLogoutMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.logout),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await supabase.auth.signOut();
  }

  Widget _buildGoogleSyncControl(AppLocalizations l10n) {
    return Column(
      spacing: 8,
      children: [
        DoButton(
          onPressed: () async {
            if (googleSyncService.currentUser == null) {
              await googleSyncService.signIn();
            } else {
              await googleSyncService.signOut();
            }
            setState(() {});
          },
          child: _buildMenuAction(
            googleSyncService.currentUser == null
                ? Icons.login_rounded
                : Icons.logout_rounded,
            googleSyncService.currentUser == null
                ? l10n.loginGoogle
                : "${l10n.logoutGoogle} (${googleSyncService.currentUser!.email})",
          ),
        ),
        if (googleSyncService.currentUser != null)
          Selector<ChickenViewModel, bool>(
            selector: (p0, p1) => p1.autoSyncEnabled,
            builder: (context, autoSyncEnabled, _) {
              return SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                title: Text(l10n.autoSyncChickenToGoogleTasks),
                value: autoSyncEnabled,
                onChanged: (value) async {
                  final chickenVM = context.read<ChickenViewModel>();
                  chickenVM.setCurrentContext(context);
                  await chickenVM.setAutoSyncEnabled(value);
                  setState(() {});
                },
              );
            },
          ),
      ],
    );
  }

  Widget _buildMenuAction(IconData icon, String label) {
    return Row(
      children: [
        SizedBox.square(
          dimension: 32,
          child: Center(child: Icon(icon, size: 26)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}
