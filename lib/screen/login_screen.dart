import 'package:auto_route/auto_route.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/extensions/text_style_extensions.dart';
import 'package:do_x/gen/assets.gen.dart';
import 'package:do_x/screen/core/app_scaffold.dart';
import 'package:do_x/screen/core/screen_state.dart';
import 'package:do_x/utils/app_info.dart';
import 'package:do_x/view_model/login_view_model.dart';
import 'package:do_x/widgets/button.dart';
import 'package:do_x/widgets/text_field.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

@RoutePage()
class LoginScreen extends StatefulScreen implements AutoRouteWrapper {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();

  @override
  Widget wrappedRoute(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LoginViewModel(), //
      child: this,
    );
  }
}

class _LoginScreenState<V extends LoginViewModel> extends ScreenState<LoginScreen, V> {
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      bottomNavigationBar: SafeArea(
        child: Container(
          height: 40,
          alignment: Alignment.center, //
          child: Text("© letrungdo. Ver ${appInfo.version}"),
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(15), //
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildLoginForms() {
    return Form(
      key: _formKey,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 25),
        child: Column(
          children: [
            Row(
              spacing: 10,
              children: [
                Expanded(
                  child: Selector<V, String>(
                    selector: (p0, p1) => p1.username,
                    builder: (context, username, _) {
                      return DoTextField(
                        value: username,
                        labelText: "Email",
                        autofillHints: [AutofillHints.username, AutofillHints.email],
                        keyboardType: TextInputType.emailAddress,
                        onChanged: (value) => vm.onUsernameChanged(value), //
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your email!';
                          }
                          return null;
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
            SizedBox(height: 15),
            Row(
              spacing: 10,
              children: [
                Expanded(
                  child: Selector<V, String>(
                    selector: (p0, p1) => p1.password,
                    builder: (context, password, _) {
                      return DoTextField(
                        labelText: "Password",
                        value: password,
                        autofillHints: [AutofillHints.password],
                        keyboardType: TextInputType.visiblePassword,
                        obscureText: true,
                        onChanged: (value) => vm.onPasswordChanged(value),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your password!';
                          }
                          return null;
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
            SizedBox(height: 50),
            Selector<V, bool>(
              selector: (p0, p1) => p1.isBusy,
              builder: (context, isBusy, _) {
                return DoButton(
                  isBusy: isBusy,
                  onPressed: () {
                    if (!_formKey.currentState!.validate()) {
                      return;
                    }
                    vm.onLogin();
                  },
                  text: context.l10n.login, //
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        SizedBox(height: 50), //
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Assets.images.appIcon.image(
              width: 60,
              height: 60,
              fit: BoxFit.contain, //
            ), //
            SizedBox(width: 10),
            Text(
              "Do X",
              style: context.textTheme.primary.size24.copyWith(
                color: context.theme.colorScheme.primary, //
              ), //
            ),
          ],
        ),
        SizedBox(height: 50), //

        _buildLoginForms(),
      ],
    );
  }
}
