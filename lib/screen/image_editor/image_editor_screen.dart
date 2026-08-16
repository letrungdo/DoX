import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:auto_route/auto_route.dart';
import 'package:crop_image/crop_image.dart';
import 'package:do_x/constants/dimens.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/screen/core/screen_state.dart';
import 'package:do_x/extensions/widget_extensions.dart';
import 'package:do_x/utils/image_edit.dart';
import 'package:do_x/utils/logger.dart';
import 'package:do_x/view_model/image_editor_view_model.dart';
import 'package:do_x/widgets/app_bar/app_bar_base.dart';
import 'package:do_x/widgets/app_scaffold.dart';
import 'package:do_x/widgets/dialog/app_modal.dart';
import 'package:do_x/widgets/neu/neu_button.dart';
import 'package:do_x/widgets/neu/neu_card.dart';
import 'package:do_x/widgets/neu/neu_chip.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

/// The editor's four tool groups, one panel each.
enum _EditorTool { crop, rotate, adjust, filters }

/// A crop shape offered in the crop panel. A null [ratio] is free selection.
typedef _AspectOption = ({
  String Function(AppLocalizations) label,
  double? ratio,
});

const _aspectOptions = <_AspectOption>[
  (label: _freeLabel, ratio: null),
  (label: _squareLabel, ratio: 1),
  (label: _label4x5, ratio: 4 / 5),
  (label: _label3x4, ratio: 3 / 4),
  (label: _label4x3, ratio: 4 / 3),
  (label: _label16x9, ratio: 16 / 9),
  (label: _label9x16, ratio: 9 / 16),
];

String _freeLabel(AppLocalizations l10n) => l10n.cropFree;
String _squareLabel(AppLocalizations l10n) => '1:1';
String _label4x5(AppLocalizations l10n) => '4:5';
String _label3x4(AppLocalizations l10n) => '3:4';
String _label4x3(AppLocalizations l10n) => '4:3';
String _label16x9(AppLocalizations l10n) => '16:9';
String _label9x16(AppLocalizations l10n) => '9:16';

@RoutePage()
class ImageEditorScreen extends StatefulScreen implements AutoRouteWrapper {
  const ImageEditorScreen({super.key});

  @override
  State<ImageEditorScreen> createState() => _ImageEditorScreenState();

  @override
  Widget wrappedRoute(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ImageEditorViewModel(), //
      child: this,
    );
  }
}

class _ImageEditorScreenState
    extends ScreenState<ImageEditorScreen, ImageEditorViewModel> {
  _EditorTool _tool = _EditorTool.adjust;

  /// Lives only while the crop panel is open: the widget hands it the decoded
  /// bitmap, so a controller kept around after the picture changed would crop
  /// the old one.
  CropController? _cropController;
  double? _cropAspect;
  bool _isCropping = false;

  /// Anchors the share sheet's popover on iPad.
  final _saveButtonKey = GlobalKey();

  void _selectTool(_EditorTool tool) {
    setState(() {
      _tool = tool;
      if (tool == _EditorTool.crop) {
        _cropAspect = null;
        _cropController = CropController(aspectRatio: null);
      } else {
        _cropController = null;
      }
    });
  }

  void _setCropAspect(double? ratio) {
    setState(() {
      _cropAspect = ratio;
      _cropController?.aspectRatio = ratio;
    });
  }

  Future<void> _applyCrop() async {
    final controller = _cropController;
    if (controller == null || _isCropping) return;
    setState(() => _isCropping = true);
    try {
      final bitmap = await controller.croppedBitmap();
      final data = await bitmap.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('cropped bitmap has no bytes');
      if (!mounted) return;
      vm.applyCrop(data.buffer.asUint8List());
      _selectTool(_EditorTool.adjust);
    } catch (e, stack) {
      logger.e('crop failed: $e', error: e, stackTrace: stack);
      if (!mounted) return;
      context.showToast(context.l10n.imageEditFailed, isError: true);
    } finally {
      if (mounted) setState(() => _isCropping = false);
    }
  }

  Future<void> _pick(ImageSource source) async {
    _selectTool(_EditorTool.adjust);
    await vm.pickImage(source);
  }

  /// The actions that don't earn a place in the app bar: swapping the picture
  /// out, and throwing every edit away.
  Future<void> _showMoreActions() async {
    final l10n = context.l10n;
    final action = await showAppBottomSheet<_MoreAction>(
      context,
      title: l10n.imageEditor,
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_library_rounded),
            title: Text(l10n.chooseFromGallery),
            onTap: () => Navigator.of(sheetContext).pop(_MoreAction.gallery),
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera_rounded),
            title: Text(l10n.takePhoto),
            onTap: () => Navigator.of(sheetContext).pop(_MoreAction.camera),
          ),
          ListTile(
            enabled: vm.hasEdits,
            leading: const Icon(Icons.restart_alt_rounded),
            title: Text(l10n.resetEdits),
            onTap: () => Navigator.of(sheetContext).pop(_MoreAction.reset),
          ),
        ],
      ),
    );
    if (action == null || !mounted) return;

    switch (action) {
      case _MoreAction.gallery:
        await _pick(ImageSource.gallery);
      case _MoreAction.camera:
        await _pick(ImageSource.camera);
      case _MoreAction.reset:
        final confirmed = await showAppConfirmDialog(
          context,
          title: l10n.resetEdits,
          message: l10n.resetEditsMessage,
          isDestructive: true,
        );
        if (!confirmed || !mounted) return;
        _selectTool(_EditorTool.adjust);
        vm.resetAll();
    }
  }

  void _save() {
    final box = _saveButtonKey.currentContext?.findRenderObject() as RenderBox?;
    vm.save(
      origin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final vm = context.watch<ImageEditorViewModel>();
    final busy = vm.isProcessing || _isCropping;

    return AppScaffold(
      bottom: true,
      appBar: DoAppBar(
        title: l10n.imageEditor,
        actions: [
          IconButton(
            onPressed: vm.canUndo && !busy ? vm.undo : null,
            icon: const Icon(Icons.undo_rounded),
            tooltip: l10n.undo,
          ),
          IconButton(
            key: _saveButtonKey,
            onPressed: vm.hasImage && !busy ? _save : null,
            icon: const Icon(Icons.ios_share_rounded),
            tooltip: l10n.save,
          ),
          IconButton(
            onPressed: busy ? null : _showMoreActions,
            icon: const Icon(Icons.more_vert_rounded),
            tooltip: l10n.more,
          ),
        ],
      ),
      body: Stack(
        children: [
          // The picture is replaced wholesale by every pass, so input has to
          // stop until the new bytes are in — not just the control that
          // started it.
          AbsorbPointer(
            absorbing: busy,
            child: vm.hasImage ? _buildEditor(vm, l10n) : _buildEmpty(l10n),
          ),
          if (busy) const LinearProgressIndicator(minHeight: 4),
        ],
      ),
    );
  }

  Widget _buildEmpty(AppLocalizations l10n) {
    return SingleChildScrollView(
      child: Padding(
        padding: Dimens.screenPadding,
        child: NeuCard(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
          child: Column(
            spacing: 16,
            children: [
              Icon(
                Icons.image_outlined,
                size: 56,
                color: context.theme.colorScheme.primary,
              ),
              Text(
                l10n.imageEditorEmptyMessage,
                textAlign: TextAlign.center,
                style: context.textTheme.primary,
              ),
              NeuButton(
                expand: true,
                accent: context.theme.colorScheme.primary,
                onPressed: () => _pick(ImageSource.gallery),
                child: _buttonLabel(
                  Icons.photo_library_rounded,
                  l10n.chooseFromGallery,
                ),
              ),
              NeuButton(
                expand: true,
                onPressed: () => _pick(ImageSource.camera),
                child: _buttonLabel(Icons.photo_camera_rounded, l10n.takePhoto),
              ),
            ],
          ),
        ),
        // The cap goes outside the padding, so this card is exactly as wide as
        // a card on any other page.
      ).contentConstrainedBox(),
    );
  }

  Widget _buildEditor(ImageEditorViewModel vm, AppLocalizations l10n) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final preview = _buildPreview(vm);
        final panel = _buildPanel(vm, l10n);
        // Landscape: the panel goes beside the picture instead of eating the
        // little height a phone on its side has left.
        if (constraints.maxWidth > constraints.maxHeight) {
          return Row(
            children: [
              Expanded(child: preview),
              SizedBox(width: _panelWidth, child: panel),
            ],
          );
        }
        return Column(
          children: [
            Expanded(child: preview),
            panel,
          ],
        );
      },
    );
  }

  Widget _buildPreview(ImageEditorViewModel vm) {
    final image = vm.image!;
    return Padding(
      padding: Dimens.screenPadding,
      child: Center(
        child: _tool == _EditorTool.crop
            ? CropImage(
                controller: _cropController!,
                // Keyed on the bytes: a new picture needs a new decode, and
                // the crop rectangle has to start over with it.
                image: Image.memory(image, key: ValueKey(image.hashCode)),
              )
            : ColorFiltered(
                colorFilter: ColorFilter.matrix(vm.previewMatrix),
                child: Image.memory(
                  image,
                  // Without this the old frame is dropped while the new bytes
                  // decode, so every edit flashes the page background.
                  gaplessPlayback: true,
                  fit: BoxFit.contain,
                ),
              ),
      ),
    );
  }

  Widget _buildPanel(ImageEditorViewModel vm, AppLocalizations l10n) {
    return NeuCard(
      margin: const EdgeInsets.all(Dimens.pagePadding),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 12,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              spacing: 8,
              children: [
                for (final tool in _EditorTool.values)
                  NeuChip(
                    label: _toolLabel(tool, l10n),
                    isSelected: _tool == tool,
                    onTap: () => _selectTool(tool),
                  ),
              ],
            ),
          ),
          switch (_tool) {
            _EditorTool.crop => _buildCropPanel(l10n),
            _EditorTool.rotate => _buildRotatePanel(l10n),
            _EditorTool.adjust => _buildAdjustPanel(vm, l10n),
            _EditorTool.filters => _buildFiltersPanel(vm, l10n),
          },
        ],
      ),
    ).contentConstrainedBox();
  }

  Widget _buildCropPanel(AppLocalizations l10n) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 12,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            spacing: 8,
            children: [
              for (final option in _aspectOptions)
                NeuChip(
                  label: option.label(l10n),
                  isSelected: _cropAspect == option.ratio,
                  onTap: () => _setCropAspect(option.ratio),
                ),
            ],
          ),
        ),
        Row(
          spacing: 12,
          children: [
            Expanded(
              child: NeuButton(
                expand: true,
                onPressed: () => _selectTool(_EditorTool.adjust),
                child: Text(l10n.cancel),
              ),
            ),
            Expanded(
              child: NeuButton(
                expand: true,
                accent: context.theme.colorScheme.primary,
                onPressed: _applyCrop,
                child: Text(l10n.crop),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRotatePanel(AppLocalizations l10n) {
    const ops = <(ImageGeometryOp, IconData)>[
      (ImageGeometryOp.rotateLeft, Icons.rotate_left_rounded),
      (ImageGeometryOp.rotateRight, Icons.rotate_right_rounded),
      (ImageGeometryOp.flipHorizontal, Icons.flip_rounded),
      (ImageGeometryOp.flipVertical, Icons.flip_rounded),
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (final (op, icon) in ops)
          NeuButton(
            onPressed: () => vm.applyGeometryOp(op),
            padding: const EdgeInsets.all(14),
            child: Transform.rotate(
              // The two flips share one icon; the quarter turn is what tells
              // the vertical one apart, as it does in the system photo editors.
              angle: op == ImageGeometryOp.flipVertical ? math.pi / 2 : 0,
              child: Icon(icon, semanticLabel: _geometryLabel(op, l10n)),
            ),
          ),
      ],
    );
  }

  Widget _buildAdjustPanel(ImageEditorViewModel vm, AppLocalizations l10n) {
    final adjustments = vm.adjustments;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _slider(
          icon: Icons.brightness_6_rounded,
          label: l10n.brightness,
          value: adjustments.brightness,
          onChanged: vm.setBrightness,
        ),
        _slider(
          icon: Icons.contrast_rounded,
          label: l10n.contrast,
          value: adjustments.contrast,
          onChanged: vm.setContrast,
        ),
        _slider(
          icon: Icons.water_drop_rounded,
          label: l10n.saturation,
          value: adjustments.saturation,
          onChanged: vm.setSaturation,
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: vm.resetAdjustments,
            child: Text(l10n.resetSliders),
          ),
        ),
      ],
    );
  }

  Widget _buildFiltersPanel(ImageEditorViewModel vm, AppLocalizations l10n) {
    final image = vm.image!;
    return SizedBox(
      height: _thumbSize + 26,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: ImageFilterPreset.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final preset = ImageFilterPreset.values[index];
          final isSelected = vm.adjustments.preset == preset;
          return GestureDetector(
            onTap: () => vm.setPreset(preset),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(Dimens.radiusSmall),
                  child: ColorFiltered(
                    colorFilter: ColorFilter.matrix(presetMatrix(preset)),
                    child: Image.memory(
                      image,
                      width: _thumbSize,
                      height: _thumbSize,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      // Decoded once at thumbnail size: a full-resolution
                      // decode per preset would cost tens of megabytes.
                      cacheWidth: (_thumbSize * 2).round(),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _presetLabel(preset, l10n),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                    color: isSelected
                        ? context.theme.colorScheme.primary
                        : context.theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _slider({
    required IconData icon,
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 8),
        SizedBox(width: 74, child: Text(label, style: context.textTheme.title)),
        Expanded(
          child: Slider(
            value: value,
            min: -1,
            max: 1,
            // 40 stops each way: fine enough to feel continuous, coarse enough
            // that the reported value is a round number.
            divisions: 80,
            label: (value * 100).round().toString(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buttonLabel(IconData icon, String label) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      spacing: 8,
      children: [Icon(icon), Text(label)],
    );
  }

  String _toolLabel(_EditorTool tool, AppLocalizations l10n) => switch (tool) {
    _EditorTool.crop => l10n.crop,
    _EditorTool.rotate => l10n.rotate,
    _EditorTool.adjust => l10n.adjust,
    _EditorTool.filters => l10n.filters,
  };

  String _geometryLabel(ImageGeometryOp op, AppLocalizations l10n) =>
      switch (op) {
        ImageGeometryOp.rotateLeft => l10n.rotateLeft,
        ImageGeometryOp.rotateRight => l10n.rotateRight,
        ImageGeometryOp.flipHorizontal => l10n.flipHorizontal,
        ImageGeometryOp.flipVertical => l10n.flipVertical,
      };

  String _presetLabel(ImageFilterPreset preset, AppLocalizations l10n) =>
      switch (preset) {
        ImageFilterPreset.none => l10n.filterNone,
        ImageFilterPreset.mono => l10n.filterMono,
        ImageFilterPreset.sepia => l10n.filterSepia,
        ImageFilterPreset.cool => l10n.filterCool,
        ImageFilterPreset.warm => l10n.filterWarm,
        ImageFilterPreset.vintage => l10n.filterVintage,
      };
}

enum _MoreAction { gallery, camera, reset }

/// Width of the tool panel when it sits beside the picture in landscape.
const _panelWidth = 320.0;
const _thumbSize = 64.0;
