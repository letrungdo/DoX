import 'package:do_x/services/update_controller.dart';
import 'package:do_x/services/update_service.dart';
import 'package:do_x/view_model/core/core_view_model.dart';

class MainViewModel extends CoreViewModel {
  final Map<String, Future<void> Function()> _tabReselectHandlers = {};
  final Set<String> _tabsBeingReselected = {};

  void registerTabReselectHandler(
    String routeName,
    Future<void> Function() handler,
  ) {
    _tabReselectHandlers[routeName] = handler;
  }

  void unregisterTabReselectHandler(
    String routeName,
    Future<void> Function() handler,
  ) {
    if (identical(_tabReselectHandlers[routeName], handler)) {
      _tabReselectHandlers.remove(routeName);
    }
  }

  Future<void> handleTabReselect(String routeName) async {
    if (!_tabsBeingReselected.add(routeName)) return;
    try {
      await _tabReselectHandlers[routeName]?.call();
    } finally {
      _tabsBeingReselected.remove(routeName);
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
