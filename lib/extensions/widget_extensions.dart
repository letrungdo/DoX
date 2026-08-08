import 'package:do_x/constants/dimens.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

extension WidgetExt on Widget {
  Widget expaned(int flex) {
    return Expanded(flex: flex, child: this);
  }

  /// Caps a dialog's width so it does not stretch across a desktop window.
  ///
  /// The [Center] is not decoration: a dialog page hands its child tight
  /// full-screen constraints, and a lone [ConstrainedBox] enforces its own
  /// limits against those, which makes it a no-op. Centring loosens them first.
  Widget dialogConstrainedBox({double maxWidth = Dimens.dialogMaxWidth}) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth), //
        child: this,
      ),
    );
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
