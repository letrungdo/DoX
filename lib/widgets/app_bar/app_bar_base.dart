import 'package:do_x/constants/dimens.dart';
import 'package:flutter/material.dart';

class DoAppBar extends StatefulWidget implements PreferredSizeWidget {
  const DoAppBar({
    super.key,
    this.title, //
    this.titleStyle,
    this.titleSuffix,
    this.onTitleTap,
    this.subtitle,
    this.titleMaxLines = 1,
    this.height = Dimens.appBarHeight,
    this.leading,
    this.leadingWidth,
    this.actions,
    this.backgroundColor,
    this.bottom,
  });
  final String? title;

  /// Overrides the default app bar title style, e.g. a smaller font so a long
  /// title still fits [titleMaxLines].
  final TextStyle? titleStyle;

  /// `null` shows the whole title, wrapping over as many lines as needed.
  final int? titleMaxLines;

  /// Sits right after [title], e.g. an `AppBarSyncIcon` that spins while data
  /// is being fetched.
  final Widget? titleSuffix;

  /// Makes the title block tappable, for a screen whose title doubles as the
  /// entry point to a picker.
  final VoidCallback? onTitleTap;

  /// Displayed below the [title].
  final Widget? subtitle;

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
  Size get preferredSize => Size.fromHeight(height + (bottom?.preferredSize.height ?? 0));
}

class _DoAppBarState extends State<DoAppBar> {
  @override
  Widget build(BuildContext context) {
    final title = widget.title;
    final titleSuffix = widget.titleSuffix;
    final subtitle = widget.subtitle;

    Widget? titleWidget;
    if (title != null) {
      titleWidget = Text(
        title,
        style: widget.titleStyle,
        maxLines: widget.titleMaxLines,
        overflow: widget.titleMaxLines == null ? TextOverflow.clip : TextOverflow.ellipsis,
      );

      if (titleSuffix != null) {
        titleWidget = Row(
          spacing: 8,
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: titleWidget),
            titleSuffix,
          ],
        );
      }

      if (subtitle != null) {
        titleWidget = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [titleWidget, subtitle],
        );
      }

      if (widget.onTitleTap != null) {
        titleWidget = GestureDetector(behavior: HitTestBehavior.opaque, onTap: widget.onTitleTap, child: titleWidget);
      }
    }

    return AppBar(
      backgroundColor: widget.backgroundColor,
      title: titleWidget,
      leading: widget.leading,
      leadingWidth: widget.leadingWidth,
      // AppBar stretches actions to the full toolbar height, which pushes a
      // neumorphic button's shadow past the bar; centring keeps it intact.
      actions: widget.actions?.map((action) => Center(child: action)).toList(),
      toolbarHeight: widget.height,
      actionsPadding: const EdgeInsets.only(right: 10),
      bottom: widget.bottom,
    );
  }
}
