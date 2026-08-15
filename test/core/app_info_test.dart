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

  test('the build number is the one in pubspec too', () {
    final pubspec = File('pubspec.yaml').readAsLinesSync();
    final line = pubspec.firstWhere((l) => l.startsWith('version:'));
    final declared = line.split(':')[1].trim().split('+').last;

    expect(AppInfo.build, declared);
  });
}
