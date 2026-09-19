import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/errors/app_failure.dart';
import 'package:garage/core/errors/failure_log.dart';
import 'package:garage/core/sync/read_cache.dart';
import 'package:garage/core/sync/read_cache_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A store whose writes fail, for the rule that a read never fails on one;
/// with [clearFails], one whose clear fails too, for the rule that a sign-out
/// never fails on it either.
class BrokenStore implements ReadCacheStore {
  BrokenStore({this.clearFails = false});

  final bool clearFails;
  final inner = InMemoryReadCacheStore();

  @override
  Future<String?> read(String key) => inner.read(key);

  @override
  Future<void> write(String key, String json) async =>
      throw StateError('disk full');

  @override
  Future<void> remove(String key) => inner.remove(key);

  @override
  Future<void> clear() async {
    if (clearFails) {
      throw StateError('storage denied');
    }
    await inner.clear();
  }
}

const offline = AppFailure(kind: AppFailureKind.network);
const tooSlow = AppFailure(kind: AppFailureKind.timeout);
const refused = AppFailure(kind: AppFailureKind.permission);

Rows rowsOf(String id) => [
  {'id': id, 'vehicle_id': 'v1'},
];

void main() {
  // A copy that cannot be kept is reported through the failure log, whose
  // best-effort persistence must land in a mock rather than a platform channel.
  setUp(() => SharedPreferences.setMockInitialValues({}));

  late InMemoryReadCacheStore store;
  late ReadCache cache;
  var now = DateTime.utc(2026, 9, 18, 14, 2);

  setUp(() {
    store = InMemoryReadCacheStore();
    now = DateTime.utc(2026, 9, 18, 14, 2);
    cache = ReadCache(store: store, userId: () => 'u1', now: () => now);
  });

  group('a read through the cache', () {
    test('returns what the fetch returned and keeps a copy', () async {
      final rows = await cache.rows('fuel/v1', () async => rowsOf('f1'));

      expect(rows, rowsOf('f1'));
      expect(
        jsonDecode((await store.read('u1/fuel/v1'))!),
        containsPair('rows', rowsOf('f1')),
      );
      expect(cache.stale.value.any, isFalse);
    });

    test('serves the copy when the network is gone, and says so', () async {
      await cache.rows('fuel/v1', () async => rowsOf('f1'));
      now = now.add(const Duration(hours: 3));

      final rows = await cache.rows('fuel/v1', () async => throw offline);

      expect(rows, rowsOf('f1'));
      expect(cache.stale.value.byKey, {
        'fuel/v1': DateTime.utc(2026, 9, 18, 14, 2),
      });
      expect(cache.stale.value.oldest, DateTime.utc(2026, 9, 18, 14, 2));
    });

    test('a timeout is the network too', () async {
      await cache.rows('fuel/v1', () async => rowsOf('f1'));

      expect(
        await cache.rows('fuel/v1', () async => throw tooSlow),
        rowsOf('f1'),
      );
    });

    test('does not paper over a refusal with an old list', () async {
      await cache.rows('fuel/v1', () async => rowsOf('f1'));

      await expectLater(
        cache.rows('fuel/v1', () async => throw refused),
        throwsA(isA<AppFailure>()),
      );
      expect(cache.stale.value.any, isFalse);
    });

    test('a miss offline fails as it always did', () async {
      await expectLater(
        cache.rows('fuel/v1', () async => throw offline),
        throwsA(isA<AppFailure>()),
      );
    });

    test('rethrows the raw error, so the repository still maps it', () async {
      // The repository wraps its query in `AppFailure.from`; the cache sits
      // inside that try, so what it rethrows must be what was thrown.
      final raw = Exception('socket closed');

      await expectLater(
        cache.rows('fuel/v1', () async => throw raw),
        throwsA(same(raw)),
      );
    });

    test('a copy stops being stale once a fetch succeeds again', () async {
      await cache.rows('fuel/v1', () async => rowsOf('f1'));
      await cache.rows('fuel/v1', () async => throw offline);
      expect(cache.stale.value.any, isTrue);

      await cache.rows('fuel/v1', () async => rowsOf('f2'));

      expect(cache.stale.value.any, isFalse);
      expect(
        await cache.rows('fuel/v1', () async => throw offline),
        rowsOf('f2'),
      );
    });

    test('the oldest stale copy is the one the banner names', () async {
      await cache.rows('fuel/v1', () async => rowsOf('f1'));
      now = now.add(const Duration(days: 1));
      await cache.rows('costs/v1', () async => rowsOf('c1'));
      await cache.rows('fuel/v1', () async => throw offline);
      await cache.rows('costs/v1', () async => throw offline);

      expect(cache.stale.value.oldest, DateTime.utc(2026, 9, 18, 14, 2));
    });

    test('is kept per user: another account gets a miss', () async {
      await cache.rows('fuel/v1', () async => rowsOf('f1'));
      final other = ReadCache(store: store, userId: () => 'u2');

      await expectLater(
        other.rows('fuel/v1', () async => throw offline),
        throwsA(isA<AppFailure>()),
      );
    });

    test('with nobody signed in nothing is kept', () async {
      final anonymous = ReadCache(store: store, userId: () => null);

      await anonymous.rows('fuel/v1', () async => rowsOf('f1'));

      expect(store.keys, isEmpty);
    });

    test('a copy that does not decode is a miss', () async {
      await store.write('u1/fuel/v1', '{not json');

      await expectLater(
        cache.rows('fuel/v1', () async => throw offline),
        throwsA(isA<AppFailure>()),
      );
    });

    test('a store that cannot write never fails the read', () async {
      final broken = ReadCache(store: BrokenStore(), userId: () => 'u1');

      expect(
        await broken.rows('fuel/v1', () async => rowsOf('f1')),
        rowsOf('f1'),
      );
    });

    test('a list too large to keep is not kept', () async {
      final huge = [
        for (var i = 0; i < 20000; i++) {'id': 'f$i', 'notes': 'x' * 60},
      ];
      await cache.rows('fuel/v1', () async => rowsOf('f1'));

      await cache.rows('fuel/v1', () async => huge);

      expect(await store.read('u1/fuel/v1'), isNull);
    });

    test('forget clears every copy and the stale set', () async {
      await cache.rows('fuel/v1', () async => rowsOf('f1'));
      await cache.rows('fuel/v1', () async => throw offline);

      await cache.forget();

      expect(store.keys, isEmpty);
      expect(cache.stale.value.any, isFalse);
    });

    test('a store that cannot clear never fails the sign-out', () async {
      final store = BrokenStore(clearFails: true);
      final broken = ReadCache(
        store: store,
        userId: () => 'u1',
        now: () => now,
      );
      await store.inner.write(
        'u1/fuel/v1',
        jsonEncode({'stored_at': now.toIso8601String(), 'rows': rowsOf('f1')}),
      );
      await broken.rows('fuel/v1', () async => throw offline);
      expect(broken.stale.value.any, isTrue);

      await broken.forget();

      expect(broken.stale.value.any, isFalse);
      expect(recordedFailures, anyElement(contains('could not clear')));
    });

    test('unmarkAll empties the stale set and keeps every copy', () async {
      await cache.rows('fuel/v1', () async => rowsOf('f1'));
      await cache.rows('fuel/v1', () async => throw offline);
      expect(cache.stale.value.any, isTrue);

      cache.unmarkAll();

      expect(cache.stale.value.any, isFalse);
      expect(await store.read('u1/fuel/v1'), isNotNull);
    });
  });

  group('the preferences store', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('keeps a key under its own prefix and clears only those', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('garage.bootstrap.v1', 'keep me');
      final store = PrefsReadCacheStore();

      await store.write('u1/fuel/v1', '{"rows":[]}');
      expect(await store.read('u1/fuel/v1'), '{"rows":[]}');

      await store.clear();

      expect(await store.read('u1/fuel/v1'), isNull);
      expect(prefs.getString('garage.bootstrap.v1'), 'keep me');
    });
  });
}
