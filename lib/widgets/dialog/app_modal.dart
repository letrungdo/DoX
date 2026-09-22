import 'dart:async';
import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:do_x/constants/dimens.dart';
import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/utils/device_type.dart';
import 'package:do_x/widgets/dialog/dialog_action_button.dart';
import 'package:do_x/widgets/neu/neu_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Every dialog and bottom sheet in the app goes through this file.
///
/// Each entry point pins the same margins, corner radius, content padding and
/// width ceiling, so a modal looks the same wherever it is opened from — and,
/// now that the app rotates, none of them stretch into a banner or run under a
/// side notch in landscape.

// ---------------------------------------------------------------------------
// Dialogs
// ---------------------------------------------------------------------------

/// Restores focus to the control that opened the modal on a television, or
/// falls back to the current page scope so focus never leaks to the left nav rail.
void _restoreFocusAfterModal(FocusNode? previousFocus, BuildContext context) {
  if (!deviceType.isTv) return;

  void doRestore() {
    if (previousFocus != null &&
        previousFocus.canRequestFocus &&
        previousFocus.context != null &&
        previousFocus.context!.mounted) {
      previousFocus.requestFocus();
      return;
    }
    final pageScope = FocusScope.of(context);
    if (pageScope.canRequestFocus) {
      pageScope.requestFocus();
    }
  }

  WidgetsBinding.instance.addPostFrameCallback((_) => doRestore());
}

/// Shows [builder]'s widget as a dialog.
///
/// `useSafeArea` is what keeps the dialog clear of the display cutout, which in
/// landscape sits on the side the dialog would otherwise reach.
Future<T?> showAppModal<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) async {
  final previousFocus = FocusManager.instance.primaryFocus;
  final result = await showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    useSafeArea: true,
    builder: (dialogContext) => TvModalFocus(child: builder(dialogContext)),
  );
  if (context.mounted) {
    _restoreFocusAfterModal(previousFocus, context);
  }
  return result;
}

/// Hands the remote to the first control inside a modal, on a television.
///
/// A dialog or sheet is its own route, and it opens with the focus on that
/// route's scope rather than on anything inside it. A phone does not care —
/// the next thing that happens is a finger landing on a button. A television
/// has nothing else: no outline is drawn, OK presses nothing, and a dialog
/// built around a text field cannot be typed into at all, which is what made
/// adding a second electricity account or editing a movie server impossible
/// from the sofa.
///
/// Every dialog and sheet in the app is wrapped in one of these by
/// [showAppModal] and [showAppBottomSheet], so no modal has to remember it.
/// A modal that has already pointed the remote somewhere of its own — a field
/// with `autofocus`, or a node it asked for by name — keeps that choice; this
/// only fills the gap where nothing was chosen.
class TvModalFocus extends StatefulWidget {
  const TvModalFocus({super.key, required this.child});

  final Widget child;

  @override
  State<TvModalFocus> createState() => _TvModalFocusState();
}

class _TvModalFocusState extends State<TvModalFocus> {
  /// How many frames the modal is given to point the remote somewhere of its
  /// own before this steps in, and to keep it there afterwards.
  ///
  /// More than one, because a modal settles over several frames: a sheet
  /// builds its list after it has been measured, and the route's own focus
  /// handling can put the focus back on the scope after the first frame — at
  /// which point the remote is homeless again.
  static const _attempts = 5;

  int _attemptsLeft = _attempts;

  @override
  void initState() {
    super.initState();
    if (!deviceType.isTv) return;
    _scheduleAttempt();
  }

  /// After the frame that builds the modal, and then on a microtask: its
  /// controls do not exist until the frame ends, and a field's own
  /// `autofocus` is only applied once the focus manager runs — which it does
  /// on a microtask. Looking before that would take the remote off the
  /// control the modal asked for.
  void _scheduleAttempt() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      scheduleMicrotask(_attempt);
    });
    // A settled modal produces no frames, and a post-frame callback waiting
    // for a frame nobody asks for never runs.
    SchedulerBinding.instance.scheduleFrame();
  }

  void _attempt() {
    if (!mounted) return;
    final scope = FocusScope.of(context);
    // Something inside holds the remote — the modal's own choice, or this.
    if (scope.focusedChild == null) {
      scope.traversalDescendants.firstOrNull?.requestFocus();
    }
    if (--_attemptsLeft <= 0) return;
    _scheduleAttempt();
  }

  @override
  Widget build(BuildContext context) => widget.child;
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
  bool useBottomSafeArea = true,
  bool showCloseButton = true,
  double maxHeightFactor = Dimens.sheetMaxHeightFactor,
  EdgeInsets padding = Dimens.sheetPadding,
}) async {
  final previousFocus = FocusManager.instance.primaryFocus;
  final result = await showModalBottomSheet<T>(
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
    builder: (sheetContext) => TvModalFocus(
      child: AppBottomSheet(
        title: title,
        showDragHandle: showDragHandle,
        scrollable: scrollable,
        useBottomSafeArea: useBottomSafeArea,
        showCloseButton: showCloseButton,
        maxHeightFactor: maxHeightFactor,
        padding: padding,
        child: builder(sheetContext),
      ),
    ),
  );
  if (context.mounted) {
    _restoreFocusAfterModal(previousFocus, context);
  }
  return result;
}

/// The app's bottom sheet surface: drag handle, optional title, then the body.
class AppBottomSheet extends StatelessWidget {
  const AppBottomSheet({
    super.key,
    required this.child,
    this.title,
    this.showDragHandle = true,
    this.scrollable = true,
    this.useBottomSafeArea = true,
    this.showCloseButton = true,
    this.maxHeightFactor = Dimens.sheetMaxHeightFactor,
    this.padding = Dimens.sheetPadding,
  });

  final Widget child;
  final String? title;
  final bool showDragHandle;

  /// The dismiss affordance every sheet gets in its top-right corner. Turn it
  /// off only for a sheet the user must answer rather than close.
  final bool showCloseButton;

  /// Wraps [child] in a scroll view. Turn it off when the body already scrolls
  /// (a `ListView`) or is a fixed-height block.
  final bool scrollable;

  /// Adds the device's bottom safe-area inset outside [child]. Turn it off
  /// when a scrolling child includes the inset in its own content padding.
  final bool useBottomSafeArea;

  final double maxHeightFactor;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = this.title;
    final screenSize = MediaQuery.sizeOf(context);
    final viewPadding = MediaQuery.paddingOf(context);
    // How far the keyboard reaches up the screen. The whole sheet is lifted
    // clear of it below; without that, a sheet that shrink-wraps its content —
    // a search list that has just filtered down to two rows — ends up entirely
    // behind the keyboard, search field and all.
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    // Added under the content rather than around the sheet, so the surface
    // still runs to the bottom of the screen. The keyboard already covers the
    // home indicator, so this drops away while it is up rather than stacking
    // on top of the lift.
    final bottomInset = keyboardInset > 0 ? 0.0 : viewPadding.bottom;

    // Full width on purpose. The column below centres its children, so a body
    // that shrink-wraps — a `Wrap` of chips, say — used to sit centred with a
    // margin of whatever was left over, which made the same sheet look
    // differently padded depending on how many chips it happened to hold.
    final body = SizedBox(
      width: double.infinity,
      child: Padding(
        padding: padding.copyWith(
          bottom: padding.bottom + (useBottomSafeArea ? bottomInset : 0),
        ),
        child: child,
      ),
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

        // A Material rather than a decorated Container: the body is usually a
        // list of tiles, and their ink has to land on the sheet's own surface.
        // Painted on a plain Container it would go to the Material behind the
        // sheet instead — invisible, and Flutter asserts about it.
        return Padding(
          // Outside the Material, so the sheet's surface stops at the top of
          // the keyboard instead of running behind it.
          padding: EdgeInsets.only(bottom: keyboardInset),
          child: Material(
            color: theme.colorScheme.surface,
            clipBehavior: Clip.antiAlias,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(Dimens.sheetRadius),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                // Measured against what is still visible: the ceiling has to
                // come down with the keyboard or the sheet is taller than the
                // room left for it.
                maxHeight:
                    (screenSize.height - keyboardInset) * maxHeightFactor,
              ),
              // Anywhere on the sheet that is not itself a control dismisses
              // the keyboard. On a sheet carrying a search field the keyboard
              // covers most of what there is to look at, and the reflex is to
              // tap the sheet rather than hunt for the keyboard's own dismiss
              // key. Translucent, so a tile or button under the pointer still
              // wins the tap.
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => FocusScope.of(context).unfocus(),
                child: Padding(
                  padding: EdgeInsets.only(left: left, right: right),
                  child: Stack(
                    children: [
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (showDragHandle) const _SheetDragHandle(),
                          if (title != null) ...[
                            Padding(
                              padding: EdgeInsets.fromLTRB(
                                16,
                                showDragHandle ? 0 : 12,
                                16,
                                0,
                              ),
                              child: Row(
                                children: [
                                  // Balances the button on the other side so the
                                  // title stays centred on the sheet rather than on
                                  // the space left beside it.
                                  if (showCloseButton)
                                    const SizedBox(width: _closeButtonSize),
                                  Expanded(
                                    child: Text(
                                      title,
                                      textAlign: TextAlign.center,
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ),
                                  if (showCloseButton)
                                    const _SheetCloseButton(),
                                ],
                              ),
                            ),
                            const Divider(height: 20),
                          ],
                          Flexible(
                            child: scrollable
                                ? SingleChildScrollView(child: body)
                                : body,
                          ),
                        ],
                      ),
                      // A titleless sheet has no header row to sit the button in,
                      // so there it is overlaid on the body's top-right corner
                      // instead — the same corner either way.
                      if (showCloseButton && title == null)
                        const Positioned(
                          top: 8,
                          right: 16,
                          child: _SheetCloseButton(),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Kept in step with the spacer that balances it across the title.
const _closeButtonSize = 32.0;

/// The dismiss affordance in a sheet's top-right corner. A neu button, like
/// every other control in the app — shallow, because it sits on the sheet's
/// header where a full-depth rim would read as a raised card.
class _SheetCloseButton extends StatelessWidget {
  const _SheetCloseButton();

  @override
  Widget build(BuildContext context) {
    return NeuIconButton(
      icon: Icons.close_rounded,
      size: _closeButtonSize,
      iconSize: 18,
      depth: 0.5,
      tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
      onPressed: () => Navigator.of(context).pop(),
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
          borderRadius: BorderRadius.circular(Dimens.radiusPill),
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
    useBottomSafeArea: false,
    // The list must own the bottom inset so its viewport can extend behind the
    // home indicator instead of being permanently shortened by outer padding.
    padding: EdgeInsets.zero,
    builder: (sheetContext) {
      final scheme = Theme.of(sheetContext).colorScheme;
      final bottomInset = MediaQuery.paddingOf(sheetContext).bottom;
      return Material(
        type: MaterialType.transparency,
        child: ListView.builder(
          shrinkWrap: true,
          padding: EdgeInsets.only(bottom: 8 + bottomInset),
          itemCount: options.length,
          itemBuilder: (context, index) {
            final option = options[index];
            final isSelected = option == selected;
            final isInitialTvFocus =
                deviceType.isTv &&
                (isSelected || (selected == null && index == 0));
            return ListTile(
              autofocus: isInitialTvFocus,
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
        ),
      );
    },
  );
}

/// A bottom sheet that picks one value out of a list too long to scan — a
/// search field filters it as the user types.
///
/// [searchIndex] returns the text a row is matched against; whatever the caller
/// wants searchable goes in there, so a bank can be found by its short name,
/// its full name or its code alike. Case does not matter — the index is folded
/// down here, so an index built straight out of a name still matches typing.
Future<T?> showAppSearchSheet<T>(
  BuildContext context, {
  String? title,
  required List<T> options,
  required T? selected,
  required String Function(T value) labelBuilder,
  required String Function(T value) searchIndex,
  String Function(T value)? subtitleBuilder,
  Widget Function(T value)? leadingBuilder,
  String? searchHint,
}) {
  return showAppBottomSheet<T>(
    context,
    title: title,
    scrollable: false,
    useBottomSafeArea: false,
    padding: EdgeInsets.zero,
    builder: (sheetContext) {
      return _SearchSheetBody<T>(
        options: options,
        selected: selected,
        labelBuilder: labelBuilder,
        searchIndex: searchIndex,
        subtitleBuilder: subtitleBuilder,
        leadingBuilder: leadingBuilder,
        searchHint: searchHint,
      );
    },
  );
}

class _SearchSheetBody<T> extends StatefulWidget {
  const _SearchSheetBody({
    required this.options,
    required this.selected,
    required this.labelBuilder,
    required this.searchIndex,
    this.subtitleBuilder,
    this.leadingBuilder,
    this.searchHint,
  });

  final List<T> options;
  final T? selected;
  final String Function(T value) labelBuilder;
  final String Function(T value) searchIndex;
  final String Function(T value)? subtitleBuilder;
  final Widget Function(T value)? leadingBuilder;
  final String? searchHint;

  @override
  State<_SearchSheetBody<T>> createState() => _SearchSheetBodyState<T>();
}

class _SearchSheetBodyState<T> extends State<_SearchSheetBody<T>> {
  final _controller = TextEditingController();
  late List<T> _visible = widget.options;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    final needle = query.trim().toLowerCase();
    setState(() {
      _visible = needle.isEmpty
          ? widget.options
          : widget.options
                .where(
                  (o) => widget.searchIndex(o).toLowerCase().contains(needle),
                )
                .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    // The sheet is already lifted clear of the keyboard, and the keyboard
    // covers the home indicator, so this inset only applies while it is down.
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom > 0
        ? 0.0
        : MediaQuery.paddingOf(context).bottom;

    return Material(
      type: MaterialType.transparency,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _controller,
              autofocus: !deviceType.isTv,
              textInputAction: TextInputAction.search,
              onChanged: _onQueryChanged,
              decoration: InputDecoration(
                isDense: true,
                hintText: widget.searchHint,
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () {
                          _controller.clear();
                          _onQueryChanged('');
                        },
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(Dimens.radiusCard),
                ),
              ),
            ),
          ),
          if (_visible.isEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(16, 24, 16, 24 + bottomInset),
              child: Text(l10n.searchNoResult),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                // Scrolling the results is the other way a user signals they
                // are done typing.
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                // The list owns the bottom inset so its viewport can run behind
                // the home indicator instead of stopping short of it.
                padding: EdgeInsets.only(bottom: 8 + bottomInset),
                itemCount: _visible.length,
                itemBuilder: (context, index) {
                  final option = _visible[index];
                  final isSelected = option == widget.selected;
                  final subtitle = widget.subtitleBuilder?.call(option);
                  final isInitialTvFocus =
                      deviceType.isTv &&
                      (isSelected || (widget.selected == null && index == 0));

                  return ListTile(
                    autofocus: isInitialTvFocus,
                    leading: widget.leadingBuilder?.call(option),
                    title: Text(
                      widget.labelBuilder(option),
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : null,
                        color: isSelected ? scheme.primary : null,
                      ),
                    ),
                    subtitle: subtitle == null
                        ? null
                        : Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                    selected: isSelected,
                    trailing: isSelected
                        ? Icon(Icons.check, color: scheme.primary)
                        : null,
                    onTap: () => Navigator.pop(context, option),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
