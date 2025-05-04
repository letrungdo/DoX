import 'package:flutter/widgets.dart';

import 'dialog_factory.dart';

/// Represents dialog in Material or Cupertino style,
/// adaptive dialog chooses style depends on platform
///
/// closable flag allows to hide dialog by back press or touch outside
class DialogWidget extends StatelessWidget {
  final bool closable;
  final Widget widget;
  final bool isModal;

  DialogWidget.progress({
    super.key,
    this.closable = false,
    this.isModal = false,
  }) : widget = DialogFactory().progress();

  DialogWidget.custom({
    super.key,
    required Widget child,
    this.closable = true,
    this.isModal = false,
    Map<String, double?>? position,
  }) : widget = DialogFactory().custom(child, position: position);

  DialogWidget.modal({
    super.key,
    required Widget child,
    this.closable = false,
    this.isModal = true,
    Map<String, double?>? position,
  }) : widget = DialogFactory().custom(child, position: position);

  @override
  Widget build(BuildContext context) {
    return widget;
  }
}
