import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/app_info.dart';

void main() {
  test('the version the app shows is the version it was built as', () {
    final pubspec = File('pubspec.yaml').readAsLinesSync();
    final line = pubspec.firstWhere((l) => l.startsWith('version:'));
    final declared = line.split(':')[1].trim().split('+').first;

    expect(
      AppInfo.version,
      declared,
      reason: 'bump lib/core/app_info.dart together with pubspec.yaml',
    );
  });

  test('the build number is CI\'s when given, and pubspec\'s otherwise', () {
    final pubspec = File('pubspec.yaml').readAsLinesSync();
    final line = pubspec.firstWhere((l) => l.startsWith('version:'));
    final declared = line.split(':')[1].trim().split('+').last;
    const fromCi = String.fromEnvironment('BUILD_NUMBER');

    // Holds either way, so running the suite with or without the define is
    // still a real check rather than a broken one.
    expect(AppInfo.build, fromCi.isEmpty ? declared : fromCi);
  });
}
