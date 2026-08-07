import 'package:do_x/constants/dimens.dart';
import 'package:flutter/material.dart';

class DoAppBar extends StatefulWidget implements PreferredSizeWidget {
  const DoAppBar({
    super.key,
    this.title, //
    this.titleSuffix,
    this.titleMaxLines = 1,
    this.height = Dimens.appBarHeight,
    this.leading,
    this.leadingWidth,
    this.actions,
    this.backgroundColor,
    this.bottom,
  });
  final String? title;
  final int titleMaxLines;

  /// Sits right after [title], e.g. an `AppBarSyncIcon` that spins while data
  /// is being fetched.
  final Widget? titleSuffix;
  final double height;
  final Widget? leading;
  final List<Widget>? actions;
  final Color? backgroundColor;
  final PreferredSizeWidget? bottom;

  /// Default 56
  final double? leadingWidth;

  @override
  State<DoAppBar> createState() => _DoAppBarState();

  @override
  Size get preferredSize =>
      Size.fromHeight(height + (bottom?.preferredSize.height ?? 0));
}

class _DoAppBarState extends State<DoAppBar> {
  @override
  Widget build(BuildContext context) {
    final title = widget.title;
    final titleSuffix = widget.titleSuffix;
    return AppBar(
      backgroundColor: widget.backgroundColor,
      title: title == null
          ? null
          : titleSuffix == null
          ? Text(
              title,
              maxLines: widget.titleMaxLines,
              overflow: TextOverflow.ellipsis,
            )
          : Row(
              spacing: 8,
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    title,
                    maxLines: widget.titleMaxLines,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                titleSuffix,
              ],
            ),
      leading: widget.leading,
      leadingWidth: widget.leadingWidth,
      actions: widget.actions,
      toolbarHeight: widget.height,
      actionsPadding: const EdgeInsets.only(right: 10),
      bottom: widget.bottom,
    );
  }
}
