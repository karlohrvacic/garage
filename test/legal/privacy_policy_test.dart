import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The policy exists twice: PRIVACY.md is the source, web/privacy.html is what
/// Play and the app link to. A policy that says less than the app does is a
/// compliance problem, so these check the two cannot drift apart unnoticed.
String get _markdown => File('PRIVACY.md').readAsStringSync();

String get _page => File('web/privacy.html').readAsStringSync();

/// Text of the page with tags and entities stripped, for substring checks.
String get _pageText => _page
    .replaceAll(RegExp(r'<[^>]+>'), ' ')
    .replaceAll('&amp;', '&')
    .replaceAll(RegExp(r'\s+'), ' ');

void main() {
  test('every section of the policy is on the hosted page', () {
    final headings = RegExp(
      r'^#{2,3} (.+)$',
      multiLine: true,
    ).allMatches(_markdown).map((match) => match.group(1)!);

    for (final heading in headings) {
      // The page renders emphasis as tags, which the text stripping removes.
      final plain = heading.replaceAll('**', '');
      expect(
        _pageText,
        contains(plain),
        reason: '"$plain" is in PRIVACY.md but not on the hosted page',
      );
    }
  });

  test('both carry the same last-updated date', () {
    final inMarkdown = RegExp(
      r'_Last updated: (\d{4}-\d{2}-\d{2})_',
    ).firstMatch(_markdown)?.group(1);
    final onPage = RegExp(
      r'Last updated: (\d{4}-\d{2}-\d{2})',
    ).firstMatch(_pageText)?.group(1);

    expect(inMarkdown, isNotNull);
    expect(onPage, inMarkdown);
  });

  test('the contact address is reachable from the page', () {
    expect(_page, contains('mailto:garage@hrva.cc'));
  });

  group('what the app actually does is disclosed', () {
    // Each of these is a data flow the code performs. If one is added or
    // removed, the policy has to move with it.
    const disclosures = {
      'attachments in storage': 'Attachments',
      'the VIN lookup leaving the EU': 'NHTSA',
      'the fuel-price dataset': 'mzoe-gor.hr',
      'webhooks the user registers': 'webhook',
      'location staying on the device': 'Location',
      'account deletion': 'Delete account',
      'CSV export': 'Export as CSV',
    };

    for (final entry in disclosures.entries) {
      test(entry.key, () {
        expect(_markdown, contains(entry.value));
        expect(_pageText, contains(entry.value));
      });
    }
  });
}
