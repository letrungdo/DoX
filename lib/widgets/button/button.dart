import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/widgets/loading.dart';
import 'package:flutter/material.dart';

class DoButton extends StatelessWidget {
  const DoButton({
    super.key, //
    this.child,
    this.onPressed,
    this.text,
    this.isBusy = false,
    this.style,
  });
  final Widget? child;
  final void Function()? onPressed;
  final String? text;
  final bool isBusy;
  final ButtonStyle? style;

  @override
  Widget build(BuildContext context) {
    final style0 = style ?? context.theme.elevatedButtonTheme.style;
    final button = ElevatedButton(
      onPressed: isBusy ? null : onPressed, //
      style: style,
      child:
          child ??
          (text != null
              ? Text(
                  text!,
                  style: style0?.textStyle?.resolve({}), //
                )
              : SizedBox.shrink()),
    );
    if (isBusy) {
      return Stack(
        // Without this the stack hands the button *loose* constraints, so a
        // button its parent had stretched to full width shrank to the width of
        // its label the moment it went busy — while the spinner, laid out by
        // Positioned.fill, stayed centred on the full width and ended up
        // sitting off to the side of it. Passthrough lets the button see the
        // same constraints it gets when it is idle, so going busy no longer
        // changes its size.
        fit: StackFit.passthrough,
        children: [
          button, //
          Positioned.fill(child: Loading()),
        ],
      );
    }
    return button;
  }
}
