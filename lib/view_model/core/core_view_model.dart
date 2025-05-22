import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/view_model/mixin/app_error.mixin.dart';
import 'package:do_x/view_model/mixin/cancel_future.mixin.dart';
import 'package:do_x/widgets/dialog/src/dialog_helper.dart';
import 'package:do_x/widgets/dialog/src/dialog_widget.dart';
import 'package:do_x/widgets/loading.dart';
import 'package:flutter/material.dart';

abstract class CoreViewModel with ChangeNotifier, CancelRequestMixin, AppErrorMixin {
  late BuildContext context;

  bool _isDispose = false;
  bool get isDispose => _isDispose;

  bool _isBusy = false;
  bool get isBusy => _isBusy;

  void setBusy(bool value) {
    _isBusy = value;
    notifyListenersSafe();
  }

  void showLoading() {
    final id = context.loadingId;
    if (DialogHelper().isExists(id)) {
      return;
    }
    DialogHelper().show(
      id: id, //
      context,
      rootOverlay: true,
      DialogWidget.custom(closable: false, child: const Loading()),
    );
  }

  void hideLoading() {
    return DialogHelper().hideImmediate(
      context, //
      id: context.loadingId,
      rootOverlay: true,
    );
  }

  void setCurrentContext(BuildContext context) {
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
