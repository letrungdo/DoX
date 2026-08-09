import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/view_model/chicken_view_model.dart';
import 'package:do_x/widgets/dialog/app_modal.dart';
import 'package:do_x/widgets/dialog/dialog_action_button.dart';
import 'package:do_x/widgets/input/cute_text_field.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Opens the "who can see my chicken data" dialog and reports the outcome on a
/// snack bar. Loads the current viewers first, so the list is never a stale one
/// from the last time the dialog was opened.
Future<void> showChickenSharingDialog(BuildContext context) async {
  final vm = context.read<ChickenViewModel>();
  await vm.loadSharing();
  if (!context.mounted) return;

  // The dialog hands back the message rather than showing it itself: its own
  // context is gone by then, and a snack bar needs one that is still mounted.
  final message = await showAppModal<String>(
    context,
    builder: (_) => const _ChickenSharingDialog(),
  );
  if (message == null || !context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

/// A widget rather than a `StatefulBuilder` over a locally held controller: the
/// dialog stays in the tree through its exit animation, so a controller
/// disposed the moment [showAppModal] returned would still be read by the field
/// on its way out.
class _ChickenSharingDialog extends StatefulWidget {
  const _ChickenSharingDialog();

  @override
  State<_ChickenSharingDialog> createState() => _ChickenSharingDialogState();
}

class _ChickenSharingDialogState extends State<_ChickenSharingDialog> {
  final _emailController = TextEditingController();
  bool _loading = false;
  String? _errorText;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _revoke(String userId) async {
    setState(() => _loading = true);
    try {
      await context.read<ChickenViewModel>().revokeShare(userId);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _share() async {
    final l10n = AppLocalizations.of(context);
    FocusManager.instance.primaryFocus?.unfocus();
    final email = _emailController.text.trim();
    if (!email.contains('@')) {
      setState(() => _errorText = l10n.emailInvalid);
      return;
    }
    setState(() {
      _loading = true;
      _errorText = null;
    });
    try {
      final emailSent = await context.read<ChickenViewModel>().shareWith(email);
      if (!mounted) return;
      Navigator.pop(
        context,
        emailSent
            ? l10n.shareAccessAddedEmailSent
            : l10n.shareAccessAddedEmailFailed,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorText = _shareErrorMessage(l10n, error);
      });
    }
  }

  /// `share_chicken_data` rejects a few cases by name, and "Could not share:
  /// PostgrestException(…)" tells the user nothing about which one they hit.
  /// The messages are raised by our own migration, so matching on them is a
  /// contract we control.
  String _shareErrorMessage(AppLocalizations l10n, Object error) {
    final message = error is PostgrestException
        ? error.message
        : error.toString();
    if (message.contains('No registered account')) {
      return l10n.shareEmailNotRegistered;
    }
    if (message.contains('cannot share data with yourself')) {
      return l10n.shareEmailIsYourself;
    }
    return l10n.shareAccessFailed(message);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Watched: revoking a viewer has to drop it from the list below.
    final viewers = context.watch<ChickenViewModel>().shareViewers;

    return AppDialog(
      title: l10n.chickenSharing,
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.chickenSharingDescription),
          const SizedBox(height: 16),
          CuteTextField(
            controller: _emailController,
            label: l10n.shareWithEmail,
            keyboardType: TextInputType.emailAddress,
            errorText: _errorText,
            onChanged: (_) {
              if (_errorText != null) setState(() => _errorText = null);
            },
          ),
          const SizedBox(height: 20),
          Text(l10n.sharedWith, style: context.theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          if (viewers.isEmpty)
            Text(l10n.notSharedYet)
          else
            for (final viewer in viewers)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: const Icon(Icons.person_outline),
                title: Text(viewer.email),
                trailing: IconButton(
                  icon: const Icon(Icons.person_remove_outlined),
                  tooltip: l10n.revokeAccess,
                  onPressed: _loading ? null : () => _revoke(viewer.userId),
                ),
              ),
        ],
      ),
      actions: [
        DialogActionButton(
          text: l10n.close,
          kind: DialogActionKind.cancel,
          onPressed: () => Navigator.pop(context),
        ),
        DialogActionButton(
          text: l10n.shareAction,
          loading: _loading,
          onPressed: _share,
        ),
      ],
    );
  }
}
