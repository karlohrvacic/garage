import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/links/url_opener.dart';
import 'package:garage/core/router/app_redirect.dart';

/// An invite link only opens the app if three things agree: the host and path
/// in the link, the intent filter that claims them, and the assetlinks file
/// Android fetches from that host to check this app is allowed to. They live in
/// three different files and nothing else relates them, so a rename in one is
/// invisible until someone follows a link and lands in a browser.
void main() {
  final manifest = File(
    'android/app/src/main/AndroidManifest.xml',
  ).readAsStringSync();
  final assetlinks = File('web/.well-known/assetlinks.json').readAsStringSync();

  test('the link points at the host the intent filter claims', () {
    final link = GarageLinks.invite('ABC12345');

    expect(link.host, GarageLinks.host);
    expect(manifest, contains('android:host="${GarageLinks.host}"'));
  });

  test('and at a path under the prefix it claims', () {
    final link = GarageLinks.invite('ABC12345');

    expect(link.path, startsWith('$joinRoute/'));
    expect(manifest, contains('android:pathPrefix="$joinRoute"'));
  });

  test('the code is upper-cased into the link, as the backend expects', () {
    expect(GarageLinks.invite('abc12345').path, '$joinRoute/ABC12345');
  });

  test('the intent filter asks Android to verify it', () {
    // Without autoVerify the link opens a chooser, or the browser, which is
    // the behaviour this whole feature exists to avoid.
    expect(manifest, contains('android:autoVerify="true"'));
  });

  test('assetlinks.json is valid JSON naming this app', () {
    final parsed = jsonDecode(assetlinks) as List<dynamic>;
    final target =
        (parsed.single as Map<String, dynamic>)['target']
            as Map<String, dynamic>;

    expect(target['namespace'], 'android_app');
    expect(target['package_name'], 'cc.hrva.garage');
    expect(target['sha256_cert_fingerprints'], isA<List<dynamic>>());
  });

  // Android fetches this file and compares it byte for byte against the
  // installed app's signing certificate. A fingerprint that is the wrong
  // length, lower-case, or still the placeholder fails silently: links simply
  // open the browser, with nothing in the app to say why.
  test('every fingerprint is a real SHA-256, not a placeholder', () {
    final parsed = jsonDecode(assetlinks) as List<dynamic>;
    final target =
        (parsed.single as Map<String, dynamic>)['target']
            as Map<String, dynamic>;
    final fingerprints = (target['sha256_cert_fingerprints'] as List<dynamic>)
        .cast<String>();

    expect(fingerprints, isNotEmpty);
    for (final fingerprint in fingerprints) {
      expect(
        fingerprint,
        matches(RegExp(r'^([0-9A-F]{2}:){31}[0-9A-F]{2}$')),
        reason:
            'SHA-256 is 32 upper-case hex bytes separated by colons; this is '
            '"$fingerprint"',
      );
    }
  });

  test('and delegates the permission Android looks for', () {
    final parsed = jsonDecode(assetlinks) as List<dynamic>;
    final relation =
        (parsed.single as Map<String, dynamic>)['relation'] as List<dynamic>;

    expect(relation, contains('delegate_permission/common.handle_all_urls'));
  });
}
