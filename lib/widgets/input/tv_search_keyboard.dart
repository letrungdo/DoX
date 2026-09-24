import 'dart:async';

import 'package:collection/collection.dart';
import 'package:do_x/utils/device_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

/// The keyboard side of a television search page: a box at the top, results
/// below it.
///
/// Wrap the page's [TextField] in this, give the field
/// `onEditingComplete: () => TvSearchKeyboard.submit(...)`, and put the
/// results under a `Focus` holding [TvSearchKeyboard.resultsNode]'s node.
///
/// Two things a television needs that a phone does not:
///
/// * **Search hands the remote to the results.** The framework's default for
///   the keyboard's Search key is to unfocus the field, which leaves the focus
///   on the page's scope — and `TvShell` rescues a remote left on a scope by
///   putting it on the first control of the page, which is this very field.
///   Focusing the field opens the keyboard, so Search appeared to do nothing
///   at all. Moving the focus into the results instead is what the viewer
///   pressed Search for, and taking it off the field closes the keyboard.
/// * **OK on the field opens the keyboard again.** With nothing to move to the
///   field keeps the focus and only the keyboard goes away, and OK on a
///   focused field is not a tap — nothing would bring the keyboard back.
///
/// Everywhere else it is a pass-through, and [submit] keeps the framework's
/// own behaviour.
class TvSearchKeyboard extends StatelessWidget {
  const TvSearchKeyboard({super.key, required this.field, required this.child});

  /// The search field's own focus node.
  final FocusNode field;

  final Widget child;

  /// A node for the `Focus` around the results: never focused itself, and
  /// not a stop of its own, only something to look for the first result in.
  static FocusNode resultsNode({String? debugLabel}) => FocusNode(
    debugLabel: debugLabel,
    canRequestFocus: false,
    skipTraversal: true,
  );

  /// What the field's Search key does.
  ///
  /// The keyboard goes at once. The remote moves to the first result the
  /// frame after [pending] — the search the key may have cut short, still
  /// waiting out its debounce or on its way back from a server — so it lands
  /// on what was searched for, not on the list from a letter ago. With no
  /// results it stays on the field, keyboard closed.
  static void submit({
    required FocusNode field,
    required FocusNode results,
    Future<void>? pending,
  }) {
    if (!deviceType.isTv) {
      // The framework's default for a Search key, which providing an
      // `onEditingComplete` replaces.
      field.unfocus();
      return;
    }
    unawaited(SystemChannels.textInput.invokeMethod<void>('TextInput.hide'));
    unawaited(_moveIntoResults(field, results, pending));
  }

  static Future<void> _moveIntoResults(
    FocusNode field,
    FocusNode results,
    Future<void>? pending,
  ) async {
    if (pending != null) await pending;
    // The results for the query are built by the next frame, not by the time
    // the search returns.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      // The viewer went somewhere else, or back into the keyboard, while the
      // search was out: the remote is theirs.
      if (!field.hasPrimaryFocus) return;
      results.traversalDescendants.firstOrNull?.requestFocus();
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  @override
  Widget build(BuildContext context) {
    if (!deviceType.isTv) return child;
    return Actions(
      actions: <Type, Action<Intent>>{
        ActivateIntent: _ReopenKeyboardAction(field),
      },
      child: child,
    );
  }
}

/// OK on the remote, while the field has it: brings the keyboard back.
class _ReopenKeyboardAction extends Action<ActivateIntent> {
  _ReopenKeyboardAction(this.field);

  final FocusNode field;

  @override
  bool isEnabled(ActivateIntent intent) => field.hasPrimaryFocus;

  @override
  Object? invoke(ActivateIntent intent) {
    // The field's `Focus` is built by its `EditableText`, so the state that
    // owns the keyboard connection is right above the node's context.
    field.context
        ?.findAncestorStateOfType<EditableTextState>()
        ?.requestKeyboard();
    return null;
  }
}
