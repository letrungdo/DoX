import 'package:auto_route/auto_route.dart';
import 'package:do_x/constants/enum/app_page.dart';
import 'package:do_x/router/app_router.dart';
import 'package:do_x/router/app_router.gr.dart';
import 'package:do_x/services/notification_service.dart';
import 'package:do_x/services/storage_service.dart';
import 'package:do_x/view_model/app_view_model.dart';
import 'package:do_x/view_model/chicken_view_model.dart';
import 'package:flutter/widgets.dart';

/// Turns a tapped notification into the screen it promised.
///
/// Lives next to the router rather than in the app widget: what a notification
/// opens is a routing decision, and every kind of them — local reminder or
/// push, tapped while the app runs or the tap that launched it — arrives here
/// through a notifier on [NotificationService] and leaves through [appRouter].
class NotificationRouting {
  NotificationRouting({required this.appVm, required this.chickenVm});

  final AppViewModel appVm;
  final ChickenViewModel chickenVm;

  void start() {
    notificationService.electricNotificationMonth.addListener(_openElectric);
    notificationService.sharedActivityOwnerId.addListener(_openSharedChicken);

    // The notification that launched the app is read asynchronously, so it can
    // land either side of the listeners above.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _openElectric();
      _openSharedChicken();
    });
  }

  void dispose() {
    notificationService.electricNotificationMonth.removeListener(_openElectric);
    notificationService.sharedActivityOwnerId.removeListener(
      _openSharedChicken,
    );
  }

  /// The monthly reminder opens the electricity page on the month it is about.
  void _openElectric() {
    final month = notificationService.electricNotificationMonth.value;
    if (month == null) return;
    notificationService.electricNotificationMonth.value = null;

    appVm.requestElectricMonth(month);
    _afterFrame(() => showPage(AppPage.electric, const ElectricRoute()));
  }

  /// A shared-activity push opens the chicken page on the data of the account
  /// that recorded the sale or the expense.
  void _openSharedChicken() {
    final ownerId = notificationService.sharedActivityOwnerId.value;
    if (ownerId == null) return;
    notificationService.sharedActivityOwnerId.value = null;

    _afterFrame(() {
      showPage(AppPage.chicken, const ChickenRoute());
      // After the navigation, so the page is already on screen while the
      // owner's records load in behind it.
      chickenVm.selectOwner(ownerId);
    });
  }

  /// Runs [action] once the frame in progress is done — the app can be mid
  /// build when a notification arrives.
  ///
  /// The frame has to be *asked for*: an app sitting idle in the foreground,
  /// which is exactly where a tapped banner finds it, draws no frames at all,
  /// so a plain post-frame callback would wait until something else woke the
  /// engine up — in practice the next time the app was resumed.
  void _afterFrame(VoidCallback action) {
    WidgetsBinding.instance.addPostFrameCallback((_) => action());
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  /// Brings [page] to the front from wherever the app was. Never stacks a
  /// second copy of a page already open.
  ///
  /// A page is a tab only while the user keeps it in the bottom bar, otherwise
  /// it lives in the menu and is pushed. Switching tab goes through the tabs
  /// router, the way the bottom bar itself does: a tab can be a child of a
  /// shell route, which `navigate` resolves to the root-stack copy of the page
  /// instead of to the tab.
  @protected
  @visibleForTesting
  void showPage(AppPage page, PageRouteInfo route) {
    final index = appVm.visibleTabs.indexOf(page);
    final tabsRouter = appRouter.innerRouterOf<TabsRouter>(MainRoute.name);
    if (index < 0 || tabsRouter == null) {
      // From the menu the page is pushed — unless it is already open, in which
      // case come back to it rather than stack a second copy of it.
      if (appRouter.stackData.any((data) => data.name == route.routeName)) {
        appRouter.popUntilRouteWithName(route.routeName);
      } else {
        appRouter.push(route);
      }
      return;
    }

    storageService.setActiveTabPage(page.name);
    // Anything sitting on top of the bottom bar — a pushed page, a settings
    // screen — would otherwise hide the tab we just switched to.
    appRouter.popUntilRouteWithName(MainRoute.name);
    tabsRouter.setActiveIndex(index);
    // A tab keeps its own stack, so it can still be showing a detail page from
    // last time.
    tabsRouter.stackRouterOfIndex(index)?.popUntilRoot();
  }
}
