import 'package:do_x/view_model/main_view_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Lets a screen react to its bottom tab being tapped again (scroll to top,
/// refresh…).
///
/// The same screen can also be opened from the menu, and a menu page is pushed
/// on the root stack — above [MainViewModel]'s provider, not inside it. Hence
/// the nullable lookup: no bottom tab to re-tap, nothing to register.
mixin TabReselect<S extends StatefulWidget> on State<S> {
  MainViewModel? _mainViewModel;

  /// Resolved once, so register and unregister pass the same closure.
  late final Future<void> Function() _handler = onTabReselect;

  /// Route name of the tab this screen backs, e.g. `NewsRoute.name`.
  String get tabRouteName;

  Future<void> onTabReselect();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final mainViewModel = context.read<MainViewModel?>();
    if (identical(_mainViewModel, mainViewModel)) return;
    _mainViewModel?.unregisterTabReselectHandler(tabRouteName, _handler);
    _mainViewModel = mainViewModel;
    mainViewModel?.registerTabReselectHandler(tabRouteName, _handler);
  }

  @override
  void dispose() {
    _mainViewModel?.unregisterTabReselectHandler(tabRouteName, _handler);
    super.dispose();
  }
}
