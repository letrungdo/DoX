import 'package:do_x/constants/dimens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DoTextField extends StatefulWidget {
  const DoTextField({
    super.key, //
    this.onChanged,
    this.value,
    this.controller,
    this.placeholder,
    this.keyboardType,
    this.obscureText = false,
    this.labelText,
    this.validator,
    this.errorText,
    this.autofillHints,
    this.decoration,
    this.textAlign = TextAlign.start,
    this.maxLines = 1,
    this.maxLength,
    this.textInputAction,
    this.onSubmitted,
    this.style,
    this.suffixIcon,
  });
  final void Function(String value)? onChanged;
  final String? value;
  final TextEditingController? controller;
  final String? placeholder;
  final TextInputType? keyboardType;
  final bool obscureText;
  final String? labelText;
  final String? Function(String?)? validator;

  /// Error shown under the field, for a message that comes back from a server
  /// rather than from a [validator].
  final String? errorText;
  final Iterable<String>? autofillHints;
  final InputDecoration? decoration;
  final TextAlign textAlign;
  final int? maxLines;
  final int? maxLength;
  final TextInputAction? textInputAction;

  /// Fired when the keyboard's action key is pressed — the hook a form uses to
  /// let Enter do what its submit button does.
  final ValueChanged<String>? onSubmitted;

  final TextStyle? style;
  final Widget? suffixIcon;

  @override
  State<DoTextField> createState() => _DoTextFieldState();
}

class _DoTextFieldState extends State<DoTextField> {
  TextEditingController? _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    // Only seeded when there is something to seed with: a caller that passes
    // its own controller and no [value] is holding the text itself, and
    // blanking it here would throw that away.
    if (widget.value != null) _controller!.text = widget.value!;
  }

  @override
  void didUpdateWidget(covariant DoTextField oldWidget) {
    // Keyed off the *incoming* value, not off the controller's text. Comparing
    // against the controller re-ran on every rebuild — including one the field
    // triggered itself, such as a password field toggling its reveal icon —
    // and a caller that never passes [value] would have its text wiped for it.
    if (widget.value != null && widget.value != oldWidget.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _controller?.text = widget.value!;
      });
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      textAlign: widget.textAlign,
      controller: _controller,
      keyboardType: widget.keyboardType,
      autofillHints: widget.autofillHints,
      maxLines: widget.maxLines,
      maxLengthEnforcement: MaxLengthEnforcement.enforced,
      maxLength: widget.maxLength,
      textInputAction: widget.textInputAction,
      style: widget.style,
      decoration:
          widget.decoration ??
          InputDecoration(
            labelText: widget.labelText,
            hintText: widget.placeholder,
            errorText: widget.errorText,
            suffixIcon: widget.suffixIcon,
            // A validator message longer than a few words is ellipsised on the
            // single line Material gives it by default.
            errorMaxLines: 4,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Dimens.radiusPanel), //
            ), //
          ),
      obscureText: widget.obscureText,
      onTapOutside: (event) {
        FocusManager.instance.primaryFocus?.unfocus();
      },
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onSubmitted,
      validator: widget.validator,
    );
  }
}
