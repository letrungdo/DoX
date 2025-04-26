import 'dart:async';

import 'package:do_ai/utils/logger.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  Future<UserCredential?> login({
    required String email, //
    required String password,
  }) async {
    try {
      final result = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email, //
        password: password,
      );
      return result;
    } on FirebaseAuthException catch (e) {
      logger.e(e.message ?? "", error: e);
    }
    return null;
  }

  Future<void> logout() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      logger.e(e.toString());
    }
  }
}
