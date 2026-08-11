import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// The app's single source of truth for spacing, radii and content widths.
///
/// Every page, dialog and bottom sheet reads its margins from here, so a change
/// made once lands everywhere instead of drifting per screen.
class Dimens {
  Dimens._();

  static const appBarHeight = kIsWeb ? 60.0 : 44.0;

  /// App bar actions are sized so their neumorphic shadow (offset + blur, about
  /// 5px at this depth) still fits inside the bar instead of spilling out of it.
  static const appBarActionSize = 32.0;
  static const appBarActionDepth = 0.4;

  /// Widest a page's content column ever gets, the app bar's title row
  /// included. Landscape hands a phone twice the width it was designed for, and
  /// a browser window even more; past this a card row stops reading as one
  /// block. Every page shares it, so no screen is narrower than its neighbour.
  ///
  /// Read it through `Widget.contentConstrainedBox()` unless a sliver forces
  /// you to do the padding maths by hand.
  static const contentMaxWidth = 700.0;

  /// Gap between a page's content and the edge of its content column. Sits
  /// *inside* [contentMaxWidth], so a card is the same width on every page.
  static const pagePadding = 16.0;

  /// Past this a dialog reads as a banner on a desktop window — and on a phone
  /// in landscape, where the screen is suddenly twice as wide.
  static const dialogMaxWidth = 460.0;

  /// A bottom sheet shares the dialog's ceiling so the two read as one surface
  /// family; on a wide (landscape / tablet) screen it centres instead of
  /// stretching edge to edge.
  static const sheetMaxWidth = dialogMaxWidth;

  /// Gap between a dialog and the screen edge.
  static const dialogInsetPadding = EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 24,
  );

  /// Padding inside a dialog's body.
  static const dialogPadding = EdgeInsets.fromLTRB(20, 20, 20, 18);

  /// Padding inside a bottom sheet's body. The bottom inset is added on top of
  /// this by the sheet itself, so the content clears the home indicator.
  static const sheetPadding = EdgeInsets.fromLTRB(20, 4, 20, 16);

  /// Standard page padding for a scrollable body.
  static const screenPadding = EdgeInsets.all(pagePadding);

  /// Corner radius shared by dialogs and the top of a bottom sheet.
  static const dialogRadius = 24.0;
  static const sheetRadius = 24.0;

  /// A sheet never grows past this share of the screen height, so the page
  /// behind it stays visible — landscape especially, where the screen is short.
  static const sheetMaxHeightFactor = 0.85;

  /// Vertical gap between two stacked fields inside a dialog or sheet.
  static const modalItemSpacing = 12.0;

  /// Narrow threshold for the movie player layout.
  static const playerNarrowThreshold = 330.0;
}
