import 'package:auto_route/auto_route.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/extensions/string_extensions.dart';
import 'package:do_x/extensions/text_style_extensions.dart';
import 'package:do_x/gen/assets.gen.dart';
import 'package:do_x/screen/core/screen_state.dart';
import 'package:do_x/utils/app_info.dart';
import 'package:do_x/view_model/app_view_model.dart';
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

class _MenuScreenState<V extends MenuViewModel> extends ScreenState<MenuScreen, V> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: DoAppBar(title: "Menu"),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 20), //
        child: _buildBody(),
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
                      ThemeMode.system => SFIcons.sf_a_circle_fill,
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
          Spacer(),
          Container(
            height: 40,
            alignment: Alignment.center, //
            child: Text("© letrungdo. Ver ${appInfo.version}"),
          ),
        ],
      ),
    );
  }
}
