import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

class TextLoading extends StatelessWidget {
  const TextLoading(
    this.value, {
    super.key, //
    this.style,
    this.textAlign,
    this.minHeight = 30,
  });
  final TextStyle? style;
  final String? value;
  final TextAlign? textAlign;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: Center(
        child: Skeletonizer(
          textBoneBorderRadius: TextBoneBorderRadius(BorderRadius.circular(2)),
          enabled: value == null,
          child: Text(
            value ?? "loading", //
            style: style,
            textAlign: textAlign,
          ),
        ),
      ),
    );
  }
}
