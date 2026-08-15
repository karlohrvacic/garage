import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/api/api_key.dart';

void main() {
  group('generating a key', () {
    test('is prefixed so it is recognisable in a config file', () {
      expect(ApiKeys.generate(), startsWith('grg_'));
    });

    test('is long enough not to be guessed', () {
      // 32 random characters after the prefix is 160+ bits of entropy.
      expect(ApiKeys.generate().length, greaterThanOrEqualTo(36));
    });

    test('uses only characters that survive a URL and a shell', () {
      expect(ApiKeys.generate(), matches(RegExp(r'^grg_[A-Za-z0-9_-]+$')));
    });

    test('never repeats', () {
      final keys = {for (var i = 0; i < 200; i++) ApiKeys.generate()};

      expect(keys, hasLength(200));
    });
  });

  group('hashing a key', () {
    test('is what gets stored, never the key itself', () {
      final key = ApiKeys.generate();

      expect(ApiKeys.hash(key), isNot(contains(key)));
      expect(ApiKeys.hash(key), hasLength(64));
    });

    test('is deterministic, so a presented key can be matched', () {
      const key = 'grg_abc123';

      expect(ApiKeys.hash(key), ApiKeys.hash(key));
    });

    test('is different for different keys', () {
      expect(ApiKeys.hash('grg_a'), isNot(ApiKeys.hash('grg_b')));
    });

    test('is plain lowercase hex', () {
      expect(ApiKeys.hash('grg_a'), matches(RegExp(r'^[0-9a-f]{64}$')));
    });
  });

  group('showing a key back', () {
    test('only the last few characters, so a list can be read', () {
      expect(ApiKeys.preview('grg_abcdefghijklmnop'), '…mnop');
    });

    test('a short key is not padded into something misleading', () {
      expect(ApiKeys.preview('abc'), '…abc');
    });
  });
}
