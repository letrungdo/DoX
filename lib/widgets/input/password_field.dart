import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/widgets/text_field.dart';
import 'package:flutter/material.dart';

/// A [DoTextField] that hides what is typed, with the eye that reveals it.
///
/// Four forms need this now — sign in, sign up, change password, delete
/// account — and each one used to carry its own `_obscure` flag plus its own
/// tooltip strings. Keeping it in one widget is also what stops the reveal
/// icon from drifting apart between them.
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.labelText,
    this.value,
    this.controller,
    this.onChanged,
    this.validator,
    this.autofillHints,
    this.textInputAction,
  });

  final String labelText;
  final String? value;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;
  final Iterable<String>? autofillHints;
  final TextInputAction? textInputAction;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DoTextField(
      value: widget.value,
      controller: widget.controller,
      labelText: widget.labelText,
      obscureText: _obscured,
      keyboardType: TextInputType.visiblePassword,
      autofillHints: widget.autofillHints,
      textInputAction: widget.textInputAction,
      onChanged: widget.onChanged,
      validator: widget.validator,
      suffixIcon: IconButton(
        tooltip: _obscured ? l10n.showPassword : l10n.hidePassword,
        onPressed: () => setState(() => _obscured = !_obscured),
        icon: Icon(
          _obscured ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        ),
      ),
    );
  }
}
