import 'dart:async';

import 'package:flutter/material.dart';

enum ActionButtonType { cancel, ok }

class ActionProps {
  const ActionProps({
    required this.text,
    this.textStyle,
    this.onPressed,
    this.type = ActionButtonType.ok,
    this.autoClose = true,
    this.contentBuilder,
  });
  final Future<void> Function(BuildContext context)? onPressed;
  final String text;
  final TextStyle? textStyle;
  final bool autoClose;
  final Widget Function(String text, TextStyle styles)? contentBuilder;

  final ActionButtonType type;
}

Future<ActionButtonType> showAppDialog(
  BuildContext context, {
  String? title,
  String? message,
  List<ActionProps>? actions,
  List<Widget> Function(BuildContext context)? childrenBuilder,
  Widget? Function(Completer<ActionButtonType> completer)? contentBuilder,
}) async {
  // TODO:

  return ActionButtonType.ok;
}
