import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// The editing maths behind the image editor, kept free of Flutter widgets so
/// the heavy passes can run in an isolate through [compute] and so the whole
/// pipeline can be unit tested without a binding.
///
/// The preview and the exported file share one description of an edit: a 4x5
/// colour matrix. The screen hands it to `ColorFilter.matrix` (drawn on the
/// GPU, so the sliders stay live), and the export applies the very same matrix
/// to the full-resolution pixels — which is what makes the saved file look like
/// what the user was looking at.

/// A one-tap look, applied after the manual adjustments.
enum ImageFilterPreset { none, mono, sepia, cool, warm, vintage }

/// A geometry change the user commits to the image — unlike the adjustments,
/// these rewrite the pixels straight away.
enum ImageGeometryOp { rotateLeft, rotateRight, flipHorizontal, flipVertical }

/// Manual colour adjustments, each `-1..1` with `0` meaning "leave it alone".
@immutable
class ImageAdjustments {
  const ImageAdjustments({
    this.brightness = 0,
    this.contrast = 0,
    this.saturation = 0,
    this.preset = ImageFilterPreset.none,
  });

  final double brightness;
  final double contrast;
  final double saturation;
  final ImageFilterPreset preset;

  static const none = ImageAdjustments();

  bool get isIdentity =>
      brightness == 0 &&
      contrast == 0 &&
      saturation == 0 &&
      preset == ImageFilterPreset.none;

  ImageAdjustments copyWith({
    double? brightness,
    double? contrast,
    double? saturation,
    ImageFilterPreset? preset,
  }) => ImageAdjustments(
    brightness: brightness ?? this.brightness,
    contrast: contrast ?? this.contrast,
    saturation: saturation ?? this.saturation,
    preset: preset ?? this.preset,
  );

  /// The single matrix standing for every adjustment on this object, in the
  /// order they read to the eye: saturation, then contrast, then brightness,
  /// and the preset last so it grades the corrected image rather than the raw
  /// one.
  List<double> get matrix => composeMatrices([
    presetMatrix(preset),
    brightnessMatrix(brightness),
    contrastMatrix(contrast),
    saturationMatrix(saturation),
  ]);
}

/// The 4x5 matrix that changes nothing.
List<double> identityMatrix() => <double>[
  1, 0, 0, 0, 0, //
  0, 1, 0, 0, 0,
  0, 0, 1, 0, 0,
  0, 0, 0, 1, 0,
];

/// Lifts or drops every channel by a constant. `amount` of 1 adds a full
/// [_channelMax], which is more than any photo survives — the screen keeps the
/// slider well inside that.
List<double> brightnessMatrix(double amount) {
  final offset = amount.clamp(-1.0, 1.0) * _channelMax;
  return <double>[
    1, 0, 0, 0, offset, //
    0, 1, 0, 0, offset,
    0, 0, 1, 0, offset,
    0, 0, 0, 1, 0,
  ];
}

/// Scales every channel around mid grey, so the image gains contrast without
/// drifting brighter or darker overall.
List<double> contrastMatrix(double amount) {
  // -1 flattens to half scale, +1 doubles it; a plain `1 + amount` would go to
  // zero at -1 and leave nothing but grey.
  final scale = 1 + amount.clamp(-1.0, 1.0) * 0.5 * (amount < 0 ? 1 : 2);
  final offset = _channelMid * (1 - scale);
  return <double>[
    scale, 0, 0, 0, offset, //
    0, scale, 0, 0, offset,
    0, 0, scale, 0, offset,
    0, 0, 0, 1, 0,
  ];
}

/// Mixes each channel towards (negative) or away from (positive) the pixel's
/// luminance. -1 is fully grey, +1 is double saturation.
List<double> saturationMatrix(double amount) {
  final scale = 1 + amount.clamp(-1.0, 1.0);
  final inverse = 1 - scale;
  final r = _lumaR * inverse;
  final g = _lumaG * inverse;
  final b = _lumaB * inverse;
  return <double>[
    r + scale, g, b, 0, 0, //
    r, g + scale, b, 0, 0,
    r, g, b + scale, 0, 0,
    0, 0, 0, 1, 0,
  ];
}

List<double> presetMatrix(ImageFilterPreset preset) => switch (preset) {
  ImageFilterPreset.none => identityMatrix(),
  ImageFilterPreset.mono => saturationMatrix(-1),
  ImageFilterPreset.sepia => <double>[
    0.393, 0.769, 0.189, 0, 0, //
    0.349, 0.686, 0.168, 0, 0,
    0.272, 0.534, 0.131, 0, 0,
    0, 0, 0, 1, 0,
  ],
  // Cool and warm are the same idea mirrored: one channel lifted, the opposite
  // one pulled back, so the overall exposure stays where the user put it.
  ImageFilterPreset.cool => <double>[
    0.9, 0, 0, 0, 0, //
    0, 0.98, 0, 0, 0,
    0, 0, 1.12, 0, 8,
    0, 0, 0, 1, 0,
  ],
  ImageFilterPreset.warm => <double>[
    1.12, 0, 0, 0, 8, //
    0, 1.0, 0, 0, 0,
    0, 0, 0.88, 0, 0,
    0, 0, 0, 1, 0,
  ],
  // Faded blacks and a green-yellow cast — film left in a drawer too long.
  ImageFilterPreset.vintage => composeMatrices([
    <double>[
      1.0, 0, 0, 0, 18, //
      0, 0.96, 0, 0, 14,
      0, 0, 0.82, 0, 10,
      0, 0, 0, 1, 0,
    ],
    saturationMatrix(-0.35),
  ]),
};

/// Folds a list of 4x5 matrices into one, applied right to left: the last entry
/// touches the pixel first.
List<double> composeMatrices(List<List<double>> matrices) {
  if (matrices.isEmpty) return identityMatrix();
  var result = matrices.first;
  for (final next in matrices.skip(1)) {
    result = _multiply(result, next);
  }
  return result;
}

/// `a` applied to the result of `b`.
List<double> _multiply(List<double> a, List<double> b) {
  final out = List<double>.filled(20, 0);
  for (var row = 0; row < 4; row++) {
    for (var col = 0; col < 5; col++) {
      var sum = 0.0;
      for (var k = 0; k < 4; k++) {
        sum += a[row * 5 + k] * b[k * 5 + col];
      }
      // The implicit fifth row of both matrices is [0, 0, 0, 0, 1], so the
      // constant column picks up `a`'s own offset on top of the sum.
      if (col == 4) sum += a[row * 5 + 4];
      out[row * 5 + col] = sum;
    }
  }
  return out;
}

/// What [renderEdited] needs to produce the file the user saves.
@immutable
class ImageRenderRequest {
  const ImageRenderRequest({
    required this.bytes,
    required this.matrix,
    this.quality = 92,
  });

  final Uint8List bytes;
  final List<double> matrix;
  final int quality;
}

/// What [prepareSource] needs to turn a picked file into an editable image.
@immutable
class ImageLoadRequest {
  const ImageLoadRequest({required this.bytes, this.maxEdge = 3000});

  final Uint8List bytes;

  /// Longest edge kept. A modern phone hands over 4000px-plus images, and every
  /// crop, rotate and export pass would then cost seconds of main-isolate-free
  /// but still user-visible waiting for detail no phone screen can show.
  final int maxEdge;
}

@immutable
class ImageGeometryRequest {
  const ImageGeometryRequest({required this.bytes, required this.op});

  final Uint8List bytes;
  final ImageGeometryOp op;
}

/// Decodes, downscales past [ImageLoadRequest.maxEdge] and re-encodes as PNG.
///
/// Top-level and self-contained so it can be handed to [compute]. Returns null
/// when the bytes are not an image this app can decode.
Uint8List? prepareSource(ImageLoadRequest request) {
  final decoded = img.decodeImage(request.bytes);
  if (decoded == null) return null;
  final resized = _downscale(decoded, request.maxEdge);
  // PNG so repeated crop/rotate rounds don't stack JPEG artefacts; the export
  // is the only step that encodes lossily.
  return img.encodePng(resized);
}

Uint8List? applyGeometry(ImageGeometryRequest request) {
  final decoded = img.decodeImage(request.bytes);
  if (decoded == null) return null;
  final result = switch (request.op) {
    ImageGeometryOp.rotateLeft => img.copyRotate(decoded, angle: -90),
    ImageGeometryOp.rotateRight => img.copyRotate(decoded, angle: 90),
    ImageGeometryOp.flipHorizontal => img.flipHorizontal(decoded),
    ImageGeometryOp.flipVertical => img.flipVertical(decoded),
  };
  return img.encodePng(result);
}

/// Bakes [ImageRenderRequest.matrix] into the pixels and encodes a JPEG — the
/// file the user shares.
Uint8List? renderEdited(ImageRenderRequest request) {
  final decoded = img.decodeImage(request.bytes);
  if (decoded == null) return null;
  applyMatrix(decoded, request.matrix);
  return img.encodeJpg(decoded, quality: request.quality);
}

/// Applies a 4x5 colour matrix to [image] in place.
///
/// The matrix is written for 0..255 channels, the range `ColorFilter.matrix`
/// works in, so a deeper image is scaled into that range and back out again.
void applyMatrix(img.Image image, List<double> matrix) {
  assert(matrix.length == 20, 'a colour matrix has 4 rows of 5');
  final maxValue = image.maxChannelValue.toDouble();
  final toBytes = maxValue == 0 ? 1.0 : _channelMax / maxValue;
  final fromBytes = toBytes == 0 ? 1.0 : 1 / toBytes;

  for (final pixel in image) {
    final r = pixel.r * toBytes;
    final g = pixel.g * toBytes;
    final b = pixel.b * toBytes;
    final a = pixel.a * toBytes;
    pixel.setRgb(
      _clamp(
            matrix[0] * r +
                matrix[1] * g +
                matrix[2] * b +
                matrix[3] * a +
                matrix[4],
          ) *
          fromBytes,
      _clamp(
            matrix[5] * r +
                matrix[6] * g +
                matrix[7] * b +
                matrix[8] * a +
                matrix[9],
          ) *
          fromBytes,
      _clamp(
            matrix[10] * r +
                matrix[11] * g +
                matrix[12] * b +
                matrix[13] * a +
                matrix[14],
          ) *
          fromBytes,
    );
  }
}

img.Image _downscale(img.Image image, int maxEdge) {
  final longest = math.max(image.width, image.height);
  if (longest <= maxEdge) return image;
  final scale = maxEdge / longest;
  return img.copyResize(
    image,
    width: math.max(1, (image.width * scale).round()),
    height: math.max(1, (image.height * scale).round()),
    interpolation: img.Interpolation.average,
  );
}

double _clamp(double value) => value.clamp(0.0, _channelMax);

const _channelMax = 255.0;
const _channelMid = 127.5;

// Rec. 709 luma: the weighting that matches how sRGB screens actually mix the
// three channels, so a desaturated photo keeps its tonal ordering.
const _lumaR = 0.2126;
const _lumaG = 0.7152;
const _lumaB = 0.0722;
