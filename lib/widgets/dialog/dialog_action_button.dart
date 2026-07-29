import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/widgets/neu/neu_button.dart';
import 'package:flutter/material.dart';

enum DialogActionKind { cancel, primary, destructive, destructiveOutline }

/// Lays a dialog's buttons out as one row, spaced far enough apart for their
/// shadows.
///
/// [AlertDialog] packs its actions into an [OverflowBar] that leaves only a few
/// pixels between them — well inside the reach of a [NeuButton]'s rims (offset
/// plus blur is ~14dp at the button's depth), so the right-hand button paints
/// over the left one's shade and the pair reads as clipped. Pass this as the
/// dialog's single action instead: the buttons share the width evenly with a gap
/// that clears both rims, and one button no longer overlaps the next.
class DialogActions extends StatelessWidget {
  const DialogActions({super.key, required this.children, this.expand = true});

  final List<Widget> children;

  /// Split the row's width evenly between the buttons. Turn it off when there
  /// are enough of them that an equal share would squeeze the labels; they then
  /// hug their own width and sit at the trailing edge.
  final bool expand;

  /// Clears the shaded rim of the button on its left (~14dp) with a little air
  /// to spare.
  static const gap = 18.0;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: expand ? MainAxisAlignment.start : MainAxisAlignment.end,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: gap),
          expand ? Expanded(child: children[i]) : children[i],
        ],
      ],
    );
  }
}

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
                child: CircularProgressIndicator(strokeWidth: 2, color: context.colors.disabled),
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
          : Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon), const SizedBox(width: 8), label]),
    );
  }
}
