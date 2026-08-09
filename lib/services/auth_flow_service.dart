import 'dart:async';

import 'package:do_x/router/app_router.dart';
import 'package:do_x/router/app_router.gr.dart';
import 'package:do_x/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Owns every navigation that a Supabase session change should trigger.
///
/// Sessions do not only arrive from the login form: tapping the link in a
/// confirmation or password-reset email hands one to the app through a deep
/// link, which `supabase_flutter` swallows silently. Keeping the reaction here
/// rather than in the login view model means the app behaves the same whether
/// the user signed in on the form or came back from their inbox.
class _AuthFlowService {
  StreamSubscription<AuthState>? _subscription;

  /// Safe to call more than once; only the first call subscribes.
  void start() {
    _subscription ??= supabase.auth.onAuthStateChange.listen(_onAuthState);
  }

  void _onAuthState(AuthState state) {
    switch (state.event) {
      // The recovery link gave us a session that may do nothing but authorise
      // one password change — take the user straight to the form.
      case AuthChangeEvent.passwordRecovery:
        if (_currentRouteName != UpdatePasswordRoute.name) {
          appRouter.push(UpdatePasswordRoute(isRecovery: true));
        }
      // Reached the app with a session while the login form is still up: from
      // the form itself, or from a confirmation email opened in the browser.
      case AuthChangeEvent.signedIn:
        unwindAuthScreens();
      default:
        break;
    }
  }

  /// Pages that exist only to obtain a session, and so have no reason to
  /// outlive one. They stack — the login form pushes the code screen — which is
  /// why this unwinds rather than popping once.
  static final _authRouteNames = {AppLoginRoute.name, VerifyOtpRoute.name};

  /// Clears the auth pages off the top of the stack, whatever produced the
  /// session: the login form, a code typed in, or a link out of an email.
  ///
  /// Also called by the update-password page once it is done, since a recovery
  /// leaves those pages sitting underneath it.
  Future<void> unwindAuthScreens() async {
    while (_authRouteNames.contains(_currentRouteName)) {
      // The auth guard redirects with `redirectUntil`, so popping is what lets
      // the guarded page resolve. With nothing underneath — the app launched
      // straight into the login screen — start the app instead.
      if (!appRouter.canPop()) {
        appRouter.replaceAll([const MainRoute()]);
        return;
      }
      // Bails out rather than spinning if the route refuses to go.
      if (!await appRouter.maybePop()) return;
    }
  }

  String? get _currentRouteName => appRouter.currentSegments.lastOrNull?.name;
}

final authFlowService = _AuthFlowService();
