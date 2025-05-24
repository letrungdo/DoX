import 'dart:ui';

import 'package:auto_route/auto_route.dart';
import 'package:collection/collection.dart';
import 'package:crop_image/crop_image.dart';
import 'package:do_x/constants/dimens.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/utils/logger.dart';
import 'package:do_x/widgets/button/button.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class CropImageModal extends StatefulWidget {
  const CropImageModal({
    super.key,
    required this.onCropped, //
    required this.image,
  });
  final void Function(Uint8List) onCropped;
  final Uint8List image;

  @override
  State<CropImageModal> createState() => _CropImageModalState();
}

class _CropImageModalState extends State<CropImageModal> {
  bool _isCroping = false;

  late final _controller = CropController(
    /// If not specified, [aspectRatio] will not be enforced.
    aspectRatio: 1,

    /// Specify in percentages (1 means full width and height). Defaults to the full image.
    // defaultCrop: Rect.fromLTRB(0.1, 0.1, 0.9, 0.9),
  );

  Future<void> _onCrop() async {
    setState(() {
      _isCroping = true;
    });
    try {
      final bitmap = await _controller.croppedBitmap();
      final data = await bitmap.toByteData(format: ImageByteFormat.png);
      widget.onCropped(data!.buffer.asUint8List());
    } catch (e) {
      logger.e(e.toString(), error: e);
    }
    if (!mounted) return;
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final heightCheck = [constraints.maxHeight - 180, size.width];
        if (kIsWeb) {
          heightCheck.add(Dimens.webMaxWidth);
        }
        final height = kIsWeb ? heightCheck.min : heightCheck.max;
        return Stack(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: height + 50,
                  child: CropImage(
                    controller: _controller, //
                    image: Image.memory(widget.image),
                  ),
                ),
                SizedBox(height: 20),
                DoButton(
                  onPressed: _isCroping ? null : _onCrop, //
                  text: context.l10n.crop,
                ),
                SizedBox(height: 50),
              ],
            ),
            if (_isCroping) LinearProgressIndicator(minHeight: 5),
          ],
        );
      },
    );
  }
}
