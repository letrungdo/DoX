import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/utils/image_edit.dart';
import 'package:do_x/utils/logger.dart';
import 'package:do_x/view_model/core/core_view_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

/// State of the image editor page.
///
/// Two kinds of edit live here, and they behave differently on purpose:
///
/// * **Geometry** (crop, rotate, flip) rewrites [image] as soon as it is
///   applied, because the crop UI and the preview both need real pixels to work
///   from. Each one pushes the previous bytes onto [_history], which is what
///   [undo] pops.
/// * **Colour** ([adjustments]) is never baked into [image]. It rides along as
///   a matrix the preview draws with and the export applies once, so dragging a
///   slider costs nothing and never degrades the picture.
class ImageEditorViewModel extends CoreViewModel {
  final _picker = ImagePicker();

  /// Undo depth. Each entry is a full-size PNG, so this is a memory budget as
  /// much as a usability one.
  static const _maxHistory = 6;

  final _history = <Uint8List>[];

  Uint8List? _original;
  Uint8List? _image;

  /// The picture every edit is applied to, already downscaled on load.
  Uint8List? get image => _image;

  bool get hasImage => _image != null;

  ImageAdjustments _adjustments = ImageAdjustments.none;
  ImageAdjustments get adjustments => _adjustments;

  /// The matrix the preview draws with — the same one the export bakes in.
  List<double> get previewMatrix => _adjustments.matrix;

  bool _isProcessing = false;

  /// A pass is running in a background isolate; the page blocks input while it
  /// does, since every one of them replaces the picture under the user.
  bool get isProcessing => _isProcessing;

  bool get canUndo => _history.isNotEmpty;

  bool get hasEdits => _history.isNotEmpty || !_adjustments.isIdentity;

  Future<void> pickImage(ImageSource source) async {
    final l10n = context.l10n;
    try {
      final picked = await _picker.pickImage(source: source);
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      _setProcessing(true);
      final prepared = await compute(
        prepareSource,
        ImageLoadRequest(bytes: bytes),
      );
      _setProcessing(false);
      if (prepared == null) {
        _showError(l10n.imageOpenFailed);
        return;
      }
      _original = prepared;
      _image = prepared;
      _history.clear();
      _adjustments = ImageAdjustments.none;
      notifyListenersSafe();
    } catch (e, stack) {
      _setProcessing(false);
      logger.e('pickImage failed: $e', error: e, stackTrace: stack);
      _showError(l10n.imageOpenFailed);
    }
  }

  Future<void> applyGeometryOp(ImageGeometryOp op) async {
    final source = _image;
    if (source == null || _isProcessing) return;
    final l10n = context.l10n;
    _setProcessing(true);
    final result = await compute(
      applyGeometry,
      ImageGeometryRequest(bytes: source, op: op),
    );
    _setProcessing(false);
    if (result == null) {
      _showError(l10n.imageEditFailed);
      return;
    }
    _commit(result);
  }

  /// Takes the bytes the crop widget produced as the new picture.
  void applyCrop(Uint8List cropped) => _commit(cropped);

  void setBrightness(double value) =>
      _setAdjustments(_adjustments.copyWith(brightness: value));

  void setContrast(double value) =>
      _setAdjustments(_adjustments.copyWith(contrast: value));

  void setSaturation(double value) =>
      _setAdjustments(_adjustments.copyWith(saturation: value));

  void setPreset(ImageFilterPreset preset) =>
      _setAdjustments(_adjustments.copyWith(preset: preset));

  /// Drops the three sliders back to neutral, leaving the chosen preset and the
  /// geometry alone.
  void resetAdjustments() =>
      _setAdjustments(ImageAdjustments(preset: _adjustments.preset));

  void undo() {
    if (_history.isEmpty) return;
    _image = _history.removeLast();
    notifyListenersSafe();
  }

  /// Back to the picture as it was picked, sliders and all.
  void resetAll() {
    final original = _original;
    if (original == null) return;
    _history.clear();
    _image = original;
    _adjustments = ImageAdjustments.none;
    notifyListenersSafe();
  }

  /// Renders the edit at full size and hands the JPEG to the share sheet.
  ///
  /// [origin] anchors the iPad popover, which has nothing to point at
  /// otherwise; pass the render box of the button that opened it.
  Future<void> save({Rect? origin}) async {
    final source = _image;
    if (source == null || _isProcessing) return;
    final l10n = context.l10n;

    _setProcessing(true);
    final Uint8List? rendered;
    try {
      rendered = await compute(
        renderEdited,
        ImageRenderRequest(bytes: source, matrix: previewMatrix),
      );
    } catch (e, stack) {
      _setProcessing(false);
      logger.e('save render failed: $e', error: e, stackTrace: stack);
      _showError(l10n.imageEditFailed);
      return;
    }
    _setProcessing(false);
    if (rendered == null) {
      _showError(l10n.imageEditFailed);
      return;
    }

    final name = 'edited-${DateTime.now().millisecondsSinceEpoch}.jpg';
    try {
      final result = await SharePlus.instance.share(
        ShareParams(
          subject: name,
          files: [XFile.fromData(rendered, mimeType: 'image/jpeg', name: name)],
          fileNameOverrides: [name],
          sharePositionOrigin: origin,
        ),
      );
      // A dismissed sheet is the user changing their mind, not a save.
      if (result.status != ShareResultStatus.success) return;
      if (!context.mounted) return;
      context.showToast(l10n.imageSaved);
    } catch (e, stack) {
      logger.e('share failed: $e', error: e, stackTrace: stack);
      _showError(l10n.imageSaveFailed);
    }
  }

  void _commit(Uint8List bytes) {
    final current = _image;
    if (current != null) {
      _history.add(current);
      if (_history.length > _maxHistory) _history.removeAt(0);
    }
    _image = bytes;
    notifyListenersSafe();
  }

  void _setAdjustments(ImageAdjustments value) {
    _adjustments = value;
    notifyListenersSafe();
  }

  void _setProcessing(bool value) {
    _isProcessing = value;
    notifyListenersSafe();
  }

  void _showError(String message) {
    if (!context.mounted) return;
    context.showToast(message, isError: true);
  }
}
