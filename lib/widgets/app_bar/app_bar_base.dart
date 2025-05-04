import 'package:do_x/constants/dimens.dart';
import 'package:flutter/material.dart';

class DoAppBar extends StatefulWidget implements PreferredSizeWidget {
  const DoAppBar({
    super.key,
    this.title, //
    this.height = Dimens.appBarHeight,
    this.leading,
    this.leadingWidth,
  });
  final String? title;
  final double height;
  final Widget? leading;
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
      // backgroundColor: Theme.of(context).colorScheme.inversePrimary, //
      title: widget.title != null ? Text(widget.title!) : null,
      leading: widget.leading,
      leadingWidth: widget.leadingWidth,
    );
  }
}
