import 'package:do_x/constants/dimens.dart';
import 'package:flutter/material.dart';

class DoAppBar extends StatefulWidget implements PreferredSizeWidget {
  const DoAppBar({
    super.key,
    this.title, //
    this.height = Dimens.appBarHeight,
    this.leading,
    this.leadingWidth,
    this.actions,
    this.backgroundColor,
  });
  final String? title;
  final double height;
  final Widget? leading;
  final List<Widget>? actions;
  final Color? backgroundColor;

  /// Default 56
  final double? leadingWidth;

  @override
  State<DoAppBar> createState() => _DoAppBarState();

  @override
  Size get preferredSize => Size.fromHeight(height);
}

class _DoAppBarState extends State<DoAppBar> {
  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: widget.backgroundColor,
      title: widget.title != null ? Text(widget.title!) : null,
      leading: widget.leading,
      leadingWidth: widget.leadingWidth,
      actions: widget.actions,
      toolbarHeight: widget.height,
      actionsPadding: EdgeInsets.only(right: 10),
    );
  }
}
