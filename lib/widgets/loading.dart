import 'package:do_x/gen/assets.gen.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class Loading extends StatelessWidget {
  const Loading({super.key, this.size = 50, this.strokeWidth});

  final double size;
  final double? strokeWidth;

  @override
  Widget build(BuildContext context) {
    return Lottie.asset(
      Assets.animation.loading,
      backgroundLoading: true,
      repeat: true,
      width: size,
      height: size,
      delegates: LottieDelegates(
        values: [
          ValueDelegate.color(const ['**'], value: Colors.amber),
        ],
      ),
    );
  }
}
