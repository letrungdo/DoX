import 'package:auto_route/auto_route.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/extensions/text_style_extensions.dart';
import 'package:do_x/extensions/widget_extensions.dart';
import 'package:do_x/screen/core/screen_state.dart';
import 'package:do_x/view_model/chicken_login_view_model.dart';
import 'package:do_x/widgets/button/button.dart';
import 'package:do_x/widgets/text_field.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

@RoutePage()
class ChickenLoginScreen extends StatefulScreen implements AutoRouteWrapper {
  const ChickenLoginScreen({super.key});

  @override
  State<ChickenLoginScreen> createState() => _ChickenLoginScreenState();

  @override
  Widget wrappedRoute(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ChickenLoginViewModel(), //
      child: this,
    );
  }
}

class _ChickenLoginScreenState extends ScreenState<ChickenLoginScreen, ChickenLoginViewModel> {
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(15), //
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        const SizedBox(height: 50),
        Text(
          "Quản lý gà",
          style: context.textTheme.primary.size24.copyWith(
            color: context.theme.colorScheme.primary, //
          ),
        ),
        const SizedBox(height: 50),
        _buildLoginForms().webConstrainedBox(),
      ],
    );
  }

  Widget _buildLoginForms() {
    return Form(
      key: _formKey,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 25),
        child: Column(
          children: [
            DoTextField(
              labelText: "Email",
              autofillHints: const [AutofillHints.username, AutofillHints.email],
              keyboardType: TextInputType.emailAddress,
              onChanged: (value) => vm.onEmailChanged(value),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Vui lòng nhập email!';
                }
                return null;
              },
            ),
            const SizedBox(height: 15),
            DoTextField(
              labelText: "Mật khẩu",
              autofillHints: const [AutofillHints.password],
              keyboardType: TextInputType.visiblePassword,
              obscureText: true,
              onChanged: (value) => vm.onPasswordChanged(value),
              validator: (value) {
                if (value == null || value.trim().length < 6) {
                  return 'Mật khẩu tối thiểu 6 ký tự!';
                }
                return null;
              },
            ),
            const SizedBox(height: 50),
            Selector<ChickenLoginViewModel, bool>(
              selector: (p0, p1) => p1.isBusy,
              builder: (context, isBusy, _) {
                return Column(
                  children: [
                    DoButton(
                      isBusy: isBusy,
                      onPressed: () {
                        if (!_formKey.currentState!.validate()) {
                          return;
                        }
                        vm.onLogin();
                      },
                      text: "Đăng nhập",
                    ),
                    TextButton(
                      onPressed: isBusy
                          ? null
                          : () {
                              if (!_formKey.currentState!.validate()) {
                                return;
                              }
                              vm.onSignUp();
                            },
                      child: const Text("Chưa có tài khoản? Đăng ký"),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
