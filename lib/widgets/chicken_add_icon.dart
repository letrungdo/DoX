import 'package:do_x/gen/assets.gen.dart';
import 'package:flutter/material.dart';

/// Shared add icon for the chicken feature screens.
class ChickenAddIcon extends StatelessWidget {
  const ChickenAddIcon({super.key, required this.icon});

  final SvgGenImage icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox.square(
      dimension: 30,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Padding(padding: const EdgeInsets.all(2), child: icon.svg()),
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: 15,
              height: 15,
              decoration: BoxDecoration(
                color: colors.primary,
                shape: BoxShape.circle,
                border: Border.all(color: colors.surface, width: 1.5),
              ),
              child: Icon(Icons.add_rounded, size: 11, color: colors.onPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
