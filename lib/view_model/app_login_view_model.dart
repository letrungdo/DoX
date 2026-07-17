import 'package:auto_route/auto_route.dart';
import 'package:do_x/router/app_router.gr.dart';
import 'package:do_x/services/secure_storage_service.dart';
import 'package:do_x/services/supabase_service.dart';
import 'package:do_x/view_model/core/core_view_model.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppLoginViewModel extends CoreViewModel {
  static const _emailConfirmationUrl =
      'https://app.xn--t-lia.vn/auth/confirmed';
  static const _passwordRecoveryUrl =
      'https://app.xn--t-lia.vn/auth/reset-password';

  String _email = '';
  String get email => _email;

  String _password = '';
  String get password => _password;

  @override
  void initState() async {
    super.initState();
    final saved = await secureStorage.getSupabaseAccount();
    if (saved != null) {
      _email = saved.email;
      _password = saved.password;
      notifyListenersSafe();
    }
  }

  void onEmailChanged(String value) {
    _email = value;
  }

  void onPasswordChanged(String value) {
    _password = value;
  }

  Future<void> onLogin() async {
    setBusy(true);
    try {
      await supabase.auth.signInWithPassword(
        email: _email.trim(),
        password: _password,
      );
      _onAuthenticated();
    } on AuthException catch (e) {
      _showMessage(e.message);
    } catch (e) {
      _showMessage("Lỗi đăng nhập: $e");
    } finally {
      setBusy(false);
    }
  }

  Future<void> onSignUp() async {
    setBusy(true);
    try {
      final result = await supabase.auth.signUp(
        email: _email.trim(),
        password: _password,
        emailRedirectTo: _emailConfirmationUrl,
      );
      if (result.session != null) {
        _onAuthenticated();
      } else {
        _showMessage(
          "Đã đăng ký. Vui lòng kiểm tra email để xác nhận tài khoản.",
        );
      }
    } on AuthException catch (e) {
      _showMessage(e.message);
    } catch (e) {
      _showMessage("Lỗi đăng ký: $e");
    } finally {
      setBusy(false);
    }
  }

  Future<void> onForgotPassword() async {
    final email = _email.trim();
    if (email.isEmpty) {
      _showMessage('Vui lòng nhập email để đặt lại mật khẩu.');
      return;
    }

    setBusy(true);
    try {
      await supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: _passwordRecoveryUrl,
      );
      _showMessage('Đã gửi email đặt lại mật khẩu. Vui lòng kiểm tra hộp thư.');
    } on AuthException catch (e) {
      _showMessage(e.message);
    } catch (e) {
      _showMessage('Không thể gửi email đặt lại mật khẩu: $e');
    } finally {
      setBusy(false);
    }
  }

  void _onAuthenticated() {
    secureStorage.saveSupabaseAccount(
      email: _email.trim(),
      password: _password,
    );
    if (!context.mounted) return;
    if (context.router.canPop()) {
      context.router.pop();
    } else {
      context.router.replaceAll([const MainRoute()]);
    }
  }

  void _showMessage(String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
