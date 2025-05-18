import 'package:auto_route/auto_route.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/extensions/string_extensions.dart';
import 'package:do_x/extensions/text_style_extensions.dart';
import 'package:do_x/screen/core/screen_state.dart';
import 'package:do_x/view_model/app_view_model.dart';
import 'package:do_x/view_model/menu_view_model.dart';
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(15), //
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        DoButton(
          child: Selector<AppViewModel, ThemeMode>(
            selector: (p0, p1) => p1.themeMode,
            builder: (context, themeMode, _) {
              return Row(
                children: [
                  SFIcon(switch (themeMode) {
                    ThemeMode.dark => SFIcons.sf_moon_fill,
                    ThemeMode.light => SFIcons.sf_sun_min_fill,
                    ThemeMode.system => SFIcons.sf_seal_fill,
                  }),
                  SizedBox(width: 8),
                  Text(
                    "${themeMode.name.toCapitalized} Mode",
                    style: context.textTheme.primary.medium.size16, //
                  ), //
                ],
              );
            },
          ),
          onPressed: () {
            context.read<AppViewModel>().toggleThemeMode();
          },
        ),
      ],
    );
  }
}
