import 'package:do_x/utils/device_type.dart';
import 'package:video_player/video_player.dart';

/// How a player that shows a picture puts it on screen.
///
/// On a television, a platform view: a SurfaceView the display composites by
/// itself, rather than a texture Flutter redraws every frame on the weakest
/// GPU the app runs on. A texture everywhere else.
///
/// Only for a stream that carries a picture — Android's platform-view player
/// reads the video format as it opens, and crashes the app on a stream of
/// sound alone. And a platform-view player has one surface: draw it in a
/// second [VideoPlayer] and that one takes the picture from the first.
VideoViewType get pictureViewType =>
    deviceType.isTv ? VideoViewType.platformView : VideoViewType.textureView;
