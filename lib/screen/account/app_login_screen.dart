import 'package:auto_route/auto_route.dart';
import 'package:do_x/constants/dimens.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/extensions/text_style_extensions.dart';
import 'package:do_x/extensions/widget_extensions.dart';
import 'package:do_x/gen/assets.gen.dart';
import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/model/supabase_account.dart';
import 'package:do_x/router/app_router.gr.dart';
import 'package:do_x/screen/core/screen_state.dart';
import 'package:do_x/view_model/app_login_view_model.dart';
import 'package:do_x/view_model/verify_otp_view_model.dart';
import 'package:do_x/widgets/app_bar/app_bar_base.dart';
import 'package:do_x/widgets/app_scaffold.dart';
import 'package:do_x/widgets/button/button.dart';
import 'package:do_x/widgets/input/password_field.dart';
import 'package:do_x/widgets/dialog/app_modal.dart';
import 'package:do_x/widgets/neu/neu_card.dart';
import 'package:do_x/widgets/text_field.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

@RoutePage()
class AppLoginScreen extends StatefulScreen implements AutoRouteWrapper {
  const AppLoginScreen({super.key});

  @override
  State<AppLoginScreen> createState() => _AppLoginScreenState();

  @override
  Widget wrappedRoute(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppLoginViewModel(), //
      child: this,
    );
  }
}

/// What the form is showing right now. Bundled so one [Selector] covers the
/// whole screen instead of one per flag.
typedef _FormState = ({
  AuthMode mode,
  String? pendingEmail,
  bool isBusy,
  List<SupabaseAccount> savedAccounts,
});

class _AppLoginScreenState
    extends ScreenState<AppLoginScreen, AppLoginViewModel> {
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      // A guard redirects here, so this screen is often the only thing on the
      // stack the user can see. Without a bar there is no back button and no
      // way out of a feature they decided not to sign in to — so show one
      // whenever there is somewhere to go back to.
      appBar: Navigator.of(context).canPop() ? const DoAppBar() : null,
      top: true,
      bottom: true,
      body: SingleChildScrollView(
        child: Padding(
          padding: Dimens.screenPadding,
          child: _buildBody(),
        ).contentConstrainedBox(),
      ),
    );
  }

  Widget _buildBody() {
    return Selector<AppLoginViewModel, _FormState>(
      selector: (_, vm) => (
        mode: vm.mode,
        pendingEmail: vm.pendingConfirmationEmail,
        isBusy: vm.isBusy,
        savedAccounts: vm.savedAccounts,
      ),
      builder: (context, state, _) {
        final l10n = context.l10n;
        return Column(
          children: [
            const SizedBox(height: 50),
            _buildLogo(context),
            const SizedBox(height: 40),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 9),
              child: state.pendingEmail != null
                  ? _buildConfirmationPending(l10n, state)
                  : _buildForm(l10n, state),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLogo(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Assets.images.appIcon.image(
          width: 60,
          height: 60,
          fit: BoxFit.contain, //
        ),
        const SizedBox(width: 10),
        Text(
          "Do X",
          style: context.textTheme.primary.size24.copyWith(
            color: context.theme.colorScheme.primary, //
          ),
        ),
      ],
    );
  }

  Widget _buildForm(AppLocalizations l10n, _FormState state) {
    final isSignUp = state.mode == AuthMode.signUp;
    return Form(
      key: _formKey,
      child: Column(
        children: [
          if (!isSignUp && state.savedAccounts.isNotEmpty) ...[
            _SavedAccountPicker(
              accounts: state.savedAccounts,
              enabled: !state.isBusy,
              onSelect: vm.loginSavedAccount,
              onForget: _forgetSavedAccount,
            ),
            const SizedBox(height: 24),
          ],
          DoTextField(
            value: vm.email,
            labelText: l10n.emailLabel,
            autofillHints: const [AutofillHints.username, AutofillHints.email],
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            onChanged: vm.onEmailChanged,
            validator: (value) => _validateEmail(l10n, value),
          ),
          const SizedBox(height: 15),
          PasswordField(
            value: vm.password,
            labelText: l10n.passwordLabel,
            autofillHints: [
              isSignUp ? AutofillHints.newPassword : AutofillHints.password,
            ],
            textInputAction: isSignUp
                ? TextInputAction.next
                : TextInputAction.done,
            // Enter on the last field does what the button does, so a hardware
            // keyboard never has to reach for the mouse.
            onSubmitted: isSignUp ? null : (_) => _submit(),
            onChanged: vm.onPasswordChanged,
            validator: (value) => _validatePassword(l10n, value),
          ),
          if (isSignUp) ...[
            const SizedBox(height: 15),
            PasswordField(
              labelText: l10n.confirmPassword,
              autofillHints: const [AutofillHints.newPassword],
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              onChanged: vm.onConfirmPasswordChanged,
              validator: (value) =>
                  value == vm.password ? null : l10n.passwordMismatch,
            ),
          ] else
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: state.isBusy ? null : vm.onForgotPassword,
                child: Text(l10n.forgotPassword),
              ),
            ),
          SizedBox(height: isSignUp ? 25 : 15),
          DoButton(
            isBusy: state.isBusy,
            onPressed: _submit,
            text: isSignUp ? l10n.signUp : l10n.login,
          ),
          TextButton(
            onPressed: state.isBusy
                ? null
                : () =>
                      vm.setMode(isSignUp ? AuthMode.signIn : AuthMode.signUp),
            child: Text(
              isSignUp ? l10n.haveAccountSignIn : l10n.noAccountSignUp,
            ),
          ),
        ],
      ),
    );
  }

  /// Shown after a sign-up, and after a sign-in that failed only because the
  /// address was never activated. Both leave the user with the same one thing
  /// to do, so both land here rather than on a snack bar they can't act on.
  Widget _buildConfirmationPending(AppLocalizations l10n, _FormState state) {
    return Column(
      children: [
        Icon(
          Icons.mark_email_unread_outlined,
          size: 64,
          color: context.theme.colorScheme.primary,
        ),
        const SizedBox(height: 20),
        Text(
          l10n.signUpCheckEmail(state.pendingEmail!),
          textAlign: TextAlign.center,
          style: context.theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: 30),
        DoButton(
          isBusy: state.isBusy,
          onPressed: vm.resendConfirmationEmail,
          text: l10n.resendConfirmationEmail,
        ),
        // For the inbox that was opened on another device, where the link in
        // the email can never reach this one.
        TextButton(
          onPressed: state.isBusy
              ? null
              : () => context.pushRoute(
                  VerifyOtpRoute(
                    email: state.pendingEmail!,
                    purpose: OtpPurpose.signup,
                  ),
                ),
          child: Text(l10n.enterCodeInstead),
        ),
        TextButton(
          onPressed: state.isBusy ? null : vm.cancelPendingConfirmation,
          child: Text(l10n.haveAccountSignIn),
        ),
      ],
    );
  }

  String? _validateEmail(AppLocalizations l10n, String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return l10n.emailRequired;
    // Deliberately loose: the address is verified by an email either way, and
    // a strict pattern only ever rejects addresses that turn out to be real.
    if (!email.contains('@') || !email.contains('.')) return l10n.emailInvalid;
    return null;
  }

  String? _validatePassword(AppLocalizations l10n, String? value) {
    if ((value ?? '').length < 6) return l10n.passwordTooShort;
    return null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    vm.submit();
  }

  Future<void> _forgetSavedAccount(SupabaseAccount account) async {
    final l10n = context.l10n;
    final confirmed = await showAppConfirmDialog(
      context,
      title: l10n.logout,
      message: l10n.forgetAccountConfirm(account.email),
      confirmText: l10n.delete,
      isDestructive: true,
    );
    if (confirmed) await vm.forgetSavedAccount(account);
  }
}

/// Accounts that authenticated successfully before. Tapping one signs in with
/// its credentials; the close button removes only that stored login.
class _SavedAccountPicker extends StatelessWidget {
  const _SavedAccountPicker({
    required this.accounts,
    required this.enabled,
    required this.onSelect,
    required this.onForget,
  });

  final List<SupabaseAccount> accounts;
  final bool enabled;
  final ValueChanged<SupabaseAccount> onSelect;
  final Future<void> Function(SupabaseAccount account) onForget;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = context.theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            l10n.savedAccounts,
            style: context.textTheme.secondary.size13,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: accounts
              .map((account) => _accountChip(context, scheme, account))
              .toList(),
        ),
      ],
    );
  }

  Widget _accountChip(
    BuildContext context,
    ColorScheme scheme,
    SupabaseAccount account,
  ) {
    return NeuCard(
      radius: 14,
      depth: 0.5,
      onTap: enabled ? () => onSelect(account) : null,
      padding: const EdgeInsets.only(left: 12, right: 4, top: 6, bottom: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.account_circle_rounded,
            size: 18,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Text(
              account.email,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: scheme.onSurface,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          IconButton(
            key: ValueKey('forget-${account.email}'),
            tooltip: context.l10n.delete,
            onPressed: enabled ? () => onForget(account) : null,
            iconSize: 16,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
            color: scheme.onSurfaceVariant,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}
