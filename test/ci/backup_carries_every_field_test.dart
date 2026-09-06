import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A backup is the only file that comes *back*, and a list it does not write
/// is a part of somebody's garage that quietly does not survive a restore.
///
/// Observations shipped without being carried, and nothing said so: the file
/// was still valid, the restore still succeeded, and the problem diary was
/// simply absent afterwards. This checks that every list on `VehicleBackup` is
/// named in both directions of the codec.
void main() {
  test('every list a VehicleBackup holds is written and read back', () {
    final source = File(
      'lib/domain/export/garage_backup.dart',
    ).readAsStringSync();

    final classBody = source.substring(
      source.indexOf('class VehicleBackup'),
      source.indexOf('class RestoredBackup'),
    );
    final fields = RegExp(
      r'final List<\w+> (\w+);',
    ).allMatches(classBody).map((match) => match.group(1)!).toSet();

    expect(
      fields,
      isNotEmpty,
      reason:
          'the field pattern no longer matches — fix this test, not the code',
    );

    final encode = source.substring(
      source.indexOf('static String encode'),
      source.indexOf('static RestoredBackup decode'),
    );
    final decode = source.substring(
      source.indexOf('static RestoredBackup decode'),
    );

    final missing = <String>[];
    for (final field in fields) {
      // The JSON key is not always the field name — `readings`, `documents`
      // and the rest happen to match, and anything that does not can be
      // spelled here rather than silently skipped.
      const jsonKey = <String, String>{};
      final key = jsonKey[field] ?? field;
      if (!encode.contains("'$key'") || !encode.contains('entry.$field')) {
        missing.add('$field is not written');
      }
      if (!decode.contains("'$key'")) {
        missing.add('$field is not read back');
      }
    }

    expect(missing, isEmpty);
  });
}
