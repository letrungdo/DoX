import 'package:do_x/constants/dimens.dart';
import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/services/supabase_service.dart';
import 'package:do_x/widgets/dialog/app_modal.dart';
import 'package:do_x/widgets/dialog/dialog_action_button.dart';
import 'package:do_x/widgets/input/password_field.dart';
import 'package:flutter/material.dart';

/// Asks for the signed-in user's password and checks it against Supabase
/// before letting a destructive action through.
///
/// A second tap is enough for something that can be undone; wiping chicken
/// records cannot be, so the password is what stands between an unlocked phone
/// and the data. Returns true only once the password checked out.
///
/// With no signed-in account there is nothing to re-authenticate against, so
/// it falls back to a plain confirmation rather than locking the action away.
Future<bool> showPasswordConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmText,
  String? prompt,
}) async {
  if (supabase.auth.currentUser?.email == null) {
    return showAppConfirmDialog(
      context,
      title: title,
      message: message,
      confirmText: confirmText,
      isDestructive: true,
    );
  }
  final password = await showPasswordVerifyDialog(
    context,
    title: title,
    message: message,
    confirmText: confirmText,
    prompt: prompt,
  );
  return password != null;
}

/// The same dialog, handing back the password it verified — for a caller that
/// has to pass it on, such as the account deletion the server re-checks.
///
/// Null when the dialog was dismissed, or when nobody is signed in and there is
/// therefore nothing to verify against.
Future<String?> showPasswordVerifyDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmText,
  String? prompt,
}) {
  final email = supabase.auth.currentUser?.email;
  if (email == null) return Future.value(null);

  return showAppModal<String>(
    context,
    builder: (dialogContext) => _PasswordConfirmDialog(
      email: email,
      title: title,
      message: message,
      confirmText: confirmText,
      prompt: prompt,
    ),
  );
}

/// A widget rather than a `StatefulBuilder` around a locally held controller:
/// the dialog stays in the tree through its exit animation, so a controller
/// disposed as soon as `showAppModal` returned was still being read by the
/// field that was on its way out.
class _PasswordConfirmDialog extends StatefulWidget {
  const _PasswordConfirmDialog({
    required this.email,
    required this.title,
    required this.message,
    required this.confirmText,
    this.prompt,
  });

  final String email;
  final String title;
  final String message;
  final String confirmText;

  /// Line above the field. Defaults to the generic "type your password to
  /// confirm the deletion".
  final String? prompt;

  @override
  State<_PasswordConfirmDialog> createState() => _PasswordConfirmDialogState();
}

class _PasswordConfirmDialogState extends State<_PasswordConfirmDialog> {
  final _controller = TextEditingController();
  bool _loading = false;
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final l10n = AppLocalizations.of(context);
    FocusManager.instance.primaryFocus?.unfocus();
    final password = _controller.text;
    if (password.isEmpty) {
      setState(() => _errorText = l10n.passwordRequired);
      return;
    }
    setState(() {
      _loading = true;
      _errorText = null;
    });
    try {
      await supabase.auth.signInWithPassword(
        email: widget.email,
        password: password,
      );
      if (!mounted) return;
      Navigator.pop(context, password);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorText = l10n.passwordIncorrect;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final errorText = _errorText;
    return AppDialog(
      title: widget.title,
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.message),
          const SizedBox(height: Dimens.modalItemSpacing),
          Text(widget.prompt ?? l10n.confirmPasswordToDelete),
          const SizedBox(height: Dimens.modalItemSpacing),
          PasswordField(
            controller: _controller,
            labelText: l10n.passwordLabel,
            errorText: errorText,
            onSubmitted: (_) => _confirm(),
            onChanged: (_) {
              if (_errorText != null) setState(() => _errorText = null);
            },
          ),
        ],
      ),
      actions: [
        DialogActionButton(
          text: l10n.cancel,
          kind: DialogActionKind.cancel,
          onPressed: () => Navigator.pop(context),
        ),
        DialogActionButton(
          text: widget.confirmText,
          kind: DialogActionKind.destructive,
          loading: _loading,
          onPressed: _confirm,
        ),
      ],
    );
  }
}
