import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Checks on the deploy configuration itself. None of this is exercised by the
/// app's tests, and every item here has a failure mode that only shows up in a
/// release: a bundle Play rejects, or an Android build configured differently
/// from the web one against the same database.
String get _play =>
    File('.github/workflows/deploy-play.yml').readAsStringSync();

String get _web => File('.github/workflows/deploy-web.yml').readAsStringSync();

void main() {
  test('web and Android are built against the same configuration', () {
    final defines = RegExp(r'--dart-define=(\w+)=');
    final webKeys = defines.allMatches(_web).map((m) => m.group(1)!).toSet();
    final playKeys = defines.allMatches(_play).map((m) => m.group(1)!).toSet();

    expect(
      playKeys,
      webKeys,
      reason:
          'a define on one platform and not the other means the two talk to '
          'different backends, or one loses Google sign-in',
    );
  });

  test('the bundle is uploaded under the id the app is built with', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    final applicationId = RegExp(
      r'applicationId\s*=\s*"([^"]+)"',
    ).firstMatch(gradle)!.group(1);

    expect(_play, contains('packageName: $applicationId'));
  });

  test('signing is required, not silently skipped', () {
    // build.gradle.kts falls back to debug signing when key.properties is
    // absent. In CI that would produce a bundle Play refuses, after a full
    // build — so the workflow has to fail before building instead.
    expect(
      _play,
      contains('ANDROID_KEYSTORE_BASE64'),
      reason: 'the release must be signed with the upload key',
    );
    expect(_play.contains('exit 1'), isTrue);
  });

  group('release notes', () {
    final directory = Directory('distribution/whatsnew');

    test('exist for every language the listing is published in', () {
      final names = directory
          .listSync()
          .map((entry) => entry.uri.pathSegments.last)
          .toSet();

      expect(names, containsAll(['whatsnew-en-GB', 'whatsnew-hr']));
    });

    test('are within the 500 characters Play accepts', () {
      for (final file in directory.listSync().whereType<File>()) {
        expect(
          file.readAsStringSync().trim().length,
          lessThanOrEqualTo(500),
          reason: '${file.path} would be rejected at upload',
        );
      }
    });
  });
}
