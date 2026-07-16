import 'package:auto_route/auto_route.dart';
import 'package:do_x/router/app_router.gr.dart';
import 'package:do_x/services/supabase_service.dart';
import 'package:do_x/view_model/core/core_view_model.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChickenLoginViewModel extends CoreViewModel {
  String _email = '';
  String get email => _email;

  String _password = '';
  String get password => _password;

  void onEmailChanged(String value) {
    _email = value;
  }

  void onPasswordChanged(String value) {
    _password = value;
  }

  Future<void> onLogin() async {
    setBusy(true);
    try {
      await supabase.auth.signInWithPassword(email: _email.trim(), password: _password);
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
      final result = await supabase.auth.signUp(email: _email.trim(), password: _password);
      if (result.session != null) {
        _onAuthenticated();
      } else {
        _showMessage("Đã đăng ký. Vui lòng kiểm tra email để xác nhận tài khoản.");
      }
    } on AuthException catch (e) {
      _showMessage(e.message);
    } catch (e) {
      _showMessage("Lỗi đăng ký: $e");
    } finally {
      setBusy(false);
    }
  }

  void _onAuthenticated() {
    if (!context.mounted) return;
    if (context.router.canPop()) {
      context.router.pop();
    } else {
      context.router.replaceAll([const MainRoute()]);
    }
  }

  void _showMessage(String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
