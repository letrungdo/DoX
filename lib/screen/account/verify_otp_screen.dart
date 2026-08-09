import 'package:auto_route/auto_route.dart';
import 'package:do_x/constants/dimens.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/extensions/widget_extensions.dart';
import 'package:do_x/screen/core/screen_state.dart';
import 'package:do_x/view_model/verify_otp_view_model.dart';
import 'package:do_x/widgets/app_bar/app_bar_base.dart';
import 'package:do_x/widgets/app_scaffold.dart';
import 'package:do_x/widgets/button/button.dart';
import 'package:do_x/widgets/text_field.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// The way through when the link in the email cannot come back to this device.
@RoutePage()
class VerifyOtpScreen extends StatefulScreen implements AutoRouteWrapper {
  const VerifyOtpScreen({
    super.key,
    required this.email,
    required this.purpose,
  });

  final String email;
  final OtpPurpose purpose;

  @override
  State<VerifyOtpScreen> createState() => _VerifyOtpScreenState();

  @override
  Widget wrappedRoute(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => VerifyOtpViewModel(email: email, purpose: purpose), //
      child: this,
    );
  }
}

class _VerifyOtpScreenState
    extends ScreenState<VerifyOtpScreen, VerifyOtpViewModel> {
  final _formKey = GlobalKey<FormState>();

  /// Short enough to let any sane OTP length through, long enough to catch a
  /// half-typed code. The project decides the real length, so it is not pinned
  /// here or in the copy.
  static const _minLength = 6;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppScaffold(
      appBar: DoAppBar(title: l10n.verifyCodeTitle),
      body: SingleChildScrollView(
        child: Padding(
          padding: Dimens.screenPadding,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                Icon(
                  Icons.mark_email_read_outlined,
                  size: 64,
                  color: context.theme.colorScheme.primary,
                ),
                const SizedBox(height: 20),
                Text(
                  l10n.verifyCodeMessage(widget.email),
                  textAlign: TextAlign.center,
                  style: context.theme.textTheme.bodyMedium?.copyWith(
                    color: context.theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 28),
                DoTextField(
                  labelText: l10n.verifyCodeLabel,
                  keyboardType: TextInputType.number,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  textInputAction: TextInputAction.done,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 22, letterSpacing: 6),
                  onChanged: vm.onCodeChanged,
                  validator: (value) => (value ?? '').trim().length < _minLength
                      ? l10n.verifyCodeRequired
                      : null,
                ),
                const SizedBox(height: 28),
                Selector<VerifyOtpViewModel, bool>(
                  selector: (_, vm) => vm.isBusy,
                  builder: (context, isBusy, _) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DoButton(
                        isBusy: isBusy,
                        onPressed: _submit,
                        text: l10n.verifyCodeAction,
                      ),
                      TextButton(
                        onPressed: isBusy ? null : vm.resend,
                        child: Text(l10n.resendCode),
                      ),
                    ],
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
