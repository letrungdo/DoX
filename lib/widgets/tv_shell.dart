import 'package:do_x/constants/dimens.dart';
import 'package:do_x/utils/device_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Everything the app does differently because it is running on a television.
///
/// Wraps the whole navigator once, rather than being sprinkled through the
/// pages, and is a pass-through on every other device — so a phone build
/// carries none of it.
///
/// Two things happen here:
///
/// * **Overscan.** A TV can crop the outer few percent of the picture, and the
///   panel has no notch for the system to report, so the padding has to be
///   invented. Injecting it into [MediaQuery] means every `SafeArea` already in
///   the app — `AppScaffold`, dialogs, sheets — keeps its content inside the
///   visible area without any of them knowing about televisions.
/// * **Getting back out of a text field.** `EditableText` binds
///   `DirectionalFocusAction.forTextField()`, which drops any arrow key whose
///   intent has `ignoreTextFields` set — and every arrow in `WidgetsApp`'s
///   default map has it set, so the keys are free to move the caret instead.
///   On a desktop that is right. On a TV it is a trap with no way out: the
///   D-pad walks into the first field of the login form and stays there, with
///   no other field, no submit button and no tab bar ever reachable again.
///   Re-binding the four arrows to the same intent with the flag cleared is
///   what frees them; the caret is not lost with it, because Android TV edits
///   text in its own full-screen IME rather than in place.
/// * **The OK button.** Depending on the remote it arrives as `select` or as a
///   game-pad button rather than as `enter`, neither of which the default
///   shortcut map turns into an activation.
///
/// This sits below `WidgetsApp`'s own `Shortcuts`, and a key walks up from the
/// focused node, so these bindings are found first and anything not listed
/// still falls through to Flutter's defaults. `NavigationMode.directional`
/// comes along for the ride: it is what Flutter documents for a television,
/// and it lets focus rest on a disabled control so the remote can read past it
/// instead of skipping it silently.
class TvShell extends StatelessWidget {
  const TvShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!deviceType.isTv) return child;

    final media = MediaQuery.of(context);
    return MediaQuery(
      data: media.copyWith(
        padding: media.padding + Dimens.tvOverscan,
        viewPadding: media.viewPadding + Dimens.tvOverscan,
        navigationMode: NavigationMode.directional,
      ),
      child: Shortcuts(
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.gameButtonA): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.arrowUp): DirectionalFocusIntent(
            TraversalDirection.up,
            ignoreTextFields: false,
          ),
          SingleActivator(LogicalKeyboardKey.arrowDown): DirectionalFocusIntent(
            TraversalDirection.down,
            ignoreTextFields: false,
          ),
          SingleActivator(LogicalKeyboardKey.arrowLeft): DirectionalFocusIntent(
            TraversalDirection.left,
            ignoreTextFields: false,
          ),
          SingleActivator(
            LogicalKeyboardKey.arrowRight,
          ): DirectionalFocusIntent(
            TraversalDirection.right,
            ignoreTextFields: false,
          ),
        },
        child: child,
      ),
    );
  }
}
