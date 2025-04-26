import 'package:flutter/material.dart';

class AppScaffold extends Scaffold {
  const AppScaffold({
    super.key,
    super.appBar,
    this.child,
    super.backgroundColor,
    super.bottomNavigationBar,
  }) : super(
          body: child,
        );

  final Widget? child;
}
