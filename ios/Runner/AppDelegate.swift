import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    // Claim the notification centre before the plugins register.
    //
    // Firebase Messaging otherwise finds the delegate slot empty and takes it,
    // and it forwards a tap only to the delegate it displaced — which was
    // nobody. flutter_local_notifications never claims the slot itself, so a
    // tap on the vaccination or electricity reminder reached no one and the
    // app stayed where it was.
    //
    // With the app delegate holding it, Firebase leaves the slot alone (it
    // recognises a FlutterAppLifeCycleProvider) and both plugins are called
    // through the usual plugin forwarding — FlutterAppDelegate already
    // conforms and hands each callback to every plugin that wants it.
    UNUserNotificationCenter.current().delegate = self
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  /// Shows a notification that arrives while the app is open.
  ///
  /// Both notification plugins answer this question and the first answer wins,
  /// an order this app does not control — Firebase Messaging answers for a
  /// notification that is not even its own. So the plugins are still called,
  /// for their side effects (`onMessage`), but with their answer thrown away:
  /// everything this app posts is worth showing.
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    super.userNotificationCenter(center, willPresent: notification) { _ in }
    completionHandler([.banner, .list, .sound, .badge])
  }
}
