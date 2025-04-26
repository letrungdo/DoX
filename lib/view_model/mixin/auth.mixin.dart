import 'dart:async';

import 'package:do_ai/screen/login_screen.dart';
import 'package:do_ai/screen/main_screen.dart';
import 'package:do_ai/view_model/core/core_view_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

mixin AuthMixin on CoreViewModel {
  late StreamSubscription<User?> _subscriptionAuthChanges;

  @override
  Future<void> initState() async {
    super.initState();
    _subscriptionAuthChanges = FirebaseAuth.instance.authStateChanges().listen(_handleAuth);
  }

  void _handleAuth(User? user) {
    if (!context.mounted) return;
    if (user == null) {
      context.replace(LoginScreen.path);
    } else {
      context.replace(MainScreen.path);
    }
  }

  @override
  void dispose() {
    _subscriptionAuthChanges.cancel();
    super.dispose();
  }
}
