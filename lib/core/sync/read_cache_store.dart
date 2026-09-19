import 'package:shared_preferences/shared_preferences.dart';

/// Where a read's last good rows are kept, as one JSON string per key.
///
/// A seam like `PendingWriteStore` and `GarageBootstrapCache`: the device's
/// preferences in the app, a map in a test, nothing at all where a cold path
/// should be measured rather than skipped.
abstract interface class ReadCacheStore {
  Future<String?> read(String key);

  Future<void> write(String key, String json);

  Future<void> remove(String key);

  /// Forgets everything. Called on sign-out: a shared phone must not keep the
  /// previous account's entries on disk for the next person to open the app
  /// into.
  Future<void> clear();
}

/// The device's preferences, the same place the startup cache lives.
///
/// One string per key rather than one blob for everything, so a list that
/// changes rewrites only itself. The prefix is what `clear` removes by, and
/// what keeps the startup cache and the write queue out of its way.
class PrefsReadCacheStore implements ReadCacheStore {
  static const _prefix = 'garage.read.v1.';

  @override
  Future<String?> read(String key) async {
    try {
      return (await SharedPreferences.getInstance()).getString('$_prefix$key');
    } catch (_) {
      // A copy that cannot be read is a copy that is not there.
      return null;
    }
  }

  @override
  Future<void> write(String key, String json) async {
    await (await SharedPreferences.getInstance()).setString(
      '$_prefix$key',
      json,
    );
  }

  @override
  Future<void> remove(String key) async {
    await (await SharedPreferences.getInstance()).remove('$_prefix$key');
  }

  @override
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys()) {
      if (key.startsWith(_prefix)) {
        await prefs.remove(key);
      }
    }
  }
}

/// A store with nothing in it, for tests and for a scope that must not reach
/// the device's preferences.
class NoReadCacheStore implements ReadCacheStore {
  const NoReadCacheStore();

  @override
  Future<String?> read(String key) async => null;

  @override
  Future<void> write(String key, String json) async {}

  @override
  Future<void> remove(String key) async {}

  @override
  Future<void> clear() async {}
}

/// A store in memory, for a test that wants to see what was kept.
class InMemoryReadCacheStore implements ReadCacheStore {
  final Map<String, String> _entries = {};

  Iterable<String> get keys => _entries.keys;

  @override
  Future<String?> read(String key) async => _entries[key];

  @override
  Future<void> write(String key, String json) async => _entries[key] = json;

  @override
  Future<void> remove(String key) async => _entries.remove(key);

  @override
  Future<void> clear() async => _entries.clear();
}
