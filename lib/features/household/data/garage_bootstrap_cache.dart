import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'garage_bootstrap.dart';
import 'supabase_garage_bootstrap_repository.dart';

/// The last garage this device saw, so a cold start can draw one before the
/// network answers.
///
/// The app's first frame used to wait on a round trip: engine, session, then
/// households and vehicles, and only then a dashboard. At a pump, on a phone
/// that has just woken up, that is the whole app feeling slow — and the one
/// entry point where it matters most, the fill-up widget, pays it every time.
///
/// **It stores the rows, not the entities.** Parsing is
/// [garageBootstrapFromRows] either way, so there is one reader of a vehicle
/// row in the codebase and a column added tomorrow cannot mean two things.
abstract interface class GarageBootstrapCache {
  /// What was last saved for [userId], or null — no cache, another account's,
  /// or too old to show.
  Future<GarageBootstrap?> read(String userId);

  Future<void> write(
    String userId, {
    required List<Map<String, dynamic>> households,
    required List<Map<String, dynamic>> vehicles,
  });

  /// Forgets it entirely. Called on sign-out: a shared phone must not keep the
  /// previous account's garage on disk.
  Future<void> clear();
}

/// Beyond this the cache is not shown at all.
///
/// Not because it would be wrong — the refresh behind it corrects anything
/// stale within a second of the app opening — but because a phone that has
/// been offline for a month should not open on a garage from a month ago and
/// look current. It refetches instead, and says so if it cannot.
const Duration bootstrapCacheMaxAge = Duration(days: 30);

class PrefsGarageBootstrapCache implements GarageBootstrapCache {
  PrefsGarageBootstrapCache({DateTime Function()? now})
    : _now = now ?? DateTime.now;

  static const _key = 'garage.bootstrap.v1';

  final DateTime Function() _now;

  @override
  Future<GarageBootstrap?> read(String userId) async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_key);
      if (raw == null) {
        return null;
      }
      final json = jsonDecode(raw) as Map<String, dynamic>;
      // Another account on the same phone gets a miss, not somebody else's
      // garage. The same rule `garageBootstrapProvider` follows for the same
      // reason.
      if (json['user'] != userId) {
        return null;
      }
      final savedAt = DateTime.tryParse(json['saved_at'] as String? ?? '');
      if (savedAt == null ||
          _now().toUtc().difference(savedAt) > bootstrapCacheMaxAge) {
        return null;
      }
      return garageBootstrapFromRows(
        households: _rows(json['households']),
        vehicles: _rows(json['vehicles']),
      );
    } catch (_) {
      // A cache that cannot be read is a cache that is not there. It is an
      // optimisation over a fetch that is about to happen anyway, and there is
      // no state of it worth failing a cold start for.
      return null;
    }
  }

  @override
  Future<void> write(
    String userId, {
    required List<Map<String, dynamic>> households,
    required List<Map<String, dynamic>> vehicles,
  }) async {
    try {
      await (await SharedPreferences.getInstance()).setString(
        _key,
        jsonEncode({
          'user': userId,
          'saved_at': _now().toUtc().toIso8601String(),
          'households': households,
          'vehicles': vehicles,
        }),
      );
    } catch (_) {
      // Same reasoning as a failed read: the app has the data it just fetched.
    }
  }

  @override
  Future<void> clear() async {
    try {
      await (await SharedPreferences.getInstance()).remove(_key);
    } catch (_) {
      // Nothing to do about it, and nothing depends on it having worked.
    }
  }
}

List<Map<String, dynamic>> _rows(Object? value) {
  return [
    for (final row in (value as List<dynamic>? ?? const []))
      Map<String, dynamic>.from(row as Map),
  ];
}

/// A cache that never has anything, for tests and for anywhere a cold start
/// should be measured rather than skipped.
class NoGarageBootstrapCache implements GarageBootstrapCache {
  const NoGarageBootstrapCache();

  @override
  Future<GarageBootstrap?> read(String userId) async => null;

  @override
  Future<void> write(
    String userId, {
    required List<Map<String, dynamic>> households,
    required List<Map<String, dynamic>> vehicles,
  }) async {}

  @override
  Future<void> clear() async {}
}
