/// What the app calls itself, for the one screen that has to say it out loud.
///
/// Hand-kept rather than read from the platform: a plugin for two strings is a
/// plugin to maintain on three targets, and `test/core/app_info_test.dart`
/// fails the build if these drift from `pubspec.yaml`.
abstract final class AppInfo {
  static const String version = '1.3.0';
  static const String build = '5';
}
