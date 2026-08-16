/// Firebase Cloud Messaging configuration, supplied by dart-defines like every
/// other environment value here.
///
/// Deliberately *not* `google-services.json` plus the Gradle plugin, which is
/// the usual FlutterFire setup. That file is not in the repository, and the
/// plugin fails the build when it is missing, so applying it would break CI's
/// `flutter build apk` and anyone cloning the project. Passing the same four
/// values as dart-defines and calling `Firebase.initializeApp(options:)`
/// achieves the same thing and leaves an unconfigured build working, with push
/// simply inactive.
///
/// None of these are secrets: they identify the Firebase project to the device
/// and ship inside every copy of the app. The credential that can actually send
/// a push is the service account, which lives only in the Edge Function's
/// `FCM_SERVICE_ACCOUNT` secret.
abstract final class PushConfig {
  static const String apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const String appId = String.fromEnvironment('FIREBASE_APP_ID');
  static const String messagingSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
  );
  static const String projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');

  /// Web push additionally needs the VAPID key from Firebase → Cloud Messaging
  /// → Web configuration. Absent it, mobile push still works.
  static const String vapidKey = String.fromEnvironment('FIREBASE_VAPID_KEY');

  static bool get isConfigured =>
      apiKey.isNotEmpty &&
      appId.isNotEmpty &&
      messagingSenderId.isNotEmpty &&
      projectId.isNotEmpty;
}
