import 'package:do_x/constants/dimens.dart';
import 'package:flutter/material.dart';

extension WidgetExt on Widget {
  Widget expaned(int flex) {
    return Expanded(flex: flex, child: this);
  }

  /// Caps a page's content at [Dimens.contentMaxWidth] and centres it, so every
  /// screen keeps the same column width — on the web, and on a phone turned
  /// landscape, where the extra width is margin rather than content.
  ///
  /// Aligned to the *top*, not the centre: a `SingleChildScrollView` handed a
  /// loose height shrink-wraps its content, so a page whose content is shorter
  /// than the screen would otherwise float in the middle of it.
  Widget contentConstrainedBox() {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: Dimens.contentMaxWidth), //
        child: this,
      ),
    );
  }
}
