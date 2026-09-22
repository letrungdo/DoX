import 'package:auto_route/auto_route.dart';
import 'package:do_x/utils/device_type.dart';
import 'package:do_x/view_model/core/core_view_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

abstract class StatefulScreen extends StatefulWidget {
  const StatefulScreen({super.key});
}

/// Only use for level Screen
abstract class ScreenState<S extends StatefulScreen, V extends CoreViewModel>
    extends State<S>
    with WidgetsBindingObserver {
  V get vm => context.read<V>();

  @mustCallSuper
  void initData() {
    vm.initData();
  }

  /// Called when the app returns to the foreground *and* this screen is the one
  /// currently visible to the user. Override to re-fetch the screen's data
  /// (e.g. `vm.ensureLoaded()`).
  void onResume() {}

  @override
  void initState() {
    super.initState();
    vm.setCurrentContext(context);
    vm.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      initData();
      _setUpRemoteNavigation();
    });
  }

  /// Makes this screen navigable with a TV remote. Two separate problems.
  ///
  /// **Letting the D-pad out of the page.** A route's focus scope defaults to
  /// [TraversalEdgeBehavior.stop], so directional focus dies at the scope's
  /// edge. A tab's page is a route inside the tab shell's nested navigator,
  /// while the tab rail belongs to the shell outside it — so pressing left from
  /// an article does nothing at all, and the tabs are unreachable for as long as
  /// the app is open. [TraversalEdgeBehavior.parentScope] lets the search carry
  /// on into the scope that holds both.
  ///
  /// **Pointing the remote at the right page.** Flutter does not decide this
  /// for us, and when it decides wrong there is no way back: pushing the login
  /// screen over the tab shell leaves the *tab's* nested route as the focused
  /// scope, so every press walks the page hidden underneath and the login form
  /// can never be reached. Nothing looks wrong — the focus is simply somewhere
  /// the user cannot see.
  ///
  /// A page pushed *inside* a tab — a market from the news list, a batch from
  /// the flock — has the same problem the other way round. The control the
  /// viewer pressed goes out of the focus tree with the page it was on, focus
  /// falls back to the scope it sat in, and no arrow key finds anything from
  /// there: the new page is on screen with a dead remote, and nothing on it
  /// can be reached or scrolled to. So every page claims the remote, not only
  /// the ones on the root navigator — and whether another page covers this one
  /// is read from the focus tree instead of from the navigator it belongs to.
  /// [AppScaffold] takes a covered page out of that tree, which is the same
  /// answer for a tab's page under a pushed login screen as for a tab's page
  /// under another page of its own tab.
  void _setUpRemoteNavigation() {
    if (!mounted || !deviceType.isTv) return;
    final scope = FocusScope.of(context);
    scope.directionalTraversalEdgeBehavior = TraversalEdgeBehavior.parentScope;

    final route = ModalRoute.of(context);
    if (route == null || !route.isCurrent) return;
    // Covered by a page somewhere above this one, which has the remote.
    if (!scope.canRequestFocus) return;
    scope.requestFocus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && _isCurrentlyVisible) {
      onResume();
    }
  }

  /// Whether this screen is the one on screen right now: it must be the topmost
  /// route in its navigator (no page pushed on top) and sit on the active
  /// navigation path (its tab is selected). Prevents background tabs and
  /// covered screens from reloading on resume.
  bool get _isCurrentlyVisible {
    if (!mounted) return false;
    final modalRoute = ModalRoute.of(context);
    if (modalRoute != null && !modalRoute.isCurrent) return false;
    return RouteData.of(context).isActive;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    vm.setCurrentContext(context);
  }
}
