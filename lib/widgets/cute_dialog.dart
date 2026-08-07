import 'dart:async';

import 'package:do_x/gen/assets.gen.dart';
import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/widgets/dialog/dialog_action_button.dart';
import 'package:flutter/material.dart';

/// Large rounded dialog with a cute SVG icon next to the title, shared by input forms.
class CuteDialog extends StatefulWidget {
  final SvgGenImage? icon;
  final String title;
  final Color? accent;
  final List<Widget> children;
  final String? confirmText;

  /// Confirm handler. An async handler is awaited: while it runs the confirm
  /// button shows a spinner and every action is disabled, so a slow save can
  /// never be submitted twice.
  final FutureOr<void> Function()? onConfirm;

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
  State<CuteDialog> createState() => _CuteDialogState();

  /// Runs [action] without the confirm spinner, for the part of a confirm
  /// handler that waits on the user (a follow-up dialog) rather than on a write.
  /// The dialog stays disabled throughout, so nothing can be submitted twice.
  static Future<T> pauseLoading<T>(Future<T> Function() action) =>
      _CuteDialogState._pauseLoading(action);
}

class _CuteDialogState extends State<CuteDialog> {
  /// The dialog whose confirm handler is running, if any. Only one confirm can
  /// be in flight at a time: every other dialog is behind a modal barrier.
  static _CuteDialogState? _confirming;

  /// True while an async confirm handler is still running.
  bool _saving = false;

  /// True while the handler is waiting on the user instead of on a write.
  bool _paused = false;

  static Future<T> _pauseLoading<T>(Future<T> Function() action) async {
    final state = _confirming;
    state?._setPaused(true);
    try {
      return await action();
    } finally {
      state?._setPaused(false);
    }
  }

  void _setPaused(bool value) {
    if (!mounted || _paused == value) return;
    setState(() => _paused = value);
  }

  Future<void> _handleConfirm() async {
    if (_saving) return;
    final previous = _confirming;
    _confirming = this;
    final FutureOr<void> result;
    try {
      result = widget.onConfirm?.call();
    } finally {
      // A synchronous handler is already done here; an async one keeps the slot
      // until it completes (restored in the block below).
      if (_confirming == this) _confirming = previous;
    }
    // A synchronous handler is already done: no spinner, no rebuild.
    if (result is! Future) return;
    _confirming = this;
    setState(() => _saving = true);
    try {
      await result;
    } finally {
      if (_confirming == this) _confirming = previous;
      // The dialog is usually gone by now (the handler pops it on success).
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = widget.accent;
    final icon = widget.icon;
    final title = widget.title;
    final children = widget.children;
    final confirmText = widget.confirmText;
    final destructiveText = widget.destructiveText;
    final accentColor = accent ?? theme.colorScheme.primary;
    final titleStyle = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.bold,
      fontSize: 18,
    );
    final deleteButton = destructiveText == null
        ? null
        : TextButton.icon(
            onPressed: _saving ? null : widget.onDestructive,
            icon: const Icon(Icons.delete_outline, size: 18),
            label: Text(destructiveText),
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
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
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
                                  child: icon.svg(width: 28, height: 28),
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
                              ?deleteButton,
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
                DialogActions(
                  children: [
                    DialogActionButton(
                      text:
                          widget.cancelText ??
                          AppLocalizations.of(context).cancel,
                      // Closing the dialog mid-save would leave the user
                      // guessing whether the write went through.
                      onPressed: _saving ? null : () => Navigator.pop(context),
                      kind: DialogActionKind.cancel,
                    ),
                    if (confirmText != null)
                      DialogActionButton(
                        text: confirmText,
                        onPressed: _saving ? null : _handleConfirm,
                        loading: _saving && !_paused,
                        kind: widget.isDestructive
                            ? DialogActionKind.destructive
                            : DialogActionKind.primary,
                      ),
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
