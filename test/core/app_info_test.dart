import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/app_info.dart';

/// The `version:` line of pubspec, split into its two halves.
({String name, String build}) get pubspecVersion {
  final line = File(
    'pubspec.yaml',
  ).readAsLinesSync().firstWhere((l) => l.startsWith('version:'));
  final value = line.split(':')[1].trim();
  return (name: value.split('+').first, build: value.split('+').last);
}

void main() {
  // Both halves of the version now follow the same rule: CI decides, and a
  // local build falls back to pubspec. The tag supplies the marketing version
  // and the commit count supplies the build number, so neither is typed into a
  // file that can then disagree with the release it describes. That
  // disagreement failed a release once, which is why it stopped being possible.
  test('the marketing version is the tag when CI gives one', () {
    const fromCi = String.fromEnvironment('APP_VERSION');

    expect(AppInfo.version, fromCi.isEmpty ? pubspecVersion.name : fromCi);
  });

  test('the build number is the commit count when CI gives one', () {
    const fromCi = String.fromEnvironment('BUILD_NUMBER');

    expect(AppInfo.build, fromCi.isEmpty ? pubspecVersion.build : fromCi);
  });

  test('a local build still names a version rather than nothing', () {
    expect(AppInfo.version, isNotEmpty);
    expect(AppInfo.build, isNotEmpty);
  });
}
