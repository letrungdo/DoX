import 'package:do_x/constants/dimens.dart';
import 'package:do_x/extensions/widget_extensions.dart';
import 'package:flutter/material.dart';

/// The scroll view every asset tab is built on: pull to refresh, and an empty
/// state that is itself scrollable.
///
/// That last part is the whole reason this is shared. A [Center] holding "no
/// records yet" cannot be dragged, so the one moment the user most wants to
/// pull — an empty list they expected to have something in it — is exactly the
/// moment a plain empty state refuses to.
class AssetRefreshableList extends StatelessWidget {
  const AssetRefreshableList({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    required this.emptyMessage,
    this.onRefresh,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final String emptyMessage;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final list = itemCount == 0
        ? LayoutBuilder(
            builder: (context, constraints) => ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: constraints.maxHeight,
                  child: Center(child: Text(emptyMessage)),
                ),
              ],
            ),
          )
        : ListView.builder(
            padding: Dimens.screenPadding,
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: itemCount,
            itemBuilder: (context, index) =>
                itemBuilder(context, index).contentConstrainedBox(),
          );

    final refresh = onRefresh;

    return refresh == null
        ? list
        : RefreshIndicator.adaptive(onRefresh: refresh, child: list);
  }
}
