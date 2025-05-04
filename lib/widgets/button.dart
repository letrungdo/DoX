import 'package:do_x/widgets/loading.dart';
import 'package:flutter/material.dart';

class DoButton extends StatelessWidget {
  const DoButton({
    super.key, //
    this.child,
    this.onPressed,
    this.text,
    this.isBusy = false,
  });
  final Widget? child;
  final void Function()? onPressed;
  final String? text;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ElevatedButton(
          onPressed: onPressed, //
          style: ButtonStyle(
            backgroundColor: isBusy ? WidgetStateProperty.all(Colors.grey) : null,
            // padding: WidgetStateProperty.all(EdgeInsets.symmetric(horizontal: 10)), //
          ),
          child: child ?? (text != null ? Text(text!) : SizedBox.shrink()),
        ),
        if (isBusy) Positioned.fill(child: Loading()),
      ],
    );
  }
}
