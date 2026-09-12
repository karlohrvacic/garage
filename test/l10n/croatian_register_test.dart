import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Croatian addresses the reader informally, in the singular, everywhere.
///
/// It used to do both: 131 strings said *vi* and 45 said *ti*, and they met in
/// the same view — an error reading "Pokušajte ponovno." above a button
/// reading "Pokušaj ponovno". Italian had already settled on *tu*, and the
/// English voice is direct, so *ti* is the one all three now share.
///
/// The rule is worth a test rather than a note, because the formal forms are
/// what a translator reaches for by default: every one of them came back the
/// first time somebody added a string without knowing the convention.
void main() {
  final hr =
      jsonDecode(File('lib/l10n/app_hr.arb').readAsStringSync())
          as Map<String, dynamic>;

  final strings = hr.entries.where((e) => !e.key.startsWith('@'));

  // Dart's `\b` is ASCII-only, so it treats the `š` in "više" as a word
  // boundary and finds a `vi` that is not there. Croatian letters have to be
  // spelled into the lookarounds by hand.
  const letter = r'[A-Za-zčćžšđČĆŽŠĐ0-9_]';

  test('no string addresses the reader as vi', () {
    // The pronouns and possessives. `vas` is deliberately here too: it is the
    // stressed accusative, and the informal clitic is `te`.
    final formal = RegExp(
      '(?<!$letter)(vi|vas|vam|vama|vaš|vaša|vaše|vašu|vaši|vaših|vašim|'
      'vašoj|vašem|vašeg|Vi|Vas|Vam|Vaš|Vaša|Vaše|Vaši)(?!$letter)',
    );
    final offenders = [
      for (final entry in strings)
        if (formal.hasMatch('${entry.value}')) '${entry.key}: ${entry.value}',
    ];

    expect(offenders, isEmpty, reason: 'Croatian is informal — use ti/tvoj');
  });

  test('no string uses the formal plural verb', () {
    // `ste`/`niste` are the giveaway, and they carry a second problem: the
    // past tense they sit in has no gender in the plural and needs one in the
    // singular, which the app cannot know. Those strings are written round it
    // — passively, or as a noun — rather than guessing.
    // `biste`/`bismo` are the formal conditional, and they hid from the first
    // version of this test: two strings still said "da biste ovo premjestili"
    // long after every `ste` had gone.
    final formalVerb = RegExp('(?<!$letter)(ste|niste|biste|bismo)(?!$letter)');
    final offenders = [
      for (final entry in strings)
        if (formalVerb.hasMatch('${entry.value}'))
          '${entry.key}: ${entry.value}',
    ];

    expect(
      offenders,
      isEmpty,
      reason: 'rewrite passively rather than picking a gender for the reader',
    );
  });

  test('nor in a conditional or an adjective', () {
    // The two vectors the participle rule misses, and the reason this one is
    // an allowlist rather than a clever pattern: Croatian cannot tell you
    // whose gender a form carries without parsing it. "Izvoz je spreman" is
    // the gender of *izvoz*, and safe; "Ako bi htio" is the gender of the
    // reader, and not. A first attempt scoped the search to strings
    // containing `ti`/`si`, which read well and caught nothing — "Ako bi
    // htio, spremi" contains neither.
    //
    // So every occurrence fails, and the three that are a noun's own gender
    // are named here with the noun that owns it. A new one is a decision
    // somebody makes on purpose, which is the only safe way round this.
    const nounGender = {
      'fuelMissedFillHint': 'podatak',
      'settingsExportDone': 'izvoz',
      'csvReadyToImport': 'redak',
    };
    final leaks = RegExp(
      '(?<!$letter)(bi\\s+$letter+(ao|la|io|ila)|siguran|sigurna|spreman|'
      'spremna|dužan|dužna|prijavljen|prijavljena)(?!$letter)',
    );
    final offenders = [
      for (final entry in strings)
        if (leaks.hasMatch('${entry.value}') &&
            !nounGender.containsKey(entry.key))
          '${entry.key}: ${entry.value}',
    ];

    expect(
      offenders,
      isEmpty,
      reason: 'say it without a gender, or add the noun that owns it above',
    );
  });

  test('and no string picks a gender for the reader either', () {
    // The trap on the other side of the same coin: an informal past tense has
    // to agree with the reader, and "kupio si" tells half the households using
    // this app that it was not written for them.
    final gendered = RegExp(
      '(?<!$letter)(si|nisi)\\s+$letter+(ao|la|io|ila)(?!$letter)',
    );
    final offenders = [
      for (final entry in strings)
        if (gendered.hasMatch('${entry.value}')) '${entry.key}: ${entry.value}',
    ];

    expect(offenders, isEmpty, reason: 'no gendered past tense in Croatian');
  });
}
