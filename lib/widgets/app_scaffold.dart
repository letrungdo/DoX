import 'package:flutter/material.dart';

/// The [Scaffold] every page in the app is built on.
///
/// The device is free to rotate, and in landscape the display cutout and the
/// rounded corners move to the *sides* — where neither [Scaffold] nor [AppBar]
/// inset anything on their own. So this wraps both the body and the app bar's
/// contents in a horizontal [SafeArea]: text and buttons stop at the notch,
/// while the bar keeps painting its background edge to edge behind it.
///
/// Pages that own the whole screen (a video player, a camera preview) should
/// keep using a bare [Scaffold]; everything else goes through here so the
/// insets, and any later change to them, stay in one place.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    this.appBar,
    this.body,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.backgroundColor,
    this.resizeToAvoidBottomInset,
    this.extendBody = false,
    this.extendBodyBehindAppBar = false,
    this.top = false,
    this.bottom = false,
    this.bodyHorizontal = true,
  });

  final PreferredSizeWidget? appBar;
  final Widget? body;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Color? backgroundColor;
  final bool? resizeToAvoidBottomInset;
  final bool extendBody;
  final bool extendBodyBehindAppBar;

  /// Inset the body below the status bar. Only needed on a page without an
  /// [appBar]; the bar already reserves that space.
  final bool top;

  /// Inset the body above the home indicator. Off by default so a scrollable
  /// body can run to the bottom edge; turn it on for a page whose content is
  /// pinned there.
  final bool bottom;

  /// Inset the body past a side notch. Turn it off when the body is itself a
  /// full page (a nested navigator, a tab host): the inner page applies its own
  /// insets, and consuming them here would leave its app bar short of the edge.
  final bool bodyHorizontal;

  @override
  Widget build(BuildContext context) {
    final body = this.body;
    final appBar = this.appBar;

    return Scaffold(
      appBar: appBar == null ? null : _HorizontalSafeAppBar(child: appBar),
      backgroundColor: backgroundColor,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      extendBody: extendBody,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      bottomNavigationBar: bottomNavigationBar == null
          ? null
          : SafeArea(top: false, bottom: false, child: bottomNavigationBar!),
      body: body == null
          ? null
          : SafeArea(
              top: top,
              bottom: bottom,
              left: bodyHorizontal,
              right: bodyHorizontal,
              child: body,
            ),
    );
  }
}

/// Keeps an app bar's contents clear of a side notch without leaving a gap of
/// scaffold colour beside it: the bar's own background is painted across the
/// full width first, and only the child is inset.
class _HorizontalSafeAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const _HorizontalSafeAppBar({required this.child});

  final PreferredSizeWidget child;

  @override
  Size get preferredSize => child.preferredSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final padding = MediaQuery.paddingOf(context);
    if (padding.left == 0 && padding.right == 0) return child;

    return ColoredBox(
      color: theme.appBarTheme.backgroundColor ?? theme.scaffoldBackgroundColor,
      child: SafeArea(top: false, bottom: false, child: child),
    );
  }
}
