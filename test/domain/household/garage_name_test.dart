import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/household/garage_name.dart';

void main() {
  group('the name taken from a person', () {
    test('is the surname of a full name', () {
      expect(GarageName.fromPerson('Karlo Hrvačić'), 'Hrvačić');
    });

    test('is the last word of a longer name', () {
      expect(GarageName.fromPerson('Ana Marija Kovač Horvat'), 'Horvat');
    });

    test('is a single word as it is', () {
      expect(GarageName.fromPerson('Karlo'), 'Karlo');
    });

    test('ignores surrounding whitespace', () {
      expect(GarageName.fromPerson('  Karlo Hrvačić  '), 'Hrvačić');
    });

    test('is empty for an empty name', () {
      expect(GarageName.fromPerson('   '), '');
    });

    test('is empty for the local part of an e-mail address', () {
      // A sign-up with no display name falls back to it, and "karlo.hrvacic"
      // is nobody's garage.
      expect(GarageName.fromPerson('karlo.hrvacic'), '');
      expect(GarageName.fromPerson('karlo_h'), '');
      expect(GarageName.fromPerson('karlo-h'), '');
      expect(GarageName.fromPerson('karlo92'), '');
    });
  });

  group('the next suggestion', () {
    test('is never the one already in the field', () {
      final random = Random(1);
      const pool = ['A', 'B', 'C'];
      for (var i = 0; i < 50; i++) {
        expect(GarageName.next(pool, 'B', random), isNot('B'));
      }
    });

    test('reaches every entry over enough draws', () {
      final random = Random(1);
      const pool = ['A', 'B', 'C', 'D'];
      final seen = <String>{};
      var current = '';
      for (var i = 0; i < 50; i++) {
        current = GarageName.next(pool, current, random);
        seen.add(current);
      }
      expect(seen, pool.toSet());
    });

    test('returns the only entry when there is nothing else', () {
      expect(GarageName.next(const ['A'], 'A', Random(1)), 'A');
      expect(GarageName.next(const ['A', 'A'], 'A', Random(1)), 'A');
    });

    test('returns the current name for an empty pool', () {
      expect(GarageName.next(const [], 'kept', Random(1)), 'kept');
    });
  });
}
