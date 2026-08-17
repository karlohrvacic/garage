import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/links/url_opener.dart';

/// The licence is a promise to everyone who receives the code, and the AGPL
/// makes a second promise to everyone who merely *uses* the hosted app. Both
/// are easy to break by accident — a LICENSE nobody names in the README, a
/// source link quietly dropped from a screen — and neither breaks loudly.
String get _licence => File('LICENSE').readAsStringSync();

String get _readme => File('README.md').readAsStringSync();

String get _pubspec => File('pubspec.yaml').readAsStringSync();

void main() {
  test('the licence is the AGPL, verbatim and unedited', () {
    expect(_licence, contains('GNU AFFERO GENERAL PUBLIC LICENSE'));
    expect(_licence, contains('Version 3, 19 November 2007'));

    // The FSF's own copyright on the licence text. Its absence means someone
    // retyped or trimmed the licence, which makes it a different document
    // than the one every "AGPL-3.0" reference in this repo points at.
    expect(
      _licence,
      contains('Copyright (C) 2007 Free Software Foundation, Inc.'),
      reason: 'LICENSE must be the canonical text, not a paraphrase of it',
    );
  });

  test('the README says which licence, and who holds the copyright', () {
    expect(_readme, contains('AGPL-3.0'));
    expect(
      _readme,
      contains('Karlo Hrvačić'),
      reason: 'a copyright holder who is named nowhere cannot enforce anything',
    );
  });

  test(
    'the package points at the repository the licence obliges it to offer',
    () {
      expect(
        _pubspec,
        contains('repository: https://github.com/karlohrvacic/garage'),
      );
    },
  );

  test('contributing terms exist and keep relicensing possible', () {
    expect(
      File('CONTRIBUTING.md').existsSync(),
      isTrue,
      reason:
          'an open repo with no contributing terms decides them by accident',
    );

    final cla = File('CLA.md');
    expect(cla.existsSync(), isTrue);
    // The whole point of the CLA is this grant. A version that only licenses
    // the work *under the AGPL* would close the door it exists to hold open.
    expect(
      cla.readAsStringSync(),
      contains('relicense'),
      reason: 'without a relicensing grant the CLA buys nothing over the AGPL',
    );
  });

  test(
    'the source offer required by AGPL section 13 has somewhere to point',
    () {
      expect(
        GarageLinks.sourceCode.toString(),
        'https://github.com/karlohrvacic/garage',
      );
    },
  );
}
