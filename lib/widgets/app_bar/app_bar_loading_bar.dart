import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// A thin progress bar for the [DoAppBar.bottom] slot. It watches [T] and shows
/// a [LinearProgressIndicator] while [selector] is true, reserving 2px height so
/// the layout doesn't jump when it toggles.
class AppBarLoadingBar<T extends ChangeNotifier> extends StatelessWidget
    implements PreferredSizeWidget {
  const AppBarLoadingBar({super.key, required this.selector});

  final bool Function(T vm) selector;

  @override
  Size get preferredSize => const Size.fromHeight(2);

  @override
  Widget build(BuildContext context) {
    return Selector<T, bool>(
      selector: (_, vm) => selector(vm),
      builder: (context, isLoading, _) => isLoading
          ? const LinearProgressIndicator(minHeight: 2)
          : const SizedBox(height: 2),
    );
  }
}
