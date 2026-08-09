import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:do_x/constants/enum/app_page.dart';
import 'package:do_x/extensions/app_page_extensions.dart';
import 'package:do_x/extensions/widget_extensions.dart';
import 'package:do_x/gen/assets.gen.dart';
import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/router/app_router.gr.dart';
import 'package:do_x/screen/core/screen_state.dart';
import 'package:do_x/services/supabase_service.dart';
import 'package:do_x/utils/app_info.dart';
import 'package:do_x/view_model/app_view_model.dart';
import 'package:do_x/view_model/menu_view_model.dart';
import 'package:do_x/widgets/app_bar/app_bar_base.dart';
import 'package:do_x/widgets/app_scaffold.dart';
import 'package:do_x/widgets/dialog/app_modal.dart';
import 'package:do_x/widgets/neu/neu_button.dart';
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
    return AppScaffold(
      appBar: DoAppBar(
        title: l10n.menu,
        actions: [
          NeuIconButton(
            icon: Icons.settings_rounded,
            tooltip: l10n.settings,
            // Sized to the 44dp toolbar: a full-size button would leave the
            // shadow pair no room to breathe.
            size: 34,
            onPressed: () => context.pushRoute(const SettingsRoute()),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        height: 40,
        alignment: Alignment.center, //
        child: Text("© letrungdo. Ver ${appInfo.version}"),
      ),
      // Two slivers rather than one column with a Spacer: the page list is
      // user-defined now, so it has to be able to grow past one screen while
      // the account button still sits at the bottom when it doesn't.
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: _buildMainActions(l10n),
            ).contentConstrainedBox(),
          ),
          SliverFillRemaining(
            hasScrollBody: false,
            // Align stays inside the cap: the cap centres its child, which
            // would pull the bottom row back up to the middle of the page.
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: _buildBottomActions(l10n),
              ),
            ).contentConstrainedBox(),
          ),
        ],
      ),
    );
  }

  /// The pages the user left out of the bottom bar, in the order they set in
  /// Settings, plus the entries that only ever live here.
  Widget _buildMainActions(AppLocalizations l10n) {
    final pages = context.select<AppViewModel, List<AppPage>>(
      (vm) => vm.menuPages,
    );
    return Column(
      // 16: these are raised rows, so the gap has to clear their shadow reach.
      spacing: 16,
      children: [
        for (final page in pages)
          _menuButton(
            page.icon,
            page.label(l10n),
            // Pushed on the root stack, so the page opens on top of the bottom
            // bar with a back button instead of replacing a tab.
            () => context.pushRoute(page.route),
          ),
        _menuButton(Icons.info_outline_rounded, l10n.about, () {
          showAboutDialog(
            applicationVersion: appInfo.version, //
            applicationIcon: Assets.images.appIcon.image(),
            context: context,
          );
        }),
      ],
    );
  }

  Widget _buildBottomActions(AppLocalizations l10n) {
    return _buildSupabaseAccountControl(l10n);
  }

  /// Full-width neumorphic row. The menu is nothing but actions, so it is where
  /// the raised-to-sunken press cue does the most work.
  Widget _menuButton(IconData icon, String label, VoidCallback onPressed) {
    return NeuButton(
      onPressed: onPressed,
      expand: true,
      radius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      child: _buildMenuAction(icon, label),
    );
  }

  Widget _buildSupabaseAccountControl(AppLocalizations l10n) {
    final user = supabase.auth.currentUser;
    if (user == null) {
      return _menuButton(
        Icons.login_rounded,
        l10n.loginDoX,
        () => context.pushRoute(const AppLoginRoute()),
      );
    }
    return _menuButton(
      Icons.logout_rounded,
      "${l10n.logout} (${user.email})",
      () => _confirmSignOut(l10n),
    );
  }

  void _confirmSignOut(AppLocalizations l10n) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: l10n.confirmLogout,
      message: l10n.confirmLogoutMessage,
      confirmText: l10n.logout,
    );
    if (!confirmed || !mounted) return;
    await supabase.auth.signOut();
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
