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

  final found = <String>[];
  final broken = <String>[];

  for (final file in Directory('docs').listSync(recursive: true)) {
    if (file is! File || !file.path.endsWith('.md')) {
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
        final length = target.readAsLinesSync().length;
        if (line > length) {
          broken.add(
            '${file.path}:${i + 1} cites $path:$line, '
            'but that file has $length lines',
          );
        }
      }
    }
  }

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
