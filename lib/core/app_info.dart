/// What the app calls itself, for the one screen that has to say it out loud.
///
/// Hand-kept rather than read from the platform: a plugin for two strings is a
/// plugin to maintain on three targets, and `test/core/app_info_test.dart`
/// fails the build if these drift from `pubspec.yaml`.
abstract final class AppInfo {
  /// The marketing version. A human decision — bump it when the release is
  /// worth a new number — and kept in step with `pubspec.yaml` by the test.
  static const String version = '1.3.0';

  /// The build number. CI passes the commit count, which only ever goes up and
  /// can never repeat a number Play has already seen; a local build falls back
  /// to whatever `pubspec.yaml` says.
  static const String build = String.fromEnvironment(
    'BUILD_NUMBER',
    defaultValue: _pubspecBuild,
  );

  static const String _pubspecBuild = '5';
}
