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
    this.autofillHints,
    this.decoration,
    this.textAlign = TextAlign.start,
    this.maxLines = 1,
    this.maxLength,
    this.textInputAction,
  });
  final void Function(String value)? onChanged;
  final String? value;
  final TextEditingController? controller;
  final String? placeholder;
  final TextInputType? keyboardType;
  final bool obscureText;
  final String? labelText;
  final String? Function(String?)? validator;
  final Iterable<String>? autofillHints;
  final InputDecoration? decoration;
  final TextAlign textAlign;
  final int? maxLines;
  final int? maxLength;
  final TextInputAction? textInputAction;

  @override
  State<DoTextField> createState() => _DoTextFieldState();
}

class _DoTextFieldState extends State<DoTextField> {
  TextEditingController? _controller;

  @override
  void initState() {
    super.initState();
    _controller = (widget.controller ?? TextEditingController())..text = widget.value ?? "";
  }

  @override
  void didUpdateWidget(covariant DoTextField oldWidget) {
    if (_controller?.text != widget.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _controller?.text = widget.value ?? "";
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
      decoration:
          widget.decoration ??
          InputDecoration(
            labelText: widget.labelText,
            hintText: widget.placeholder,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20), //
            ), //
          ),
      obscureText: widget.obscureText,
      onTapOutside: (event) {
        FocusManager.instance.primaryFocus?.unfocus();
      },
      onChanged: widget.onChanged,
      validator: widget.validator,
    );
  }
}
