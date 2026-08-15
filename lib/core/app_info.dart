/// What the app calls itself, for the one screen that has to say it out loud.
///
/// Hand-kept rather than read from the platform: a plugin for two strings is a
/// plugin to maintain on three targets, and `test/core/app_info_test.dart`
/// fails the build if these drift from `pubspec.yaml`.
abstract final class AppInfo {
  /// The marketing version, taken from the release tag.
  ///
  /// `git tag v1.3.1` is the whole act of versioning: the workflow passes the
  /// tag here and to `--build-name`, so what a release calls itself and what
  /// the tag says cannot disagree. They did once, and the release stopped at
  /// the guard that noticed.
  ///
  /// The fallback is only for a local build, which has no tag to read.
  static const String version = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: _pubspecVersion,
  );

  static const String _pubspecVersion = '1.3.1';

  /// The build number. CI passes the commit count, which only ever goes up and
  /// can never repeat a number Play has already seen; a local build falls back
  /// to whatever `pubspec.yaml` says.
  static const String build = String.fromEnvironment(
    'BUILD_NUMBER',
    defaultValue: _pubspecBuild,
  );

  static const String _pubspecBuild = '5';
}
