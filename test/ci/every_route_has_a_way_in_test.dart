import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every screen the router can build has something in the app that opens it.
///
/// `/vehicles/:id/lending` — lending a car to somebody for a weekend — shipped
/// with a screen, a table, its own row-level-security policies, a test suite
/// and a line in the release notes, and no button anywhere. Its route existed,
/// so nothing failed; the borrower's half was on More, and the owner's half,
/// the half you need first, could only be reached by typing the URL. The
/// person it was built for went looking for it and could not find it.
///
/// The same shape had already happened twice — `/routes` reached only from an
/// unlabelled toolbar icon, `/pending` only from a banner that appears when
/// something has gone wrong — which is why this is a test and not a habit.
///
/// It proves reachability from *code*, not from a screen a person can actually
/// get to: a caller inside an unreachable screen would satisfy it. That is the
/// floor, and `more_screen_test.dart` is where the labelled entry points are
/// checked.
void main() {
  test('no route is reachable only by typing its URL', () {
    final router = File('lib/core/router/app_router.dart').readAsStringSync();
    final routes = RegExp(
      r"path:\s*'([^']+)'",
    ).allMatches(router).map((m) => m.group(1)!).toSet();

    /// A path with its variable parts flattened, so the `/vehicles/:id/edit`
    /// the router declares and the `'/vehicles/$vehicleId/edit'` a screen
    /// pushes compare equal.
    String shape(String path) => path
        .split('?')
        .first
        .split('/')
        .map(
          (segment) =>
              segment.startsWith(':') ||
                  segment.startsWith(r'$') ||
                  segment.contains(r'${')
              ? ':x'
              : segment,
        )
        .join('/');

    final pushed = <String>{};
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      if (file.path.endsWith('app_router.dart')) continue;
      for (final match in RegExp(
        r"'(/[^']*)'",
      ).allMatches(file.readAsStringSync())) {
        pushed.add(shape(match.group(1)!));
      }
    }

    // The invite deep link is built from a constant rather than written out,
    // and `invite_links_test.dart` is the guard that the two agree.
    const builtFromAConstant = {r'$joinRoute/:code'};

    final unreachable = routes
        .where((route) => !builtFromAConstant.contains(route))
        .where((route) => !pushed.contains(shape(route)))
        .toList(growable: false);

    expect(
      unreachable,
      isEmpty,
      reason:
          'These routes exist and nothing in lib/ opens them, so the feature '
          'is finished and invisible: $unreachable. Give each one a button, or '
          'delete the route.',
    );
  });
}
