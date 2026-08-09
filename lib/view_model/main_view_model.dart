import 'package:do_x/services/update_controller.dart';
import 'package:do_x/services/update_service.dart';
import 'package:do_x/view_model/core/core_view_model.dart';

/// What a tab screen offers the bottom bar: [reselect] applies the shared
/// re-tap rule (scroll to top, or refresh when already there), while [refresh]
/// reloads unconditionally — which is what switching *into* a tab wants, at
/// whatever scroll position the user left it.
typedef TabHandlers = ({
  Future<void> Function() reselect,
  Future<void> Function() refresh,
});

class MainViewModel extends CoreViewModel {
  final Map<String, TabHandlers> _tabHandlers = {};
  final Set<String> _tabsBeingHandled = {};

  void registerTabHandlers(String routeName, TabHandlers handlers) {
    _tabHandlers[routeName] = handlers;
  }

  void unregisterTabHandlers(String routeName, TabHandlers handlers) {
    final registered = _tabHandlers[routeName];
    if (registered != null &&
        identical(registered.reselect, handlers.reselect)) {
      _tabHandlers.remove(routeName);
    }
  }

  /// The user tapped the tab they are already on.
  Future<void> handleTabReselect(String routeName) {
    return _run(routeName, (handlers) => handlers.reselect());
  }

  /// The user switched to another tab, which re-fetches that tab's data.
  Future<void> handleTabSwitch(String routeName) {
    return _run(routeName, (handlers) => handlers.refresh());
  }

  /// One tap at a time per tab: a second one while the first is still running
  /// would fire a duplicate request or fight the scroll animation.
  Future<void> _run(
    String routeName,
    Future<void> Function(TabHandlers handlers) action,
  ) async {
    final handlers = _tabHandlers[routeName];
    if (handlers == null) return;
    if (!_tabsBeingHandled.add(routeName)) return;
    try {
      await action(handlers);
    } finally {
      _tabsBeingHandled.remove(routeName);
    }
  }

  @override
  void initData() {
    super.initData();
    _initAppUpdate();
  }

  void _initAppUpdate() async {
    // Resume any download interrupted by a previous app kill first, so the
    // toast reappears (and continues) right away — even while offline.
    await updateController.init();

    // Then check the network for the latest release and reconcile: if a newer
    // version than the one being resumed exists, the stale partial download is
    // discarded and the newer one starts; otherwise the resume continues.
    // When nothing was resumed, this simply starts the newly found update.
    final latest = await updateService.checkForUpdate();
    await updateController.reconcile(latest);
  }
}
