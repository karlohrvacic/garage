import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The only page a visitor sees before deciding whether to sign up.
///
/// garage.hrva.cc redirects an unauthenticated visitor straight to a sign-in
/// form, so without this page the whole public face of the app is a password
/// box. It is a static file rather than a screen for the same reason: someone
/// evaluating the app should not have to load a Flutter bundle to find out
/// what it is, and a search engine should not have to run one to index it.
String get _page => File('web/features.html').readAsStringSync();

String get _text =>
    _page.replaceAll(RegExp(r'<[^>]+>'), ' ').replaceAll(RegExp(r'\s+'), ' ');

void main() {
  test('the showcase exists and says what the app is', () {
    expect(_text, contains('Garage'));
    expect(_page, contains('<title>'));
    expect(
      _page,
      contains('meta name="description"'),
      reason: 'this is the page a search result and a shared link both quote',
    );
  });

  test('it names the things that make the app different', () {
    // Not a feature list for its own sake: these are the four claims the app
    // is built around, and a showcase that omits one is selling something
    // else. They are also the ones a competitor comparison turns on.
    for (final claim in [
      'full-tank economy',
      'one shop visit',
      'once the fuel to get there is paid for',
      'transfer code',
    ]) {
      expect(_text, contains(claim), reason: 'the showcase drops "$claim"');
    }
  });

  test('it keeps the promises the About screen makes', () {
    // The same four the app states in its own words. A landing page that
    // undersells them is the one place a reader decides whether to trust the
    // rest, and a landing page that *over*sells them is worse.
    expect(_text, contains('No ads, no subscription'));
    expect(_text, contains('No tracking, no analytics'));
    expect(_text, contains('export everything'));
  });

  test('it leads somewhere, and discloses the licence', () {
    expect(_page, contains('href="/"'), reason: 'no way into the app');
    expect(_page, contains('href="/privacy"'));
    expect(
      _page,
      contains('AGPL-3.0'),
      reason: 'the public page is where an open-source claim gets checked',
    );
  });

  test('it renders in a dark theme too', () {
    // Served to whoever follows a link, on whatever they are holding. The
    // other static pages already do this and a white flash is a poor first
    // impression of an app whose own identity is dark.
    expect(_page, contains('prefers-color-scheme: dark'));
  });
}
