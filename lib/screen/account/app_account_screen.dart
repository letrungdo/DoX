import 'package:auto_route/auto_route.dart';
import 'package:do_x/constants/dimens.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/extensions/widget_extensions.dart';
import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/router/app_router.gr.dart';
import 'package:do_x/screen/core/screen_state.dart';
import 'package:do_x/screen/modal/crop_image_modal.dart';
import 'package:do_x/view_model/app_account_view_model.dart';
import 'package:do_x/widgets/account_avatar.dart';
import 'package:do_x/widgets/app_bar/app_bar_base.dart';
import 'package:do_x/widgets/app_scaffold.dart';
import 'package:do_x/widgets/dialog/app_modal.dart';
import 'package:do_x/widgets/dialog/dialog_action_button.dart';
import 'package:do_x/widgets/input/password_field.dart';
import 'package:do_x/widgets/neu/neu_card.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Ways to change the account picture, in the order the sheet offers them.
enum _AvatarAction { gallery, camera, remove }

@RoutePage()
class AppAccountScreen extends StatefulScreen implements AutoRouteWrapper {
  const AppAccountScreen({super.key});

  @override
  State<AppAccountScreen> createState() => _AppAccountScreenState();

  @override
  Widget wrappedRoute(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppAccountViewModel(), //
      child: this,
    );
  }
}

class _AppAccountScreenState
    extends ScreenState<AppAccountScreen, AppAccountViewModel> {
  static final _dateFormat = DateFormat('dd/MM/yyyy');
  static final _dateTimeFormat = DateFormat('HH:mm dd/MM/yyyy');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppScaffold(
      appBar: DoAppBar(title: l10n.accountTitle),
      // The avatar URL is selected alongside the user: it lives on the user's
      // metadata, and a fresh User instance is not reliably unequal to the old
      // one, so a picture change would otherwise not repaint.
      body: Selector<AppAccountViewModel, (User?, String?, bool)>(
        selector: (_, vm) => (vm.user, vm.avatarUrl, vm.isBusy),
        builder: (context, state, _) {
          final user = state.$1;
          // Signing out is what closes this page; for the frame between the
          // session going and the pop landing there is no user to describe.
          if (user == null) return const SizedBox.shrink();
          return SingleChildScrollView(
            child: Padding(
              padding: Dimens.screenPadding,
              child: _buildBody(l10n, user, state.$2, state.$3),
            ).contentConstrainedBox(),
          );
        },
      ),
    );
  }

  Widget _buildBody(
    AppLocalizations l10n,
    User user,
    String? avatarUrl,
    bool isBusy,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildIdentityCard(l10n, user, avatarUrl, isBusy),
        const SizedBox(height: 24),
        _buildSectionLabel(l10n.accountSectionSecurity),
        const SizedBox(height: 10),
        _buildActionCard(
          icon: Icons.lock_reset_rounded,
          title: l10n.changePassword,
          subtitle: l10n.changePasswordSubtitle,
          onTap: isBusy ? null : () => context.pushRoute(UpdatePasswordRoute()),
        ),
        const SizedBox(height: 12),
        _buildActionCard(
          icon: Icons.logout_rounded,
          title: l10n.logout,
          onTap: isBusy ? null : () => _confirmSignOut(l10n),
        ),
        const SizedBox(height: 24),
        _buildSectionLabel(l10n.accountSectionDanger),
        const SizedBox(height: 10),
        _buildActionCard(
          icon: Icons.delete_forever_rounded,
          title: l10n.deleteAccount,
          subtitle: l10n.deleteAccountSubtitle,
          color: context.theme.colorScheme.error,
          onTap: isBusy ? null : () => _confirmDelete(l10n),
        ),
      ],
    );
  }

  Widget _buildIdentityCard(
    AppLocalizations l10n,
    User user,
    String? avatarUrl,
    bool isBusy,
  ) {
    final email = user.email ?? '';
    final confirmed = user.emailConfirmedAt != null;

    return NeuCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AccountAvatar(
                email: email,
                avatarUrl: avatarUrl,
                onTap: isBusy ? null : () => _editAvatar(l10n, avatarUrl),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _buildVerifiedBadge(l10n, confirmed),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 28),
          _buildInfoRow(
            l10n.accountMemberSince,
            _formatDate(user.createdAt, _dateFormat),
          ),
          const SizedBox(height: 8),
          _buildInfoRow(
            l10n.accountLastSignIn,
            _formatDate(user.lastSignInAt, _dateTimeFormat),
          ),
          if (!confirmed) ...[
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: vm.resendConfirmationEmail,
                icon: const Icon(Icons.send_rounded, size: 18),
                label: Text(l10n.resendConfirmationEmail),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVerifiedBadge(AppLocalizations l10n, bool confirmed) {
    final color = confirmed
        ? context.colors.success
        : context.theme.colorScheme.error;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          confirmed ? Icons.verified_rounded : Icons.error_outline_rounded,
          size: 16,
          color: color,
        ),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            confirmed ? l10n.accountEmailVerified : l10n.accountEmailUnverified,
            style: context.theme.textTheme.bodySmall?.copyWith(color: color),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    final textTheme = context.theme.textTheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: textTheme.bodyMedium?.copyWith(
            color: context.theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: context.theme.textTheme.labelMedium?.copyWith(
        color: context.theme.colorScheme.onSurfaceVariant,
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    String? subtitle,
    Color? color,
    VoidCallback? onTap,
  }) {
    final foreground = color ?? context.theme.colorScheme.onSurface;
    return NeuCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 24, color: foreground),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: context.theme.textTheme.titleSmall?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: context.theme.textTheme.bodySmall?.copyWith(
                      color: context.theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: foreground),
        ],
      ),
    );
  }

  String _formatDate(String? isoDate, DateFormat format) {
    final parsed = DateTime.tryParse(isoDate ?? '');
    return parsed == null ? '-' : format.format(parsed.toLocal());
  }

  /// Offers the ways in, then routes the chosen one through the shared
  /// cropper. [currentUrl] decides whether removing is even on the menu.
  Future<void> _editAvatar(AppLocalizations l10n, String? currentUrl) async {
    final actions = [
      _AvatarAction.gallery,
      _AvatarAction.camera,
      if (currentUrl != null && currentUrl.isNotEmpty) _AvatarAction.remove,
    ];
    final action = await showAppOptionSheet<_AvatarAction>(
      context,
      title: l10n.changeAvatar,
      options: actions,
      selected: null,
      labelBuilder: (value) => switch (value) {
        _AvatarAction.gallery => l10n.chooseFromGallery,
        _AvatarAction.camera => l10n.takePhoto,
        _AvatarAction.remove => l10n.removeAvatar,
      },
    );
    if (action == null || !mounted) return;

    if (action == _AvatarAction.remove) {
      await vm.removeAvatar();
      return;
    }

    final picked = await vm.pickAvatar(
      action == _AvatarAction.camera ? ImageSource.camera : ImageSource.gallery,
    );
    if (picked == null || !mounted) return;

    // The cropper is locked to 1:1 already, which is the shape every avatar in
    // the app is drawn in.
    await showAppBottomSheet<void>(
      context,
      enableDrag: false,
      scrollable: false,
      builder: (_) => CropImageModal(image: picked, onCropped: vm.uploadAvatar),
    );
  }

  Future<void> _confirmSignOut(AppLocalizations l10n) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: l10n.confirmLogout,
      message: l10n.confirmLogoutMessage,
      confirmText: l10n.logout,
    );
    if (!confirmed || !mounted) return;
    await vm.signOut();
  }

  /// Deleting an account cannot be walked back, so the dialog asks for the
  /// password rather than settling for a second tap.
  Future<void> _confirmDelete(AppLocalizations l10n) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final password = await showAppModal<String>(
      context,
      builder: (dialogContext) => AppDialog(
        title: l10n.deleteAccount,
        scrollable: true,
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.deleteAccountWarning),
              const SizedBox(height: Dimens.modalItemSpacing),
              Text(l10n.deleteAccountPasswordPrompt),
              const SizedBox(height: Dimens.modalItemSpacing),
              PasswordField(
                controller: controller,
                labelText: l10n.passwordLabel,
                validator: (value) =>
                    (value ?? '').isEmpty ? l10n.passwordTooShort : null,
              ),
            ],
          ),
        ),
        actions: [
          DialogActionButton(
            text: l10n.cancel,
            kind: DialogActionKind.cancel,
            onPressed: () => Navigator.pop(dialogContext),
          ),
          DialogActionButton(
            text: l10n.deleteAccount,
            kind: DialogActionKind.destructive,
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(dialogContext, controller.text);
            },
          ),
        ],
      ),
    );
    controller.dispose();
    if (password == null || !mounted) return;
    await vm.deleteAccount(password);
  }
}
