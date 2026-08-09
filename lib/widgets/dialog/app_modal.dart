import 'dart:math' as math;

import 'package:do_x/constants/dimens.dart';
import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/widgets/dialog/dialog_action_button.dart';
import 'package:flutter/material.dart';

/// Every dialog and bottom sheet in the app goes through this file.
///
/// Each entry point pins the same margins, corner radius, content padding and
/// width ceiling, so a modal looks the same wherever it is opened from — and,
/// now that the app rotates, none of them stretch into a banner or run under a
/// side notch in landscape.

// ---------------------------------------------------------------------------
// Dialogs
// ---------------------------------------------------------------------------

/// Shows [builder]'s widget as a dialog.
///
/// `useSafeArea` is what keeps the dialog clear of the display cutout, which in
/// landscape sits on the side the dialog would otherwise reach.
Future<T?> showAppModal<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    useSafeArea: true,
    builder: builder,
  );
}

/// The app's dialog surface: a titled panel with an optional message/content
/// block and a row of [DialogActionButton]s.
///
/// Use it instead of a bare [AlertDialog] — it carries the shared inset,
/// radius and [Dimens.dialogMaxWidth] cap, which an [AlertDialog] on its own
/// does not (it grows to whatever the screen offers).
class AppDialog extends StatelessWidget {
  const AppDialog({
    super.key,
    this.title,
    this.titleWidget,
    this.message,
    this.content,
    this.actions,
    this.contentPadding,
    this.maxWidth = Dimens.dialogMaxWidth,
    this.insetPadding = Dimens.dialogInsetPadding,
    this.scrollable = false,
    this.expandActions = true,
  });

  final String? title;

  /// Replaces [title] when the header needs more than a line of text.
  final Widget? titleWidget;

  /// Convenience for the common "one paragraph" body.
  final String? message;

  /// Body of the dialog; wins over [message] when both are given.
  final Widget? content;

  /// Rendered as one evenly-spaced row. Pass [DialogActionButton]s.
  final List<Widget>? actions;

  /// Split the action row's width evenly. Turn it off when there are enough
  /// buttons that an equal share would squeeze their labels.
  final bool expandActions;

  final EdgeInsets? contentPadding;
  final double maxWidth;
  final EdgeInsets insetPadding;

  /// Let the body scroll when it is taller than the dialog — worth turning on
  /// for anything with a form in it, since landscape halves the height.
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final title = this.title;
    final message = this.message;
    final actions = this.actions;
    final body = content ?? (message == null ? null : Text(message));

    return Center(
      // A dialog route hands its child tight full-screen constraints, and a
      // lone ConstrainedBox would enforce its limits against those — a no-op.
      // Centring loosens them first.
      child: ConstrainedBox(
        // [insetPadding] is added back on purpose: AlertDialog subtracts its own
        // inset from whatever width it is handed, so capping at [maxWidth] here
        // would leave the panel narrower than a `CuteDialog` by twice the inset
        // — a difference you only see on a wide (landscape) screen, where the
        // cap is what binds rather than the inset.
        constraints: BoxConstraints(
          maxWidth: maxWidth + insetPadding.horizontal,
        ),
        child: AlertDialog(
          insetPadding: insetPadding,
          scrollable: scrollable,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Dimens.dialogRadius),
          ),
          title: titleWidget ?? (title == null ? null : Text(title)),
          content: body,
          contentPadding: contentPadding,
          actions: actions == null || actions.isEmpty
              ? null
              : [DialogActions(expand: expandActions, children: actions)],
        ),
      ),
    );
  }
}

/// Ask/confirm dialog shared by every "are you sure?" in the app.
///
/// Returns true only when the user picks the confirm action; a dismiss counts
/// as a no, so an accidental tap outside never destroys anything.
Future<bool> showAppConfirmDialog(
  BuildContext context, {
  required String title,
  String? message,
  Widget? content,
  String? confirmText,
  String? cancelText,
  bool isDestructive = false,
}) async {
  final l10n = AppLocalizations.of(context);
  final result = await showAppModal<bool>(
    context,
    builder: (dialogContext) => AppDialog(
      title: title,
      message: message,
      content: content,
      actions: [
        DialogActionButton(
          text: cancelText ?? l10n.cancel,
          kind: DialogActionKind.cancel,
          onPressed: () => Navigator.pop(dialogContext, false),
        ),
        DialogActionButton(
          text: confirmText ?? l10n.ok,
          kind: isDestructive
              ? DialogActionKind.destructive
              : DialogActionKind.primary,
          onPressed: () => Navigator.pop(dialogContext, true),
        ),
      ],
    ),
  );
  return result ?? false;
}

// ---------------------------------------------------------------------------
// Bottom sheets
// ---------------------------------------------------------------------------

/// Shows [builder]'s widget inside an [AppBottomSheet].
///
/// The sheet is capped at [Dimens.sheetMaxWidth] and centred, so on a wide
/// (landscape or tablet) screen it stays a sheet instead of a full-width strip.
Future<T?> showAppBottomSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  String? title,
  bool showDragHandle = true,
  bool isDismissible = true,
  bool enableDrag = true,
  bool scrollable = true,
  double maxHeightFactor = Dimens.sheetMaxHeightFactor,
  EdgeInsets padding = Dimens.sheetPadding,
}) {
  return showModalBottomSheet<T>(
    context: context,
    // Always on: without it the sheet is capped at half the screen, which in
    // landscape is a couple of finger-widths.
    isScrollControlled: true,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    // Off here, and drawn by [AppBottomSheet] instead — it sits inside the
    // sheet's own surface. Letting the route draw one too paints two handles.
    showDragHandle: false,
    // The sheet paints its own surface and rounds its own top corners.
    backgroundColor: Colors.transparent,
    // Handled inside the sheet instead, so its background still reaches the
    // bottom edge while the content clears the home indicator.
    useSafeArea: false,
    constraints: const BoxConstraints(maxWidth: Dimens.sheetMaxWidth),
    builder: (sheetContext) => AppBottomSheet(
      title: title,
      showDragHandle: showDragHandle,
      scrollable: scrollable,
      maxHeightFactor: maxHeightFactor,
      padding: padding,
      child: builder(sheetContext),
    ),
  );
}

/// The app's bottom sheet surface: drag handle, optional title, then the body.
class AppBottomSheet extends StatelessWidget {
  const AppBottomSheet({
    super.key,
    required this.child,
    this.title,
    this.showDragHandle = true,
    this.scrollable = true,
    this.maxHeightFactor = Dimens.sheetMaxHeightFactor,
    this.padding = Dimens.sheetPadding,
  });

  final Widget child;
  final String? title;
  final bool showDragHandle;

  /// Wraps [child] in a scroll view. Turn it off when the body already scrolls
  /// (a `ListView`) or is a fixed-height block.
  final bool scrollable;

  final double maxHeightFactor;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = this.title;
    final screenSize = MediaQuery.sizeOf(context);
    final viewPadding = MediaQuery.paddingOf(context);
    // Added under the content rather than around the sheet, so the surface
    // still runs to the bottom of the screen.
    final bottomInset = viewPadding.bottom;

    final body = Padding(
      padding: padding.copyWith(bottom: padding.bottom + bottomInset),
      child: child,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final sheetWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : screenSize.width;
        // The sheet is centred at [Dimens.sheetMaxWidth], so on a wide screen
        // it already stops well short of the edge. Only pad by whatever a side
        // notch still reaches past that margin — a plain SafeArea here would
        // inset landscape a second time on top of the margin it already has.
        final margin = math.max(0.0, (screenSize.width - sheetWidth) / 2);
        final left = math.max(0.0, viewPadding.left - margin);
        final right = math.max(0.0, viewPadding.right - margin);

        return Container(
          constraints: BoxConstraints(
            maxHeight: screenSize.height * maxHeightFactor,
          ),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(Dimens.sheetRadius),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.only(left: left, right: right),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showDragHandle) const _SheetDragHandle(),
                if (title != null) ...[
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      showDragHandle ? 0 : 16,
                      20,
                      0,
                    ),
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Divider(height: 20),
                ],
                Flexible(
                  child: scrollable ? SingleChildScrollView(child: body) : body,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SheetDragHandle extends StatelessWidget {
  const _SheetDragHandle();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

/// A bottom sheet that picks one value out of a list — the shape used by the
/// year filter, the chart interval picker and the player's quality / speed
/// menus, which each used to build their own.
Future<T?> showAppOptionSheet<T>(
  BuildContext context, {
  String? title,
  required List<T> options,
  required T? selected,
  String Function(T value)? labelBuilder,
}) {
  return showAppBottomSheet<T>(
    context,
    title: title,
    scrollable: false,
    padding: const EdgeInsets.only(bottom: 8),
    builder: (sheetContext) {
      final scheme = Theme.of(sheetContext).colorScheme;
      return ListView.builder(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: options.length,
        itemBuilder: (context, index) {
          final option = options[index];
          final isSelected = option == selected;
          return ListTile(
            title: Text(
              labelBuilder?.call(option) ?? '$option',
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : null,
                color: isSelected ? scheme.primary : null,
              ),
            ),
            selected: isSelected,
            trailing: isSelected
                ? Icon(Icons.check, color: scheme.primary)
                : null,
            onTap: () => Navigator.pop(sheetContext, option),
          );
        },
      );
    },
  );
}
