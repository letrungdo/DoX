import 'package:do_x/constants/dimens.dart';
import 'package:do_x/extensions/context_extensions.dart';
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
}) async {
  final email = supabase.auth.currentUser?.email;
  if (email == null) {
    return showAppConfirmDialog(
      context,
      title: title,
      message: message,
      confirmText: confirmText,
      isDestructive: true,
    );
  }

  final confirmed = await showAppModal<bool>(
    context,
    builder: (dialogContext) => _PasswordConfirmDialog(
      email: email,
      title: title,
      message: message,
      confirmText: confirmText,
    ),
  );
  return confirmed ?? false;
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
  });

  final String email;
  final String title;
  final String message;
  final String confirmText;

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
      Navigator.pop(context, true);
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
          Text(l10n.confirmPasswordToDelete),
          const SizedBox(height: Dimens.modalItemSpacing),
          PasswordField(
            controller: _controller,
            labelText: l10n.passwordLabel,
            onSubmitted: (_) => _confirm(),
            onChanged: (_) {
              if (_errorText != null) setState(() => _errorText = null);
            },
          ),
          if (errorText != null) ...[
            const SizedBox(height: 8),
            Text(
              errorText,
              style: TextStyle(color: context.colors.danger, fontSize: 13),
            ),
          ],
        ],
      ),
      actions: [
        DialogActionButton(
          text: l10n.cancel,
          kind: DialogActionKind.cancel,
          onPressed: () => Navigator.pop(context, false),
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
