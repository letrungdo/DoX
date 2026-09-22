import 'package:do_x/utils/device_type.dart';
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
  ///
  /// A television is the one screen that wants more of it. A 1080p panel
  /// reports 960dp across, and once the nav rail and the overscan band have
  /// taken their share there is about 780dp of page left — so the phone's cap
  /// would leave a strip empty down each side for no reason. It is not the
  /// dramatic gain the pixel count suggests, because a TV's device pixel
  /// ratio is 2: the screen is wide in pixels and ordinary in dp.
  static double get contentMaxWidth => deviceType.isTv ? 820.0 : 700.0;

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

  /// The radius scale, named by the role a corner plays rather than by size.
  ///
  /// Neumorphism leans on the shadow pair rather than an outline, so a corner is
  /// the only other thing telling two stacked panels apart — a radius that
  /// drifts by a pixel or two per screen reads as sloppiness rather than as
  /// hierarchy. Pick the step whose *role* matches; do not add a value in
  /// between.
  ///
  /// When nesting, the inner radius is the outer one minus the gap between them,
  /// so a card at [radiusCard] holding a control inset by 4 wants
  /// [radiusControlSmall], not another [radiusCard].
  ///
  /// Chart bars, badges, inline markers.
  static const radiusTiny = 4.0;

  /// Tags and small pills that sit inside a row.
  static const radiusSmall = 8.0;

  /// Text and icon buttons, chips — a control small enough that the workhorse
  /// radius would swallow its label.
  static const radiusControlSmall = 12.0;

  /// The workhorse: filled and outlined buttons, inputs, list tiles, snack bars.
  static const radiusControl = 14.0;

  /// Cards and the panels that group a set of controls.
  static const radiusCard = 16.0;

  /// A panel large enough that [radiusCard] reads as square on it — a toast, a
  /// full-width summary block.
  static const radiusPanel = 20.0;

  /// Fully rounded: avatars, circular badges, capsule buttons. Large enough that
  /// `BorderRadius.circular` clamps to a half-height capsule at any size.
  static const radiusPill = 999.0;

  /// The moment photo is a rounded square, and it is sized off the viewport
  /// rather than fixed - so its corner is a share of its own side, holding the
  /// same shape from a phone to the widest the content cap allows. A fixed
  /// radius reads as a circle at one width and a sharp box at another.
  static const momentImageRadiusRatio = 0.18;

  /// A sheet never grows past this share of the screen height, so the page
  /// behind it stays visible — landscape especially, where the screen is short.
  static const sheetMaxHeightFactor = 0.85;

  /// Vertical gap between two stacked fields inside a dialog or sheet.
  static const modalItemSpacing = 12.0;

  /// Narrow threshold for the movie player layout.
  static const playerNarrowThreshold = 330.0;

  /// Thickness of the outline drawn around whatever the TV remote's D-pad is
  /// pointing at. Heavier than a desktop focus ring on purpose: it is read
  /// from across a room, and it is the only cue a television gets.
  static const focusRingWidth = 2.5;

  /// Shared television margins, injected by `TvShell` for every page.
  /// The right edge uses a compact 24dp inset to give content more room.
  static const tvOverscan = EdgeInsets.fromLTRB(48, 27, 24, 27);

  /// How far the television's focus outline is drawn outside the control it
  /// marks, so the control's own edge stays readable underneath it.
  static const focusOutlineGap = 3.0;

  /// The smallest the text may be on a television.
  ///
  /// The app is written for a phone held at arm's length; a television is read
  /// from a sofa, about ten times as far away for a screen only a few times
  /// the size. Google's leanback guidance puts the floor for body text at
  /// 18sp, and the app's own body text is 14 — so everything is scaled up
  /// rather than each size being chosen twice.
  ///
  /// A floor, not a multiplier: a viewer who has already asked their TV for
  /// larger text gets what they asked for instead of that on top of this.
  ///
  /// 1.2 and no more. 1.5 is what the leanback guidance would want, and on a
  /// television emulator it broke page after page: the app is full of rows,
  /// tiles and bars whose height was chosen once against phone-sized text,
  /// and half again is more than they have to give. Raising this means going
  /// and finding every one of them first.
  static const tvTextScale = 1.2;

  /// How much wider the control under the remote is drawn, in pixels.
  ///
  /// The outline says where the remote is; the lift is what makes it obvious
  /// from across the room, and it is what every television interface does.
  ///
  /// Pixels rather than a percentage, because the app's controls are nothing
  /// like the same size. A tenth added to a channel tile is the small hop a
  /// grid wants; the same tenth on a menu row that spans the page is fifty
  /// pixels of lurch, and the row swings out past its neighbours like a
  /// drawer coming open. A fixed amount reads as the same lift on both.
  static const tvFocusGrowth = 10.0;

  /// The most the lift may come to on a small control, where a fixed ten
  /// pixels would otherwise be a third of it.
  static const tvFocusScaleMax = 1.08;

  /// The channel grid, on the page and again over the picture when the
  /// player opens its list. One set of numbers so a channel is the same card
  /// in both places.
  static const tvChannelTileMaxWidth = 150.0;
  static const tvChannelTileAspect = 0.85;
  static const tvChannelTileSpacing = 12.0;

  /// The same card over the picture is a shallower one: it is laid over a
  /// programme the viewer is still watching, so every row of it that is not
  /// needed is a row of programme taken away.
  static const tvChannelOverlayTileAspect = 1.5;
}
