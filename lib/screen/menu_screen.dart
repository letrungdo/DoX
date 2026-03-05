import 'package:auto_route/auto_route.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/extensions/string_extensions.dart';
import 'package:do_x/extensions/text_style_extensions.dart';
import 'package:do_x/extensions/widget_extensions.dart';
import 'package:do_x/gen/assets.gen.dart';
import 'package:do_x/screen/core/screen_state.dart';
import 'package:do_x/services/google_sync_service.dart';
import 'package:do_x/utils/app_info.dart';
import 'package:do_x/view_model/app_view_model.dart';
import 'package:do_x/view_model/chicken_view_model.dart';
import 'package:do_x/view_model/menu_view_model.dart';
import 'package:do_x/widgets/app_bar/app_bar_base.dart';
import 'package:do_x/widgets/button/button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sficon/flutter_sficon.dart';
import 'package:provider/provider.dart';

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

class _MenuScreenState<V extends MenuViewModel> extends ScreenState<MenuScreen, V> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: DoAppBar(title: "Menu"),
      bottomNavigationBar: Container(
        height: 40,
        alignment: Alignment.center, //
        child: Text("© letrungdo. Ver ${appInfo.version}"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 20), //
        child: _buildBody().webConstrainedBox(),
      ),
    );
  }

  Widget _buildBody() {
    return ElevatedButtonTheme(
      data: ElevatedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(
            BeveledRectangleBorder(borderRadius: BorderRadius.circular(5)), //
          ),
          padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 10, vertical: 5)),
          minimumSize: WidgetStatePropertyAll(Size(double.infinity, 45)),
          alignment: Alignment.center,
          textStyle: WidgetStatePropertyAll(TextStyle().size16),
        ),
      ),
      child: Column(
        spacing: 8,
        children: [
          DoButton(
            child: Selector<AppViewModel, ThemeMode>(
              selector: (p0, p1) => p1.themeMode,
              builder: (context, themeMode, _) {
                return Row(
                  spacing: 8,
                  children: [
                    SFIcon(switch (themeMode) {
                      ThemeMode.dark => SFIcons.sf_moon_fill,
                      ThemeMode.light => SFIcons.sf_sun_min_fill,
                      ThemeMode.system => context.theme.brightness == Brightness.light ? SFIcons.sf_sun_min_fill : SFIcons.sf_moon_fill,
                    }),
                    Text(
                      "${themeMode.name.toCapitalized} Mode",
                      style: context.theme.elevatedButtonTheme.style?.textStyle?.resolve({}), //
                    ), //
                  ],
                );
              },
            ),
            onPressed: () {
              context.read<AppViewModel>().toggleThemeMode();
            },
          ),
          _buildGoogleSyncControl(),
          DoButton(
            text: "About",
            onPressed: () {
              showAboutDialog(
                applicationVersion: appInfo.version, //
                applicationIcon: Assets.images.appIcon.image(),
                context: context,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildGoogleSyncControl() {
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
          child: Row(
            spacing: 8,
            children: [
              Icon(googleSyncService.currentUser == null ? Icons.login : Icons.logout),
              Text(googleSyncService.currentUser == null ? "Đăng nhập Google" : "Đăng xuất (${googleSyncService.currentUser!.email})"),
            ],
          ),
        ),
        if (googleSyncService.currentUser != null)
          DoButton(
            text: "Khôi phục dữ liệu từ Cloud",
            onPressed: () {
              final chickenVM = context.read<ChickenViewModel>();
              chickenVM.setCurrentContext(context);
              chickenVM.restoreFromGoogle();
            },
          ),
      ],
    );
  }
}
