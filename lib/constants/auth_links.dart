/// Everywhere an authentication email can send the user back to.
///
/// The links live here rather than next to the code that builds them because
/// three places have to agree on them: the app (what it passes to Supabase as
/// `emailRedirectTo`), the website that hosts the landing pages, and the
/// platform manifests that claim the host as an App Link / Universal Link.
class AuthLinks {
  AuthLinks._();

  /// Site hosting the auth landing pages.
  ///
  /// On Android the app also claims this host as an App Link, so the link in
  /// the email opens the app without the browser appearing at all. iOS does
  /// *not*: Universal Links need the Associated Domains entitlement, which
  /// needs a paid Apple Developer Program membership. To turn it back on once
  /// the team has one, add the Associated Domains capability to the Runner
  /// target in Xcode with `applinks:app.xn--t-lia.vn` — the matching
  /// `apple-app-site-association` is already published on the site.
  ///
  /// Nothing depends on that: with or without it the landing page hands the
  /// session to [appScheme], so iOS just sees a browser flash on the way.
  static const webBase = 'https://app.xn--t-lia.vn';

  /// Where Supabase sends a user who clicked "confirm my email".
  static const emailConfirmation = '$webBase/auth/confirmed';

  /// Where Supabase sends a user who clicked "reset my password".
  static const passwordRecovery = '$webBase/auth/reset-password';

  /// Private scheme the landing pages hand the session back over when the
  /// browser — not the app — opened them. A redirect out of Supabase's
  /// `/auth/v1/verify` does not reliably trigger a Universal Link, so the web
  /// page is always reached first and bounces to this.
  ///
  /// Must match the `<data android:scheme>` in `AndroidManifest.xml` and
  /// `CFBundleURLSchemes` in `Info.plist`.
  static const appScheme = 'vn.dox.app';
}
