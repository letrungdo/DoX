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
    return Stack(
      children: [
        ElevatedButton(
          onPressed: isBusy ? null : onPressed, //
          child:
              child ??
              (text != null
                  ? Text(
                    text!,
                    style: style0?.textStyle?.resolve({}), //
                  )
                  : SizedBox.shrink()),
        ),
        if (isBusy) Positioned.fill(child: Loading()),
      ],
    );
  }
}
