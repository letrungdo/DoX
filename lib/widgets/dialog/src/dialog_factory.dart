import 'package:flutter/cupertino.dart';

// Platform dialog factory
abstract class DialogFactory {
  factory DialogFactory() {
    return _CupertinoDialogFactory();
  }

  Widget progress();

  Widget custom(
    Widget child, {
    required Map<String, double?>? position,
  });
}

class _CupertinoDialogFactory implements DialogFactory {
  @override
  Widget progress() {
    return const Center(
      child: CupertinoActivityIndicator(animating: true),
    );
  }

  @override
  Widget custom(
    Widget child, {
    required Map<String, double?>? position,
  }) {
    if (position != null) {
      return Stack(
        children: [
          Positioned(
            top: position['top'],
            left: position['left'],
            bottom: position['bottom'],
            right: position['right'],
            child: child,
          )
        ],
      );
    }
    return Center(
      child: child,
    );
  }
}
