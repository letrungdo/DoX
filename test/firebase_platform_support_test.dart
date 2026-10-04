import 'package:do_x/firebase_options.dart';
import 'package:do_x/main.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('Windows startup skips unconfigured Firebase services', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    // Asking for these options used to abort initialization before the UI.
    expect(
      () => DefaultFirebaseOptions.currentPlatform,
      throwsUnsupportedError,
    );
    expect(supportsFirebaseServices, isFalse);
  });

  test('existing native Firebase platforms retain their configuration', () {
    for (final platform in [
      TargetPlatform.android,
      TargetPlatform.iOS,
      TargetPlatform.macOS,
    ]) {
      debugDefaultTargetPlatformOverride = platform;
      expect(supportsFirebaseServices, isTrue, reason: platform.name);
      expect(DefaultFirebaseOptions.currentPlatform.projectId, 'do-appx');
    }
  });
}
