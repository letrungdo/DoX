import 'package:auto_route/auto_route.dart';
import 'package:collection/collection.dart';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:do_x/constants/dimens.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/widgets/button.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class CropImageModal extends StatefulWidget {
  const CropImageModal({super.key, required this.onCropped, this.controller, required this.image, this.onCrop});

  final void Function(CropResult) onCropped;
  final CropController? controller;
  final Uint8List image;
  final void Function()? onCrop;

  @override
  State<CropImageModal> createState() => _CropImageModalState();
}

class _CropImageModalState extends State<CropImageModal> {
  bool _isCroping = false;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    final heightCheck = [size.height - 300, size.width - 20];
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
              height: height,
              child: Crop(
                initialRectBuilder: InitialRectBuilder.withSizeAndRatio(size: 1, aspectRatio: 1),
                image: widget.image,
                controller: widget.controller,
                aspectRatio: 1,
                baseColor: Colors.transparent,
                filterQuality: FilterQuality.high,
                // maskColor: Colors.transparent,
                onCropped: (value) async {
                  widget.onCropped(value);
                  setState(() {
                    _isCroping = false;
                  });
                  context.pop();
                },
              ),
            ),
            SizedBox(height: 20),
            DoButton(
              onPressed:
                  _isCroping
                      ? null
                      : () {
                        setState(() {
                          _isCroping = true;
                        });
                        widget.onCrop?.call();
                      }, //
              text: context.l10n.crop,
            ),
            SizedBox(height: 50),
          ],
        ),
        if (_isCroping) LinearProgressIndicator(minHeight: 5),
      ],
    );
  }
}
