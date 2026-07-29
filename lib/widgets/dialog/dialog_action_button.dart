import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/widgets/neu/neu_button.dart';
import 'package:flutter/material.dart';

enum DialogActionKind { cancel, primary, destructive, destructiveOutline }

/// A semantic action button shared by modal and dialog surfaces.
///
/// Built on [NeuButton], so save/cancel/delete carry the same raised-to-pressed
/// cue as the rest of the app. What used to separate the kinds was the button
/// *class* — filled vs outlined — which put an outline on the cancel and the
/// secondary destructive variant; the fill carries that difference now:
///
/// * [DialogActionKind.primary] — the accent fill,
/// * [DialogActionKind.cancel] — the plain surface, lifted like any panel,
/// * [DialogActionKind.destructive] — filled with the error colour,
/// * [DialogActionKind.destructiveOutline] — surface fill with an error label,
///   for a destructive action that is not the dialog's main one.
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (Color? accent, Color? foreground) = switch (kind) {
      DialogActionKind.primary => (scheme.primary, scheme.onPrimary),
      DialogActionKind.destructive => (scheme.error, scheme.onError),
      DialogActionKind.destructiveOutline => (null, scheme.error),
      DialogActionKind.cancel => (null, null),
    };

    return NeuButton(
      onPressed: loading ? null : onPressed,
      accent: accent,
      foreground: foreground,
      radius: 14,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
      child: loading
          ? Center(
              child: SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: context.colors.disabled,
                ),
              ),
            )
          : _label(),
    );
  }

  /// Centred: these usually sit in an `Expanded`, and a raw `Text` would hug
  /// the left edge of the stretched button.
  Widget _label() {
    final label = Text(text, style: textStyle);
    return Center(
      child: icon == null
          ? label
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [Icon(icon), const SizedBox(width: 8), label],
            ),
    );
  }
}
