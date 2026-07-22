import 'package:do_x/widgets/input/cute_input_decoration.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Rounded text field styled with [cuteInputDecoration].
class CuteTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? prefixText;
  final String? suffixText;
  final String? errorText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int maxLines;
  final TextStyle? style;
  final ValueChanged<String>? onChanged;
  final bool autofocus;

  const CuteTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.prefixText,
    this.suffixText,
    this.errorText,
    this.keyboardType,
    this.inputFormatters,
    this.maxLines = 1,
    this.style,
    this.onChanged,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLines: maxLines,
      style: style,
      onChanged: onChanged,
      autofocus: autofocus,
      decoration: cuteInputDecoration(
        context,
        label,
        hint: hint,
        prefixText: prefixText,
        suffixText: suffixText,
        errorText: errorText,
      ),
    );
  }
}
