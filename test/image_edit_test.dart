import 'dart:typed_data';

import 'package:do_x/utils/image_edit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// A 2x1 image: mid grey beside pure red.
img.Image _sample() {
  final image = img.Image(width: 2, height: 1);
  image.setPixelRgb(0, 0, 128, 128, 128);
  image.setPixelRgb(1, 0, 255, 0, 0);
  return image;
}

void main() {
  group('colour matrices', () {
    test('the identity matrix leaves every pixel where it was', () {
      final image = _sample();
      applyMatrix(image, identityMatrix());

      expect(image.getPixel(0, 0).r, 128);
      expect(image.getPixel(1, 0).r, 255);
      expect(image.getPixel(1, 0).g, 0);
    });

    test('brightness lifts every channel and clamps at white', () {
      final image = _sample();
      applyMatrix(image, brightnessMatrix(0.2));

      expect(image.getPixel(0, 0).r, 128 + (0.2 * 255).round());
      // Already at full red: it can only stay there.
      expect(image.getPixel(1, 0).r, 255);
    });

    test('contrast pivots around mid grey, leaving it untouched', () {
      final image = _sample();
      applyMatrix(image, contrastMatrix(0.5));

      expect(image.getPixel(0, 0).r, closeTo(128, 1));
      expect(image.getPixel(1, 0).r, 255);
      expect(image.getPixel(1, 0).g, 0);
    });

    test('full desaturation turns a colour into its luminance', () {
      final image = _sample();
      applyMatrix(image, saturationMatrix(-1));

      final red = image.getPixel(1, 0);
      expect(red.r, red.g);
      expect(red.g, red.b);
      expect(red.r, closeTo(0.2126 * 255, 1));
    });

    test('composing applies the last matrix first', () {
      // A mid-range pixel, so nothing clips: a channel pinned at 0 or 255
      // would hide the ordering behind the clamp.
      img.Image midtone() {
        final image = img.Image(width: 1, height: 1);
        image.setPixelRgb(0, 0, 120, 60, 90);
        return image;
      }

      final direct = midtone();
      applyMatrix(direct, brightnessMatrix(0.1));
      applyMatrix(direct, contrastMatrix(0.4));

      final composed = midtone();
      applyMatrix(
        composed,
        composeMatrices([contrastMatrix(0.4), brightnessMatrix(0.1)]),
      );

      expect(composed.getPixel(0, 0).r, closeTo(direct.getPixel(0, 0).r, 1));
      expect(composed.getPixel(0, 0).b, closeTo(direct.getPixel(0, 0).b, 1));

      // Reversed, the same pair lands somewhere else — which is why the order
      // is part of the contract rather than an implementation detail.
      final reversed = midtone();
      applyMatrix(
        reversed,
        composeMatrices([brightnessMatrix(0.1), contrastMatrix(0.4)]),
      );
      expect(reversed.getPixel(0, 0).r, isNot(composed.getPixel(0, 0).r));
    });

    test('the neutral adjustment set is the identity matrix', () {
      expect(ImageAdjustments.none.isIdentity, isTrue);
      expect(ImageAdjustments.none.matrix, identityMatrix());
      expect(
        const ImageAdjustments(preset: ImageFilterPreset.mono).isIdentity,
        isFalse,
      );
    });
  });

  group('pixel passes', () {
    test('a quarter turn swaps the image dimensions', () {
      final source = img.encodePng(img.Image(width: 4, height: 2));

      final rotated = applyGeometry(
        ImageGeometryRequest(bytes: source, op: ImageGeometryOp.rotateRight),
      );

      final decoded = img.decodeImage(rotated!)!;
      expect(decoded.width, 2);
      expect(decoded.height, 4);
    });

    test('flipping horizontally mirrors the row', () {
      final source = img.encodePng(_sample());

      final flipped = applyGeometry(
        ImageGeometryRequest(bytes: source, op: ImageGeometryOp.flipHorizontal),
      );

      final decoded = img.decodeImage(flipped!)!;
      expect(decoded.getPixel(0, 0).r, 255);
      expect(decoded.getPixel(1, 0).r, 128);
    });

    test('a picture over the cap comes back scaled to it', () {
      final source = img.encodePng(img.Image(width: 900, height: 300));

      final prepared = prepareSource(
        ImageLoadRequest(bytes: source, maxEdge: 300),
      );

      final decoded = img.decodeImage(prepared!)!;
      expect(decoded.width, 300);
      expect(decoded.height, 100);
    });

    test('a picture already inside the cap is left at its own size', () {
      final source = img.encodePng(img.Image(width: 120, height: 80));

      final prepared = prepareSource(
        ImageLoadRequest(bytes: source, maxEdge: 300),
      );

      final decoded = img.decodeImage(prepared!)!;
      expect(decoded.width, 120);
      expect(decoded.height, 80);
    });

    test('bytes that are not an image are reported rather than thrown', () {
      final junk = Uint8List.fromList(List.filled(64, 7));

      expect(prepareSource(ImageLoadRequest(bytes: junk)), isNull);
      expect(
        applyGeometry(
          ImageGeometryRequest(bytes: junk, op: ImageGeometryOp.rotateLeft),
        ),
        isNull,
      );
      expect(
        renderEdited(ImageRenderRequest(bytes: junk, matrix: identityMatrix())),
        isNull,
      );
    });

    test('the export bakes the matrix into the encoded file', () {
      final source = img.encodePng(_sample());

      final jpeg = renderEdited(
        ImageRenderRequest(bytes: source, matrix: saturationMatrix(-1)),
      );

      final decoded = img.decodeImage(jpeg!)!;
      final red = decoded.getPixel(1, 0);
      // JPEG's chroma subsampling means "grey" is only grey to within a few
      // levels — enough to tell it apart from the red it started as.
      expect((red.r - red.g).abs(), lessThan(12));
      expect(red.r, lessThan(120));
    });
  });
}
