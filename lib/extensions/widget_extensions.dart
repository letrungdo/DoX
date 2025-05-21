import 'package:do_x/constants/dimens.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

extension WidgetExt on Widget {
  Widget expaned(int flex) {
    return Expanded(flex: flex, child: this);
  }

  Widget webConstrainedBox() {
    if (kIsWeb) {
      return Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: Dimens.webMaxWidth), //
          child: this,
        ),
      );
    }
    return this;
  }
}
