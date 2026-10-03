import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../support/workflow_steps.dart';

/// The web build's fonts are cut to `scripts/web_font_ranges.txt`
/// (decision 189). A character outside it is drawn from a fallback font the
/// engine fetches from Google, so every character the app itself writes has to
/// be inside, and so do the scripts somebody's name is likely written in.
List<(int, int)> _ranges() => [
  for (final line in File('scripts/web_font_ranges.txt').readAsLinesSync())
    if (RegExp(r'^U\+([0-9A-F]+)(?:-([0-9A-F]+))?').firstMatch(line.trim())
        case final match?)
      (
        int.parse(match[1]!, radix: 16),
        int.parse(match[2] ?? match[1]!, radix: 16),
      ),
];

void main() {
  final ranges = _ranges();
  bool covered(int rune) => ranges.any((r) => r.$1 <= rune && rune <= r.$2);

  test('the list reads as ranges at all', () {
    expect(ranges, isNotEmpty);
  });

  test('every character the app writes, in every language, is kept', () {
    final missing = <String>{};
    for (final file in Directory('lib/l10n').listSync().whereType<File>()) {
      if (!file.path.endsWith('.arb')) {
        continue;
      }
      final messages = jsonDecode(file.readAsStringSync()) as Map;
      for (final MapEntry(:key, :value) in messages.entries) {
        if (key.toString().startsWith('@') || value is! String) {
          continue;
        }
        for (final rune in value.runes) {
          if (!covered(rune)) {
            missing.add('U+${rune.toRadixString(16).toUpperCase()} in $key');
          }
        }
      }
    }
    expect(missing, isEmpty);
  });

  test('Croatian and Italian letters, the euro and the arrows are kept', () {
    for (final char in 'čćđšžČĆĐŠŽàèéìòùÀÈÉÌÒÙ€→›–—…„“”'.runes) {
      expect(covered(char), isTrue, reason: String.fromCharCode(char));
    }
  });

  test('Greek and Cyrillic are kept, so a name in them stays on our fonts', () {
    expect(covered(0x03B1), isTrue); // α
    expect(covered(0x0436), isTrue); // ж
  });

  test('the apostrophe of a Ukrainian name and the keys of a shortcut too', () {
    for (final char in 'ʼ⌃⌘⌥'.runes) {
      expect(covered(char), isTrue, reason: String.fromCharCode(char));
    }
  });

  test('the deploy and the pull-request build both cut the fonts', () {
    for (final path in [
      '.github/workflows/deploy-web.yml',
      '.github/workflows/ci.yml',
    ]) {
      final workflow = File(path).readAsStringSync();
      // The command, not a comment that mentions it.
      final build = RegExp(
        r'^[ \t]*(?:run:[ \t]*)?flutter build web',
        multiLine: true,
      ).firstMatch(workflow)!.start;
      final subset = workflow.indexOf('scripts/subset_web_fonts.sh');
      expect(subset, greaterThan(build), reason: path);
    }
  });

  test('ci.yml cuts the fonts only when it has built them', () {
    // On main the deploy calls ci.yml, which then builds no web app: a cut
    // that ran anyway would find no build/web and fail the deploy's checks.
    final ci = File('.github/workflows/ci.yml').readAsStringSync();
    final build = conditionOf(ci, 'flutter build web');
    expect(
      build,
      isNotNull,
      reason: 'the web build here is pull requests only',
    );
    expect(conditionOf(ci, 'scripts/subset_web_fonts.sh'), build);
  });

  test('the cut keeps the licence the OFL asks every copy to carry', () {
    // Name IDs 13 and 14 are the licence and its address. pyftsubset keeps
    // only 0 to 6 unless told, and nothing else in the web build carries the
    // licence of Inter or JetBrains Mono.
    expect(
      File('scripts/subset_web_fonts.sh').readAsStringSync(),
      contains('--name-IDs+=13,14'),
    );
  });
}
