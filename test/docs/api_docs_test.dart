import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The API reference exists twice: docs/public-api.md is the source, and
/// web/api.html is what somebody holding a key can actually reach. A hosted
/// page that describes fewer endpoints than the API has is worse than no page
/// — it is believed. These stop the two drifting apart unnoticed, the same way
/// the privacy policy is pinned to its hosted copy.
String get _markdown => File('docs/public-api.md').readAsStringSync();

String get _page => File('web/api.html').readAsStringSync();

String get _pageText => _page
    .replaceAll(RegExp(r'<[^>]+>'), ' ')
    .replaceAll('&amp;', '&')
    .replaceAll(RegExp(r'\s+'), ' ');

void main() {
  test('every endpoint the docs list is on the hosted page', () {
    final paths = RegExp(
      r'^\| `(/[a-z]*)` \|',
      multiLine: true,
    ).allMatches(_markdown).map((match) => match.group(1)!).toList();

    expect(
      paths,
      isNotEmpty,
      reason: 'the endpoint table in docs/public-api.md changed shape',
    );
    for (final path in paths) {
      expect(
        _pageText,
        contains(path),
        reason: '"$path" is documented but not on the hosted page',
      );
    }
  });

  /// Sections that belong to whoever maintains the app, not to whoever holds a
  /// key. Deploy commands on a public page would be noise at best.
  const maintainerOnly = {'Deploying it'};

  test('every reader-facing section is on the hosted page', () {
    final headings = RegExp(
      r'^#{2} (.+)$',
      multiLine: true,
    ).allMatches(_markdown).map((match) => match.group(1)!);

    for (final heading in headings) {
      if (maintainerOnly.contains(heading)) {
        continue;
      }
      expect(
        _pageText,
        contains(heading.replaceAll('**', '')),
        reason: '"$heading" is in docs/public-api.md but not on the page',
      );
    }
  });

  // The one thing a reader cannot guess and cannot recover: keys are shown
  // once. A page that omits it costs somebody their key.
  test('the page says a key is shown only once', () {
    expect(_pageText.toLowerCase(), contains('not shown again'));
  });

  test('the page carries the fields a fill-up actually returns', () {
    for (final field in [
      'fuel_type_key',
      'cheapest_nearby_price',
      'cheapest_nearby_km',
      'cheapest_nearby_station',
      'prices_seen_on',
    ]) {
      expect(
        _pageText,
        contains(field),
        reason: '$field is returned by /fuel but the page does not mention it',
      );
    }
  });

  test('the page carries the drivetrain fields a vehicle returns', () {
    for (final field in ['timing_drive', 'transmission']) {
      expect(
        _pageText,
        contains(field),
        reason:
            '$field is returned by /vehicles but the page does not mention it',
      );
    }
  });

  test('the page does not promise a write API', () {
    expect(_pageText.toLowerCase(), contains('read-only'));
  });

  test('the page keeps deploy instructions off it', () {
    expect(_pageText, isNot(contains('supabase functions deploy')));
  });
}
