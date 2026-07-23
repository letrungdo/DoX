import 'package:do_x/gen/assets.gen.dart';
import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/widgets/dialog/dialog_action_button.dart';
import 'package:flutter/material.dart';

/// Large rounded dialog with a cute SVG icon next to the title, shared by input forms.
class CuteDialog extends StatelessWidget {
  final SvgGenImage? icon;
  final String title;
  final Color? accent;
  final List<Widget> children;
  final String? confirmText;
  final VoidCallback? onConfirm;

  /// Defaults to the localized "Cancel" label when null.
  final String? cancelText;
  final bool isDestructive;
  final String? destructiveText;
  final VoidCallback? onDestructive;

  const CuteDialog({
    super.key,
    this.icon,
    required this.title,
    this.accent,
    this.children = const [],
    this.confirmText,
    this.onConfirm,
    this.cancelText,
    this.isDestructive = false,
    this.destructiveText,
    this.onDestructive,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = accent ?? theme.colorScheme.primary;
    final titleStyle = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.bold,
      fontSize: 18,
    );
    final deleteButton = destructiveText == null
        ? null
        : TextButton.icon(
            onPressed: onDestructive,
            icon: const Icon(Icons.delete_outline, size: 18),
            label: Text(destructiveText!),
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
          );
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        // Tapping outside a field (but still inside the dialog) dismisses the
        // keyboard without closing the dialog.
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header scrolls together with the fields so the content keeps
              // its space when the keyboard shrinks the dialog.
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (icon != null || deleteButton != null)
                        Row(
                          children: [
                            if (icon != null) ...[
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: accentColor.withValues(
                                  alpha: 0.12,
                                ),
                                child: icon!.svg(width: 28, height: 28),
                              ),
                              const SizedBox(width: 12),
                            ],
                            Expanded(
                              child: Text(
                                title,
                                textAlign: icon == null
                                    ? TextAlign.center
                                    : TextAlign.start,
                                style: titleStyle,
                              ),
                            ),
                            if (deleteButton != null) deleteButton,
                          ],
                        )
                      else
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: titleStyle,
                        ),
                      const SizedBox(height: 16),
                      for (var i = 0; i < children.length; i++) ...[
                        if (i > 0) const SizedBox(height: 12),
                        children[i],
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DialogActionButton(
                      text: cancelText ?? AppLocalizations.of(context).cancel,
                      onPressed: () => Navigator.pop(context),
                      kind: DialogActionKind.cancel,
                    ),
                  ),
                  if (confirmText != null) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: DialogActionButton(
                        text: confirmText!,
                        onPressed: onConfirm,
                        kind: isDestructive
                            ? DialogActionKind.destructive
                            : DialogActionKind.primary,
                      ),
                    ),
                  ],
                ],
              ),
            ],
            ),
          ),
        ),
      ),
    );
  }
}
