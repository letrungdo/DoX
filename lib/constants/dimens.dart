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

  /// App bar actions: a button that sits centred in the 44dp bar with room
  /// above and below it.
  static const appBarActionSize = 36.0;

  /// Default side of a `AppIconButton` outside an app bar.
  static const iconButtonSize = 40.0;

  /// The least height a filled, outlined or dialog button is laid out at.
  static const buttonMinHeight = 48.0;

  /// Padding inside a card, for new code.
  static const cardPadding = EdgeInsets.all(16);

  /// Gap between stacked tappable full-width rows (menu, settings).
  static const rowSpacing = 8.0;

  /// Gap between cards within a page section.
  static const cardSpacing = 12.0;

  /// Thickness of a divider, the bottom bar's top edge and the TV rail's edge.
  static const hairline = 1.0;

  /// How far a control shrinks while held, and a card — a wide surface, where
  /// the same 3% reads as the whole panel lurching.
  static const pressedScaleControl = 0.97;
  static const pressedScaleCard = 0.99;

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
  /// Fill steps and corners, not shadows, tell stacked panels apart — so a
  /// radius that drifts by a pixel or two per screen reads as sloppiness
  /// rather than as hierarchy. Pick the step whose *role* matches; do not add a value in
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
  /// from across a room, and with no shadow lifting the control it carries
  /// more of the load than the growth and the focused fill beside it.
  static const focusRingWidth = 3.0;

  /// Shared television margins, injected by `TvShell` for every page.
  ///
  /// The same inset on both sides. The left edge used to be twice the right
  /// one, which nothing on screen explains: a rail down the left of a page
  /// then stood further from the panel's edge than the player on the other
  /// side, and every grid sat off-centre.
  static const tvOverscan = EdgeInsets.symmetric(horizontal: 24, vertical: 27);

  /// The margin around a television rail's rows, shared by the home page's
  /// rail and the music page's so the two are the same object twice.
  static const tvRailPadding = 20.0;

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
  ///
  /// Wider than it is tall, because a station's logo is: drawn to fit inside
  /// a square the artwork ends up a band across the middle with as much air
  /// above and below it as there is logo. Half that height is what the
  /// picture actually needs, and the rows it saves are rows of channels.
  ///
  /// A television gets a wider tile than a phone for the same reason it gets
  /// a wider content column: the panel is read from a sofa, and 150dp of
  /// logo-and-name at that distance is a smudge.
  ///
  /// It is also what decides how many channels fit across. A television
  /// reports the same logical width whatever the panel measures — a 1080p
  /// set is 960dp whether it is 43 inches or 75 — so the row does not get
  /// wider with the screen, and this number is the only thing that changes
  /// how much of the playlist is on show. At 170 a 1080p set fits five
  /// channels across the space the rail leaves; the tile still lands near
  /// 140dp, which carries a logo from a sofa.
  static double get tvChannelTileMaxWidth => deviceType.isTv ? 170.0 : 150.0;

  /// The width every channel logo is decoded at, in pixels.
  ///
  /// A station publishes its logo at whatever size it likes — half a
  /// megapixel is common — and a television has to turn that into a bitmap
  /// before it can draw it in a box a hundred pixels wide. Decoding it down
  /// to the size it is actually drawn at is most of the work saved, and
  /// because the page and the player's grid both ask for the same size,
  /// the grid opens on the bitmaps the page has already decoded rather
  /// than decoding a screenful again over a running programme.
  static const tvChannelLogoDecodeWidth = 256;
  static const tvChannelTileAspect = 1.4;
  static const tvChannelTileSpacing = 12.0;

  /// One track in the music list: a row, not a tile.
  ///
  /// Sized rather than given an aspect ratio, because the row's artwork is a
  /// square as tall as the row — so a ratio chosen for the grid decided how
  /// much width was left for the title, and on a television it left almost
  /// none. Fixing the height and the square fixes the title's room with them.
  static const musicTrackArtSize = 56.0;

  /// Tall enough for the title, the artist and the counts underneath, at the
  /// television's larger text as well as the phone's.
  static double get musicTrackTileHeight => deviceType.isTv ? 92.0 : 76.0;

  /// The gap between two rows of the music list.
  static const musicTrackSpacing = 12.0;

  /// How long the music list takes to bring the track now playing into view
  /// after next or previous — a longer ride than a focus move, because it can
  /// cover a whole shelf.
  static const musicFollowScrollDuration = Duration(milliseconds: 350);

  /// The code the television shows for a phone to sign it in with. Big enough
  /// to be read from across a room, which is where the phone usually is.
  static const musicPairingQrSize = 260.0;

  /// The quiet zone around it, in white whatever the theme: a scanner reads a
  /// dark code on a light plate and nothing else.
  static const musicPairingQrPadding = 14.0;

  /// The video in the phone's player, where the artwork is otherwise: the
  /// artwork's height, in the shape of a widescreen picture.
  static const musicMiniVideoHeight = 44.0;

  /// The icons of the phone's mini player, and the spinner on its video
  /// button while the picture is on its way.
  static const musicMiniIconSize = 20.0;
  static const musicMiniVideoAspect = 16 / 9;

  /// The video's run between the phone's player and the whole screen: how
  /// long it takes on its own, how far a drag goes for all of it as a share
  /// of the screen's height, and how fast a flick has to be to decide it
  /// whatever the distance, in logical pixels a second.
  static const musicVideoExpandDuration = Duration(milliseconds: 280);
  static const musicVideoDragTravelShare = 0.6;
  static const musicVideoFlingVelocity = 700.0;

  /// How far the "original sound" badge sits from the video's corner.
  static const musicVideoBadgeInset = 8.0;

  /// The full-screen video: its round controls — a television's sized for
  /// across the room, a phone's for a thumb — the gap between them, how far
  /// above them the fade starts, the artwork shown while the next video is
  /// fetched, and how long the controls stay up with nobody touching them.
  static double get musicFullscreenControlSize => deviceType.isTv ? 56.0 : 44.0;
  static double get musicFullscreenPlayButtonSize =>
      deviceType.isTv ? 72.0 : 56.0;
  static double get musicFullscreenControlSpacing =>
      deviceType.isTv ? 20.0 : 12.0;

  /// How much of a full-screen control its icon, or the spinner standing in
  /// for it, fills.
  static const musicFullscreenIconShare = 0.55;
  static const musicFullscreenControlsTop = 64.0;
  static const musicFullscreenWaitingArtSize = 240.0;
  static const musicFullscreenControlsHideDelay = Duration(seconds: 5);
  static const musicFullscreenControlsFade = Duration(milliseconds: 200);

  /// Around the phone's full-screen controls, inside the safe area; the top
  /// is where the fade starts.
  static const musicPhoneControlsPadding = EdgeInsets.fromLTRB(16, 48, 16, 12);

  /// The least room kept under the phone's full-screen controls for the
  /// home indicator's strip, which takes the first touch there.
  static const musicPhoneGestureClearance = 24.0;

  /// Between the like, video and full-screen buttons under the television
  /// dashboard's transport row.
  static const musicDashboardActionSpacing = 16.0;

  /// The music service's bot check, framed in a sheet: tall enough for its
  /// puzzle without the sheet having to scroll.
  static const musicChallengeHeight = 460.0;

  /// The remote's pointer over a web view — see `TvWebPointer`. Big enough to
  /// find from the sofa, small enough not to hide what it is pointing at.
  static const tvWebPointerSize = 28.0;

  /// The phone's camera window onto that code.
  static const musicPairingScannerMaxSize = 320.0;

  /// Where a tile the remote has just moved onto is parked in its viewport,
  /// and how long the ride takes. Half way up, so there is always a row of
  /// peek above and below telling the viewer the grid carries on.
  static const tvFocusScrollAlignment = 0.5;
  static const tvFocusScrollDuration = Duration(milliseconds: 180);

  /// How long the player's control overlay stays up after the last key press.
  ///
  /// A television waits longer than a phone: the viewer is three metres away
  /// reading the bar rather than an arm's length away pointing at it, and
  /// every correction costs another press of the remote.
  static Duration get playerControlsTimeout =>
      deviceType.isTv ? const Duration(seconds: 5) : const Duration(seconds: 3);

  /// The same card over the picture is a shallower one again: it is laid
  /// over a programme the viewer is still watching, so every row of it that
  /// is not needed is a row of programme taken away.
  static const tvChannelOverlayTileAspect = 2.4;
}
