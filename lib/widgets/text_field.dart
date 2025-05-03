import 'package:flutter/material.dart';

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
  });
  final Function(String value)? onChanged;
  final String? value;
  final TextEditingController? controller;
  final String? placeholder;
  final TextInputType? keyboardType;
  final bool obscureText;
  final String? labelText;
  final String? Function(String?)? validator;
  final Iterable<String>? autofillHints;

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
      controller: _controller,
      keyboardType: widget.keyboardType,
      autofillHints: widget.autofillHints,
      decoration: InputDecoration(
        labelText: widget.labelText,
        hintText: widget.placeholder,
        // border: InputBorder.none,
        // focusedBorder: InputBorder.none,
        // enabledBorder: InputBorder.none,
        // errorBorder: InputBorder.none,
        // disabledBorder: InputBorder.none,
        // hintTextDirection: TextDirection.ltr,
        // fillColor: Colors.transparent,
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
