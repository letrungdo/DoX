import 'package:auto_size_text/auto_size_text.dart';

class TextAutoScaleWidget extends AutoSizeText {
  const TextAutoScaleWidget(
    this.text, {
    super.style,
    super.textAlign,
    super.maxLines = 1,
    super.overflow,
    super.key,
    super.minFontSize = 1,
    super.stepGranularity = 0.5,
  }) : super(text);

  final String text;
}
