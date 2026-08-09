import 'package:do_x/constants/dimens.dart';
import 'package:do_x/gen/assets.gen.dart';
import 'package:do_x/widgets/neu/neu_button.dart';
import 'package:flutter/material.dart';

/// Shared add icon for the chicken feature screens.
class ChickenAddIcon extends StatelessWidget {
  const ChickenAddIcon({
    super.key,
    required this.icon,
    this.enabled = true,
    this.size = 30,
  });

  final SvgGenImage icon;
  final bool enabled;

  /// Side of the whole mark, badge included. Everything inside scales with it,
  /// so the badge keeps its proportion on a smaller app bar button.
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final badgeSize = size / 2;
    return Opacity(
      opacity: enabled ? 1 : 0.38,
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: icon.svg(),
              ),
            ),
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: badgeSize,
                height: badgeSize,
                decoration: BoxDecoration(
                  color: colors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.surface, width: 1.5),
                ),
                child: Icon(
                  Icons.add_rounded,
                  size: badgeSize * 0.73,
                  color: colors.onPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// [ChickenAddIcon] as an app bar action, on the same neumorphic button the
/// other bar actions use. A null [onPressed] dims the mark as well as
/// disabling the button, which is how read-only mode reads across the feature.
class ChickenAddButton extends StatelessWidget {
  const ChickenAddButton({super.key, required this.icon, this.onPressed});

  final SvgGenImage icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    // NeuButton rather than NeuIconButton: the mark is an illustration with a
    // badge, not an [IconData].
    return NeuButton(
      radius: 14,
      depth: Dimens.appBarActionDepth,
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      child: SizedBox.square(
        dimension: Dimens.appBarActionSize,
        child: Center(
          child: ChickenAddIcon(
            icon: icon,
            enabled: onPressed != null,
            size: 24,
          ),
        ),
      ),
    );
  }
}
