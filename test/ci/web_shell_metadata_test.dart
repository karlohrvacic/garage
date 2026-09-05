import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `web/index.html` and `web/manifest.json` shipped Flutter's scaffold text to
/// production for the app's whole life: the meta description read "A new
/// Flutter project." and the title was a lowercase "garage".
///
/// Nothing in the build complains, the app works perfectly, and the only place
/// it shows is a search result, a browser tab, and the card somebody sees when
/// the link is shared. `flutter create` regenerates both files, so this is the
/// kind of thing that comes back.
void main() {
  final index = File('web/index.html').readAsStringSync();
  final manifest =
      jsonDecode(File('web/manifest.json').readAsStringSync())
          as Map<String, dynamic>;

  test('no scaffold text survives in the web shell', () {
    for (final placeholder in [
      'A new Flutter project',
      '<title>garage</title>',
    ]) {
      expect(
        index,
        isNot(contains(placeholder)),
        reason: '"$placeholder" is what `flutter create` writes',
      );
      expect(jsonEncode(manifest), isNot(contains(placeholder)));
    }
  });

  test('the page says what the app is', () {
    expect(index, contains('<meta name="description"'));
    expect(index, contains('<title>Garage'));
    expect(manifest['description'], isNot('A new Flutter project.'));
    expect(manifest['name'], startsWith('Garage'));
  });

  test('a phone gets the viewport it is entitled to', () {
    // Without this the engine inserts one at runtime, which is a frame of
    // desktop-width layout on the phone this app is mostly used on.
    expect(index, contains('name="viewport"'));
    expect(index, contains('width=device-width'));
  });

  test('the browser chrome matches the theme, in both directions', () {
    // Dark-first app behind light browser chrome is the flash the theme
    // tokens exist to prevent.
    expect(index, contains('prefers-color-scheme: light'));
    expect(index, contains('prefers-color-scheme: dark'));
    expect(index, contains('#0F1114'), reason: 'GarageTokens.dark.bg');
    expect(index, contains('#F4F4F2'), reason: 'GarageTokens.light.bg');
  });

  test('a shared link previews as something', () {
    expect(index, contains('property="og:title"'));
    expect(index, contains('property="og:image"'));
    expect(index, contains('name="twitter:card"'));
  });

  test('the preview image it points at is actually served', () {
    // An og:image 404 is worse than none: the card renders broken rather than
    // falling back to text.
    final match = RegExp(
      r'property="og:image" content="https://garage\.hrva\.cc/([^"]+)"',
    ).firstMatch(index);
    expect(match, isNotNull, reason: 'og:image must be an absolute URL');

    expect(
      File('web/${match!.group(1)}').existsSync(),
      isTrue,
      reason: 'og:image points at a file that web/ does not contain',
    );
  });

  test('the manifest does not lock an orientation the app adapts to', () {
    // The layout switches to a rail at 900px and a sidebar at 1200
    // (GarageBreakpoints). A manifest that pins portrait means an installed
    // PWA can never reach either.
    expect(manifest['orientation'], isNot('portrait-primary'));
  });
}
