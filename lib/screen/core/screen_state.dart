import 'package:auto_route/auto_route.dart';
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
  /// (e.g. `vm.ensureBatchesLoaded()`).
  void onResume() {}

  @override
  void initState() {
    super.initState();
    vm.setCurrentContext(context);
    vm.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      initData();
    });
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
