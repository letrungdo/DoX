import 'package:flutter/material.dart';

/// The look of a caption overlay, taken from what the moment API's own client
/// posts.
///
/// Both the payload and the on-camera preview read from here. They drifted
/// apart once already - the preview drew dark text on a white pill while the
/// payload asked for white text on a blurred one - and the only way to see that
/// was to post and look at the result.
abstract final class OverlayStyle {
  /// Text on every overlay but the weather badge: #FFFFFFE6.
  static const text = Color(0xE6FFFFFF);

  /// The weather badge sits on its own gradient and takes full white.
  static const weatherText = Color(0xFFFFFFFF);

  static const locationIcon = Color(0xFF24B0FF);
  static const weatherIcon = Color(0xFFFFFFFF);
  static const timeIcon = Color(0xCCFFFFFF);

  /// The tint behind the blur. The API names the surface `ultra_thin` or
  /// `regular`; on screen both come out as a dark wash over the photo.
  static const blurTint = Color(0x40000000);

  /// Blur radius standing in for the API's `material_blur`.
  static const blurSigma = 24.0;

  /// The hairline that keeps the badge off a photo of the same brightness.
  static const edge = Color(0x1FFFFFFF);
}
