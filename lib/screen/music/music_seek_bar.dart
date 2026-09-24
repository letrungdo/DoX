import 'package:do_x/view_model/music/music_view_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// A seek bar for the track playing, and the position to show beside it.
///
/// The thumb follows the finger while it drags and the sound otherwise, and
/// the track is sought once, where the thumb is let go. Sought on every move
/// of the finger, a drag sent both players some sixty seeks a second, and
/// the sound's own position, read twice a second, pulled the thumb back
/// from under the finger.
///
/// [builder] lays the [Slider] out with whatever goes around it; the
/// position it is handed is the thumb's, so the time beside the bar moves
/// with a drag too.
class MusicSeekBar extends StatefulWidget {
  const MusicSeekBar({super.key, required this.builder});

  final Widget Function(BuildContext context, Duration position, Widget slider)
  builder;

  @override
  State<MusicSeekBar> createState() => _MusicSeekBarState();
}

class _MusicSeekBarState extends State<MusicSeekBar> {
  /// Where the thumb is being dragged to, in milliseconds; null while it is
  /// left alone.
  final _dragValue = ValueNotifier<double?>(null);

  @override
  void dispose() {
    _dragValue.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.read<MusicViewModel>();
    final duration = context
        .select<MusicViewModel, Duration>((vm) => vm.duration)
        .inMilliseconds
        .toDouble();
    return ListenableBuilder(
      listenable: Listenable.merge([vm.positionListenable, _dragValue]),
      builder: (context, _) {
        final dragged = _dragValue.value;
        final value = (dragged ?? vm.position.inMilliseconds.toDouble()).clamp(
          0.0,
          duration,
        );
        final slider = Slider(
          value: value,
          max: duration == 0 ? 1 : duration,
          onChangeStart: (value) => _dragValue.value = value,
          onChanged: (value) => _dragValue.value = value,
          onChangeEnd: (value) {
            // Sought before the thumb is let go of, so it does not flick
            // back to the old position for a frame in between.
            vm.seekTo(Duration(milliseconds: value.toInt()));
            _dragValue.value = null;
          },
        );
        final position = dragged == null
            ? vm.position
            : Duration(milliseconds: value.toInt());
        return widget.builder(context, position, slider);
      },
    );
  }
}
