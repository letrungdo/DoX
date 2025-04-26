import 'package:do_ai/screen/core/app_scaffold.dart';
import 'package:do_ai/screen/core/screen_state.dart';
import 'package:do_ai/view_model/login_view_model.dart';
import 'package:do_ai/widgets/app_bar/app_bar_base.dart';
import 'package:do_ai/widgets/text_field.dart';
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
  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: DoAppBar(title: "Login"), //
      child: Padding(
        padding: const EdgeInsets.all(15), //
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        Row(
          spacing: 10,
          children: [
            Text("Username"),
            Expanded(
              child: Selector<V, String>(
                selector: (p0, p1) => p1.username,
                builder: (context, username, _) {
                  return DoTextField(
                    initialValue: username,
                    onChanged: (value) => vm.onUsernameChanged(value), //
                  );
                },
              ),
            ),
          ],
        ),
        Row(
          spacing: 10,
          children: [
            Text("Password"),
            Expanded(
              child: Selector<V, String>(
                selector: (p0, p1) => p1.password,
                builder: (context, password, _) {
                  return DoTextField(
                    initialValue: password,
                    onChanged: (value) => vm.onPasswordChanged(value), //
                  );
                },
              ),
            ),
          ],
        ),
        SizedBox(height: 50),
        ElevatedButton(
          onPressed: () => vm.onLogin(),
          child: Text("Login"), //
        ),
      ],
    );
  }
}
