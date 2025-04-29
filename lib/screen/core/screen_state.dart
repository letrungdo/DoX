import 'package:do_x/view_model/core/core_view_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

abstract class ProviderWrapper {
  Widget providerWrapper();
}

abstract class StatefulScreen extends StatefulWidget {
  const StatefulScreen({super.key});
}

/// Only use for level Screen
abstract class ScreenState<S extends StatefulScreen, V extends CoreViewModel> extends State<S> {
  V get vm => context.read<V>();

  @mustCallSuper
  void initData() {
    vm.initData();
  }

  @override
  void initState() {
    super.initState();
    vm.setCurrentContext(context);
    vm.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      initData();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    vm.setCurrentContext(context);
  }
}
