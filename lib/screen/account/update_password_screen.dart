import 'package:auto_route/auto_route.dart';
import 'package:do_x/constants/dimens.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/extensions/widget_extensions.dart';
import 'package:do_x/screen/core/screen_state.dart';
import 'package:do_x/view_model/update_password_view_model.dart';
import 'package:do_x/widgets/app_bar/app_bar_base.dart';
import 'package:do_x/widgets/app_scaffold.dart';
import 'package:do_x/widgets/button/button.dart';
import 'package:do_x/widgets/input/password_field.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Sets a new password, from two directions: the account page (where the
/// current one is asked for) and the link in a password-reset email (where the
/// mailbox already stood in for it).
@RoutePage()
class UpdatePasswordScreen extends StatefulScreen implements AutoRouteWrapper {
  const UpdatePasswordScreen({super.key, this.isRecovery = false});

  /// True when a recovery email opened this page.
  final bool isRecovery;

  @override
  State<UpdatePasswordScreen> createState() => _UpdatePasswordScreenState();

  @override
  Widget wrappedRoute(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => UpdatePasswordViewModel(isRecovery: isRecovery), //
      child: this,
    );
  }
}

class _UpdatePasswordScreenState
    extends ScreenState<UpdatePasswordScreen, UpdatePasswordViewModel> {
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isRecovery = widget.isRecovery;

    return AppScaffold(
      // Arriving from an email, this page can be the only thing on the stack.
      appBar: DoAppBar(
        title: isRecovery ? l10n.setNewPassword : l10n.changePassword,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: Dimens.screenPadding,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 10),
                Text(
                  isRecovery
                      ? l10n.setNewPasswordMessage
                      : l10n.changePasswordSubtitle,
                  style: context.theme.textTheme.bodyMedium?.copyWith(
                    color: context.theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                if (!isRecovery) ...[
                  PasswordField(
                    labelText: l10n.currentPassword,
                    autofillHints: const [AutofillHints.password],
                    textInputAction: TextInputAction.next,
                    onChanged: vm.onCurrentPasswordChanged,
                    validator: (value) =>
                        (value ?? '').isEmpty ? l10n.passwordTooShort : null,
                  ),
                  const SizedBox(height: 15),
                ],
                PasswordField(
                  labelText: l10n.newPassword,
                  autofillHints: const [AutofillHints.newPassword],
                  textInputAction: TextInputAction.next,
                  onChanged: vm.onNewPasswordChanged,
                  validator: (value) =>
                      (value ?? '').length < 6 ? l10n.passwordTooShort : null,
                ),
                const SizedBox(height: 15),
                PasswordField(
                  labelText: l10n.confirmPassword,
                  autofillHints: const [AutofillHints.newPassword],
                  textInputAction: TextInputAction.done,
                  validator: vm.validateConfirmation,
                ),
                const SizedBox(height: 30),
                Selector<UpdatePasswordViewModel, bool>(
                  selector: (_, vm) => vm.isBusy,
                  builder: (context, isBusy, _) => DoButton(
                    isBusy: isBusy,
                    onPressed: _submit,
                    text: l10n.updatePassword,
                  ),
                ),
              ],
            ),
          ),
        ).contentConstrainedBox(),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    vm.submit();
  }
}
