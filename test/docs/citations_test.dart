import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every `path:line` citation in `docs/` points at a file that exists, at a
/// line that exists in it.
///
/// The docs tree is written to be believed — it is the thing a new developer
/// or an agent reads *instead* of the code — and CLAUDE.md says as much: a doc
/// that is merely out of date is worse than no doc. Line numbers rot silently
/// the moment code moves, and the repo's own instructions ask for a citation
/// check that lives outside this repository, in a skill directory, so it runs
/// only when somebody remembers.
///
/// This is the half that can be checked here, on every push: the file is still
/// there, and the line is still inside it. It cannot tell whether line 111
/// still says what the paragraph claims — only the reader can — but a citation
/// pointing past the end of a file, or at a file that was renamed, is
/// unambiguous rot and is exactly what a rename produces.
///
/// Bare basenames (`unit_format.dart:9`) are deliberately not checked: they
/// are a shorthand the docs use once the full path has been given a paragraph
/// earlier, and there is no path to resolve.
void main() {
  final citation = RegExp(
    r'`([A-Za-z0-9_./-]*/[A-Za-z0-9_./-]+'
    r'\.(?:dart|sql|ts|json|yaml|yml|arb|html|xml|kt|gradle)):(\d+)`',
  );

  /// Every file in the tree by basename, for resolving a bare citation.
  final byName = <String, List<String>>{};
  for (final root in ['lib', 'supabase', 'test', 'web', 'android']) {
    final directory = Directory(root);
    if (!directory.existsSync()) {
      continue;
    }
    for (final file in directory.listSync(recursive: true)) {
      if (file is File) {
        byName.putIfAbsent(file.uri.pathSegments.last, () => []).add(file.path);
      }
    }
  }

  /// The lines a citation must not land on: the definition it named has moved
  /// and the number has stayed behind.
  const emptyLanding = {'', '{', '}', ');', '},', '),', '];', ']'};

  final found = <String>[];
  final broken = <String>[];

  for (final file in Directory('docs').listSync(recursive: true)) {
    if (file is! File || !file.path.endsWith('.md')) {
      continue;
    }
    // `docs/superpowers/` holds working specs and plans that are gitignored —
    // a CI checkout does not have them at all, so checking them here would
    // fail only on the machine that wrote them.
    if (file.path.contains('/superpowers/')) {
      continue;
    }
    final lines = file.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      for (final match in citation.allMatches(lines[i])) {
        final path = match.group(1)!;
        final line = int.parse(match.group(2)!);
        found.add('$path:$line');

        final target = File(path);
        if (!target.existsSync()) {
          broken.add('${file.path}:${i + 1} cites $path, which does not exist');
          continue;
        }
        final targetLines = target.readAsLinesSync();
        if (line > targetLines.length) {
          broken.add(
            '${file.path}:${i + 1} cites $path:$line, '
            'but that file has ${targetLines.length} lines',
          );
          continue;
        }
        // A citation that lands on a closing brace or a blank line is the
        // shape rot takes when the *file* still has the line: the definition
        // moved and the number stayed. Thirteen citations were found in this
        // state in one night — four of them made that same night, by edits
        // above the thing being cited — and every one of them was wrong.
        //
        // It cannot catch a citation that drifted onto a different *statement*,
        // which only a reader can. It catches the common half for nothing.
        final landing = targetLines[line - 1].trim();
        if (emptyLanding.contains(landing)) {
          broken.add(
            '${file.path}:${i + 1} cites $path:$line, which is "$landing" — '
            'the definition it named has moved',
          );
        }
      }
    }
  }

  /// The same check for the shorthand form, resolved by name.
  final bareCitation = RegExp(r'`([A-Za-z0-9_-]+\.(?:dart|sql|ts)):(\d+)`');
  var bare = 0;

  for (final file in Directory('docs').listSync(recursive: true)) {
    if (file is! File || !file.path.endsWith('.md')) {
      continue;
    }
    if (file.path.contains('/superpowers/')) {
      continue;
    }
    final lines = file.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      for (final match in bareCitation.allMatches(lines[i])) {
        final name = match.group(1)!;
        final line = int.parse(match.group(2)!);
        final candidates = byName[name] ?? const <String>[];
        if (candidates.isEmpty) {
          broken.add(
            '${file.path}:${i + 1} cites $name, and no file of that name '
            'exists — a rename left the shorthand behind',
          );
          continue;
        }
        // Two files of one name is not rot, it is an ambiguity this check
        // cannot resolve; the docs happen to have none today.
        if (candidates.length > 1) {
          continue;
        }
        bare++;
        final targetLines = File(candidates.single).readAsLinesSync();
        if (line > targetLines.length) {
          broken.add(
            '${file.path}:${i + 1} cites $name:$line, but '
            '${candidates.single} has ${targetLines.length} lines',
          );
          continue;
        }
        final landing = targetLines[line - 1].trim();
        if (emptyLanding.contains(landing)) {
          broken.add(
            '${file.path}:${i + 1} cites $name:$line, which is "$landing" in '
            '${candidates.single} — the definition it named has moved',
          );
        }
      }
    }
  }

  test('the shorthand citations resolve too', () {
    expect(
      bare,
      greaterThan(20),
      reason: 'the bare-name pattern matched almost nothing — has it drifted?',
    );
  });

  test('the docs are actually being read', () {
    // A regex that stopped matching would make the check below pass over
    // nothing, which is the failure mode a parsing test has.
    expect(
      found.length,
      greaterThan(100),
      reason: 'the citation pattern matched almost nothing — has it drifted?',
    );
  });

  test('every cited file and line still exists', () {
    expect(
      broken,
      isEmpty,
      reason:
          'a citation that no longer resolves is documentation rot, and the '
          'docs are read instead of the code',
    );
  });
}
