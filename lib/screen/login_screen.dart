import 'package:do_x/screen/core/app_scaffold.dart';
import 'package:do_x/screen/core/screen_state.dart';
import 'package:do_x/view_model/login_view_model.dart';
import 'package:do_x/widgets/text_field.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class LoginScreen extends StatefulScreen implements ProviderWrapper {
  const LoginScreen({super.key});

  static const path = "/login";

  @override
  State<LoginScreen> createState() => _LoginScreenState();

  @override
  Widget providerWrapper() {
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
      child: SafeArea(
        child: Padding(
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
                        labelText: "Username",
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
            ElevatedButton(
              onPressed: () {
                if (!_formKey.currentState!.validate()) {
                  return;
                }
                vm.onLogin();
              },
              child: Text("Login"), //
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        SizedBox(height: 100), //
        _buildLoginForms(),
      ],
    );
  }
}
