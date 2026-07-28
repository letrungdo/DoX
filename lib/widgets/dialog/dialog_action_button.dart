import 'package:flutter/material.dart';

enum DialogActionKind { cancel, primary, destructive, destructiveOutline }

/// A semantic action button shared by modal and dialog surfaces.
class DialogActionButton extends StatelessWidget {
  const DialogActionButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.kind = DialogActionKind.primary,
    this.icon,
    this.textStyle,
    this.loading = false,
  });

  final String text;
  final VoidCallback? onPressed;
  final DialogActionKind kind;
  final IconData? icon;
  final TextStyle? textStyle;

  /// Shows a spinner in place of the label; the button is not tappable while it
  /// is set, so a slow action cannot be started twice.
  final bool loading;

  Widget _spinner(Color color) => SizedBox(
    height: 18,
    width: 18,
    child: CircularProgressIndicator(strokeWidth: 2, color: color),
  );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (loading) {
      return switch (kind) {
        DialogActionKind.cancel ||
        DialogActionKind.destructiveOutline => OutlinedButton(
          onPressed: null,
          child: _spinner(scheme.onSurface),
        ),
        DialogActionKind.primary => FilledButton(
          onPressed: null,
          child: _spinner(scheme.onSurface),
        ),
        DialogActionKind.destructive => FilledButton(
          style: FilledButton.styleFrom(
            disabledBackgroundColor: scheme.error.withValues(alpha: 0.6),
            disabledForegroundColor: scheme.onError,
          ),
          onPressed: null,
          child: _spinner(scheme.onError),
        ),
      };
    }
    final destructiveStyle = FilledButton.styleFrom(
      backgroundColor: scheme.error,
      foregroundColor: scheme.onError,
      disabledBackgroundColor: scheme.onSurface.withValues(alpha: 0.12),
      disabledForegroundColor: scheme.onSurface.withValues(alpha: 0.38),
    );
    final destructiveOutlineStyle = OutlinedButton.styleFrom(
      foregroundColor: scheme.error,
      side: BorderSide(color: scheme.error.withValues(alpha: 0.72)),
    );

    return switch (kind) {
      DialogActionKind.cancel =>
        icon == null
            ? OutlinedButton(
                onPressed: onPressed,
                child: Text(text, style: textStyle),
              )
            : OutlinedButton.icon(
                onPressed: onPressed,
                icon: Icon(icon),
                label: Text(text, style: textStyle),
              ),
      DialogActionKind.primary =>
        icon == null
            ? FilledButton(
                onPressed: onPressed,
                child: Text(text, style: textStyle),
              )
            : FilledButton.icon(
                onPressed: onPressed,
                icon: Icon(icon),
                label: Text(text, style: textStyle),
              ),
      DialogActionKind.destructive =>
        icon == null
            ? FilledButton(
                style: destructiveStyle,
                onPressed: onPressed,
                child: Text(text, style: textStyle),
              )
            : FilledButton.icon(
                style: destructiveStyle,
                onPressed: onPressed,
                icon: Icon(icon),
                label: Text(text, style: textStyle),
              ),
      DialogActionKind.destructiveOutline =>
        icon == null
            ? OutlinedButton(
                style: destructiveOutlineStyle,
                onPressed: onPressed,
                child: Text(text, style: textStyle),
              )
            : OutlinedButton.icon(
                style: destructiveOutlineStyle,
                onPressed: onPressed,
                icon: Icon(icon),
                label: Text(text, style: textStyle),
              ),
    };
  }
}
