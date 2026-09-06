import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every `More → Your data → Export as spreadsheets` in the public documents
/// names rows that exist, in the order you actually tap them.
///
/// These breadcrumbs are instructions given to somebody who cannot ask a
/// follow-up question: a reader of the privacy policy exercising a data right,
/// a Play reviewer checking the deletion route, someone following the API page
/// to find their key. When a row is renamed or moved, nothing fails — the
/// sentence still reads perfectly and simply sends people to a screen that is
/// not there. Five such paths had gone stale at once ("Settings → Export as
/// CSV" for a row called "Export as spreadsheets", three "Settings → API
/// access" for a screen two levels down), and one, "More → Waiting to sync",
/// described a screen that had no entry point on More at all.
///
/// Two things are checked, and both are cheap: every segment is a real English
/// label, and the path starts at a tab, because everything these documents
/// point at hangs off one. Neither can tell you the *order* is right — for
/// that, the screen tests are where a row proves it opens the next one.
///
/// `docs/play-store-listing.md` deliberately keeps its own arrows (`Play → App
/// content → Data safety`): those are the Play console's menus, not this app's.
void main() {
  final arb = jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync());
  final labels = {
    for (final entry in (arb as Map<String, dynamic>).entries)
      if (!entry.key.startsWith('@') && entry.value is String)
        entry.value as String,
  };

  /// The five bottom-bar destinations, read from the ARB rather than typed
  /// out, so renaming a tab moves the guard with it instead of past it.
  final tabs = {
    for (final key in const [
      'dashboardTitle',
      'timelineTitle',
      'vehiclesTitle',
      'plannerTitle',
      'settingsMore',
    ])
      arb[key] as String,
  };

  final files = [
    'PRIVACY.md',
    'web/privacy.html',
    'web/delete-account.html',
    'web/api.html',
    'docs/public-api.md',
    'lib/l10n/app_en.arb',
  ];

  // A run of arrow-separated words. The first and last segments run into the
  // prose around them, so those are matched by their inner edge.
  final chain = RegExp(r'[A-Za-z][A-Za-z ]*(?:\s*→\s*[A-Za-z][A-Za-z \-]*)+');

  for (final path in files) {
    test('$path names rows that exist', () {
      final text = File(
        path,
      ).readAsStringSync().replaceAll(RegExp(r'\s+'), ' ');
      for (final match in chain.allMatches(text)) {
        final segments = match
            .group(0)!
            .split('→')
            .map((segment) => segment.trim())
            .toList(growable: false);

        // The first and last segments run into the prose around them, so each
        // is read from its inner edge: `data as spreadsheets from More` starts
        // at More, and `Delete account immediately.` names Delete account.
        String? labelEnding(String segment) => labels.firstWhere(
          (label) => segment == label || segment.endsWith(' $label'),
          orElse: () => '',
        );
        String? labelStarting(String segment) => labels.firstWhere(
          (label) =>
              segment == label ||
              segment.startsWith('$label ') ||
              segment.startsWith('$label.') ||
              segment.startsWith('$label,'),
          orElse: () => '',
        );

        // An arrow is not always a menu. `Home → Work` is a suggested name for
        // a route somebody drives; `Rijeka → Zagreb` is a journey. What marks
        // a chain as a path through the app is that one end of it, or one of
        // its middle segments, is a row this app actually draws — including
        // when the row it names is the *wrong* one, which is the whole point.
        final looksLikeAPath =
            labelEnding(segments.first)!.isNotEmpty ||
            labelStarting(segments.last)!.isNotEmpty ||
            segments.skip(1).take(segments.length - 2).any(labels.contains);
        if (!looksLikeAPath) {
          continue;
        }

        // The first segment carries whatever prose preceded it, so it is the
        // *end* of it that must name a tab.
        final start = tabs.firstWhere(
          (tab) => segments.first == tab || segments.first.endsWith(' $tab'),
          orElse: () => '',
        );
        expect(
          start,
          isNotEmpty,
          reason:
              '"${match.group(0)}" in $path starts at "${segments.first}", '
              'which is not one of the tabs $tabs. Everything these documents '
              'point at is reached from a tab; a path that skips one tells a '
              'reader to look somewhere that has no such row.',
        );

        for (final segment in segments.skip(1)) {
          final known = labels.any(
            (label) =>
                segment == label ||
                // The last segment runs into the sentence after it.
                segment.startsWith('$label ') ||
                segment.startsWith('$label.'),
          );
          expect(
            known,
            isTrue,
            reason:
                '"$segment" in "${match.group(0)}" ($path) is not a label in '
                'app_en.arb. Either the row was renamed and this sentence was '
                'not, or it never existed.',
          );
        }
      }
    });
  }
}
