import 'dart:convert';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/files/file_text.dart';
import 'package:garage/domain/import/fuelio_backup.dart';

void main() {
  group('reading a picked file as text', () {
    // The bug this exists for. `XFile.readAsString` looks like it decodes as
    // UTF-8 — it even takes an `encoding` parameter — but when the XFile was
    // built from bytes rather than a path it runs `String.fromCharCodes`,
    // which is Latin-1, and ignores the parameter entirely. Android's picker
    // hands back bytes, so every Croatian diacritic in an imported file came
    // out as mojibake: "svjećica" as "svjeÄica". Nothing threw; the text was
    // simply wrong, and a Fuelio reminder whose name no longer matched any
    // known service silently imported as nothing.
    test('a file made of bytes keeps its diacritics', () async {
      final file = XFile.fromData(
        utf8.encode('Zamjena svjećica, kočione tekućine, putničkog prostora'),
        name: 'fuelio.csv',
      );

      expect(
        await readTextFile(file),
        'Zamjena svjećica, kočione tekućine, putničkog prostora',
      );
    });

    test('and readAsString is what gets this wrong', () async {
      // Kept as the proof: if a future cross_file fixes this, the helper is
      // still correct and this test is what says the workaround can go.
      final file = XFile.fromData(utf8.encode('svjećica'), name: 'a.csv');

      expect(await file.readAsString(), isNot('svjećica'));
    });

    test('a byte-order mark is not part of the text', () async {
      // Exported from a spreadsheet on Windows, a CSV routinely carries one,
      // and it would otherwise become an invisible first character of the
      // first header — which is how a column stops being found.
      final file = XFile.fromData(utf8.encode('﻿"## Vehicle"'), name: 'a.csv');

      expect(await readTextFile(file), '"## Vehicle"');
    });

    test('a byte that is not valid UTF-8 does not throw', () async {
      // A file in some other encoding should import as much as it can rather
      // than failing whole. The alternative is "something went wrong" over a
      // backup that is 99% readable.
      final file = XFile.fromData(
        Uint8List.fromList([0x61, 0xFF, 0x62]),
        name: 'a.csv',
      );

      expect(await readTextFile(file), contains('a'));
      expect(await readTextFile(file), contains('b'));
    });
  });

  group('a Fuelio backup picked on a phone', () {
    // The whole failure, end to end and in one place: Android's picker hands
    // back bytes, the bytes were decoded as Latin-1, and every reminder whose
    // name needed a Croatian letter to be recognised silently imported as
    // nothing. Three of this user's ten did.
    const csv = '''
"## Costs"
"CostTitle","Data","Odo","Cost","CostTypeID","RepeatOdo","RepeatMonths"
"Zamjena svjećica","2025-07-27","17006","0.00","1","60000","48"
"Zamjena kočione tekućine","2025-08-01","17100","0.00","1","0","36"
"Zamjena filtra putničkog prostora","2025-07-27","17006","0.00","1","30000","24"
''';

    test('keeps every reminder its names can be recognised by', () async {
      final file = XFile.fromData(utf8.encode(csv), name: 'fuelio.csv');

      final backup = parseFuelioBackup(await readTextFile(file));

      expect(backup.reminders, hasLength(3));
      expect(backup.reminders.map((r) => r.serviceTypeKey), [
        'service_spark_plugs',
        'service_brake_fluid',
        'service_cabin_filter',
      ]);
    });

    test('and readAsString loses all three', () async {
      // The proof that the helper is what fixes it, not the mapping.
      final file = XFile.fromData(utf8.encode(csv), name: 'fuelio.csv');

      final backup = parseFuelioBackup(await file.readAsString());

      expect(
        backup.reminders.map((r) => r.serviceTypeKey),
        everyElement(isNull),
        reason: 'mojibake matches no needle, and nothing throws to say so',
      );
    });
  });
}
