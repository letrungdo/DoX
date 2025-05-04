// ignore_for_file: deprecated_member_use

import 'dart:async';

import 'package:do_x/extensions/string_extensions.dart';
import 'package:do_x/widgets/dialog/src/dialog_widget.dart';
import 'package:flutter/material.dart';

import 'animation/appear_widget.dart';

///Helper class to handle dialog appearance
///Keeps the latest dialog and closes the previous dialog automatically
class DialogHelper {
  static const Duration defaultDuration = Duration(milliseconds: 100);

  static final DialogHelper _instance = DialogHelper._();

  factory DialogHelper() => _instance;

  DialogHelper._();

  final List<IndexedData<OverlayEntry>> currentOverlay = [];

  // Shows the dialog
  void show(
    BuildContext context,
    DialogWidget dialog, {
    bool rootOverlay = true,
    bool isWindowDialog = false,

    /// Id should be the hashcode of the context
    required String id,
    bool hidePrevious = false,
    Color overlayColor = const Color.fromRGBO(0, 0, 0, 0.5),
    VoidCallback? onClose,
  }) {
    if (hidePrevious) {
      hideImmediate(context, id: id, rootOverlay: rootOverlay);
    }
    final overlayState = Overlay.of(context, rootOverlay: rootOverlay);
    final StreamController<double> controller = StreamController();
    final overlayFocusNode = FocusScopeNode();

    void hideInternal() {
      if (!context.mounted) return;
      hide(context, id: id, rootOverlay: rootOverlay).whenComplete(() {
        onClose?.call();
      });
    }

    final OverlayEntry overlayEntry = OverlayEntry(
      builder:
          (_) => Stack(
            children: <Widget>[
              // This ModalBarrier blocks touch and focus interactions with underlying widgets
              AppearWidget(
                progress: controller.stream,
                duration: defaultDuration,
                style: AppearStyle.opacity,
                child: ModalBarrier(
                  color: overlayColor,
                  onDismiss: () async {
                    if (dialog.closable) {
                      hideInternal();
                    }
                  },
                ),
              ),
              dialog,
            ],
          ),
    );
    currentOverlay.add(IndexedData<OverlayEntry>(id: id, data: overlayEntry, controller: controller, isWindowDialog: isWindowDialog));

    overlayState.insert(overlayEntry);
    FocusScope.of(context).requestFocus(overlayFocusNode);
    controller.add(1.0);
  }

  // Hide opened dialog with animation
  Future<void> hide(BuildContext context, {String? id, required bool rootOverlay}) {
    currentOverlay.where((e) => e.id == id || id == null).forEach((e) => e.controller.add(0.0));

    return Future.delayed(defaultDuration)
        .then(
          (_) => _hide(
            // ignore: use_build_context_synchronously
            context,
            id,
            rootOverlay: rootOverlay,
          ),
        )
        .catchError((error) {});
  }

  bool isExists(String id) {
    return currentOverlay.any((controller) => controller.id == id);
  }

  // Hide opened dialog without animation, clear closable callback if any
  void hideImmediate(
    BuildContext context, {
    String? id,
    required bool rootOverlay,
    bool excludeLoading = false,
    bool isMainWindow = false,
  }) {
    _hide(context, id, rootOverlay: rootOverlay, excludeLoading: excludeLoading);
  }

  void _hide(BuildContext context, String? id, {required bool rootOverlay, bool excludeLoading = false}) async {
    currentOverlay.removeWhere((overlay) {
      if (excludeLoading && overlay.id.isLoadingDialog()) {
        return false;
      }
      if (overlay.id == id || id == null) {
        try {
          overlay.data.remove();
        } catch (error) {
          debugPrint(error.toString());
        }
        try {
          overlay.controller.close();
        } catch (error) {
          debugPrint(error.toString());
        }
        return true;
      }

      return false;
    });
  }
}

class IndexedData<T> {
  final String? id;
  final T data;
  final bool? isWindowDialog;
  final StreamController<double> controller;

  const IndexedData({required this.controller, this.id, required this.data, this.isWindowDialog});
}
