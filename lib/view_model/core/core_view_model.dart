import 'package:do_x/view_model/mixin/app_error.mixin.dart';
import 'package:do_x/view_model/mixin/cancel_future.mixin.dart';
import 'package:flutter/material.dart';

abstract class CoreViewModel with ChangeNotifier, CancelRequestMixin, AppErrorMixin {
  late BuildContext context;

  bool _isDispose = false;
  bool get isDispose => _isDispose;

  void setCurrentContext(BuildContext context, [GlobalKey? gkey]) {
    this.context = context;
  }

  void notifyInInitState() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListenersSafe();
    });
  }

  void notifyListenersSafe() {
    if (!isDispose) {
      notifyListeners();
    }
  }

  /// Invoke after ui render
  @mustCallSuper
  void initData() async {}

  @mustCallSuper
  void initState() async {}

  @override
  void dispose() {
    _isDispose = true;
    cancelRequest("dispose");
    super.dispose();
  }
}
