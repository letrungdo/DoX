import 'package:do_x/view_model/main_view_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Gives a bottom-tab screen the app's shared "tapped my own tab again"
/// behaviour, so every tab answers a re-tap the same way:
///
/// * the page is **scrolled down** — ride back to the top, and stop there. The
///   user is navigating, not asking for fresh data, and refetching under them
///   would swap the list out mid-scroll.
/// * the page is **already at the top** — there is nowhere to scroll, so the
///   re-tap can only mean "reload this", and [onTabRefresh] runs.
///
/// A screen supplies the two page-specific pieces — [tabScrollController] and
/// [onTabRefresh] — and inherits the rule itself.
///
/// The same screen can also be opened from the menu, and a menu page is pushed
/// on the root stack — above [MainViewModel]'s provider, not inside it. Hence
/// the nullable lookup: no bottom tab to re-tap, nothing to register.
mixin TabReselect<S extends StatefulWidget> on State<S> {
  MainViewModel? _mainViewModel;

  /// Resolved once, so register and unregister pass the same closures.
  late final TabHandlers _handlers = (
    reselect: _handleTabReselect,
    refresh: _refresh,
  );

  static const _scrollToTopDuration = Duration(milliseconds: 250);

  /// Anything within this many pixels of the top counts as "at the top", so a
  /// list resting a hair off zero still refreshes.
  static const _atTopTolerance = 1.0;

  /// True while this screen is showing as a bottom tab, false when the same
  /// page was pushed from the menu instead. Worth checking before offering an
  /// affordance the tab bar already provides — a scroll-to-top button, say,
  /// which re-tapping the tab does anyway.
  bool get isBottomTab => _mainViewModel != null;

  /// Route name of the tab this screen backs, e.g. `NewsRoute.name`.
  String get tabRouteName;

  /// Controller of the page's main scroll view. Leave it null for a page with
  /// nothing to scroll — a re-tap then always refreshes.
  ScrollController? get tabScrollController => null;

  /// Reload the page's data. Only called when the page is already at the top,
  /// so it never has to guard against interrupting a scroll. Defaults to doing
  /// nothing, for a page with no data to refetch.
  Future<void> onTabRefresh() async {}

  Future<void> _handleTabReselect() async {
    final controller = tabScrollController;
    if (controller != null && controller.hasClients) {
      final position = controller.position;
      if (position.pixels > position.minScrollExtent + _atTopTolerance) {
        await controller.animateTo(
          position.minScrollExtent,
          duration: _scrollToTopDuration,
          curve: Curves.easeOut,
        );
        return;
      }
    }
    if (mounted) await onTabRefresh();
  }

  Future<void> _refresh() async {
    if (mounted) await onTabRefresh();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final mainViewModel = context.read<MainViewModel?>();
    if (identical(_mainViewModel, mainViewModel)) return;
    _mainViewModel?.unregisterTabHandlers(tabRouteName, _handlers);
    _mainViewModel = mainViewModel;
    mainViewModel?.registerTabHandlers(tabRouteName, _handlers);
  }

  @override
  void dispose() {
    _mainViewModel?.unregisterTabHandlers(tabRouteName, _handlers);
    super.dispose();
  }
}
