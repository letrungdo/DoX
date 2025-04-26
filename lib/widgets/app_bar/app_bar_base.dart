import 'package:do_ai/constants/dimens.dart';
import 'package:flutter/material.dart';

class DoAppBar extends StatefulWidget implements PreferredSizeWidget {
  const DoAppBar({
    super.key,
    required this.title, //
    this.height = Dimens.appBarHeight,
  });
  final String title;
  final double height;

  @override
  State<DoAppBar> createState() => _DoAppBarState();

  @override
  Size get preferredSize => Size.fromHeight(height);
}

class _DoAppBarState extends State<DoAppBar> {
  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Theme.of(context).colorScheme.inversePrimary, //
      title: Text(widget.title),
    );
  }
}
