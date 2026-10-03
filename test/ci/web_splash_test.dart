import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/theme/garage_tokens.dart';

/// The seconds between a tap on a link and Flutter's first frame were a blank
/// page. The splash is plain HTML the browser draws before any script runs,
/// and the bootstrap takes it away on the engine's first frame.
String _hex(Color color) =>
    '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

void main() {
  final index = File('web/index.html').readAsStringSync();
  final bootstrap = File('web/flutter_bootstrap.js').readAsStringSync();

  test('the splash is in the page before the script that loads the app', () {
    final splash = index.indexOf('id="splash"');
    expect(splash, isNonNegative);
    expect(splash, lessThan(index.indexOf('src="flutter_bootstrap.js"')));
    expect(index, contains('id="splash-progress"'));
  });

  // The app's own ground and amber, so the splash and the first frame are the
  // same page rather than a flash of a different one. Read from the splash's
  // <style> alone: the theme-color metas carry both grounds and the dark
  // media query too, and would pass for a splash with no colours at all.
  test('it wears the tokens in both themes', () {
    final style = RegExp(r'<style>([\s\S]*?)</style>').firstMatch(index);
    expect(style, isNotNull, reason: 'the splash has no <style> block');
    final css = style!.group(1)!;
    for (final color in [
      GarageTokens.light.bg,
      GarageTokens.dark.bg,
      GarageTokens.light.accent,
      GarageTokens.dark.accent,
    ]) {
      expect(css.toUpperCase(), contains(_hex(color)));
    }
    expect(css, contains('prefers-color-scheme: dark'));
  });

  test('the bootstrap is Flutter\'s, with the splash wired in', () {
    expect(bootstrap, contains('{{flutter_js}}'));
    expect(bootstrap, contains('{{flutter_build_config}}'));
    expect(bootstrap, contains('{{flutter_service_worker_version}}'));
    expect(bootstrap, contains('initializeEngine'));
    expect(bootstrap, contains('runApp'));
  });

  test('and the first frame takes the splash away and says so', () {
    expect(bootstrap, contains("'flutter-first-frame'"));
    expect(bootstrap, contains("getElementById('splash')"));
    expect(bootstrap, contains("performance.mark('garage-first-frame')"));
    expect(bootstrap, contains('__garageFirstFrame = true'));
  });
}
