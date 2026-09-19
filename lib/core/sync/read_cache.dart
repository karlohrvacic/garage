import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../errors/app_failure.dart';
import '../errors/failure_log.dart';
import 'read_cache_store.dart';

typedef Rows = List<Map<String, dynamic>>;

/// Beyond this a list is not kept. A typical household is well under a
/// megabyte in total; a log this large would exhaust a browser's storage
/// and bloat the preferences file on a phone, and the app has the rows it
/// just fetched either way.
const int readCacheMostBytes = 1 << 20;

/// The reads currently being served from a copy rather than the server, and
/// when each copy was taken.
class StaleReads {
  const StaleReads(this.byKey);

  final Map<String, DateTime> byKey;

  bool get any => byKey.isNotEmpty;

  /// The copy the banner names: the oldest, because a screen showing three
  /// lists is only as current as the least current of them.
  DateTime? get oldest => byKey.values.isEmpty
      ? null
      : byKey.values.reduce((a, b) => a.isBefore(b) ? a : b);
}

/// The last good rows of every list read, served back when the network is
/// gone.
///
/// Sits inside a Supabase repository's list read, between the query and the
/// row reader, so parsing stays in the one `fromRow` per table — the rule the
/// startup cache set (decision 126). Only a connection failure falls back to
/// the copy: a refusal is the server answering, and an old list over a
/// permission error would hide the one thing the person needs to know.
///
/// A copy has no expiry. It is marked as old on the screen instead, which is
/// honest about a phone that has been away for a month and useful about one
/// that has been in a tunnel for a minute.
class ReadCache {
  ReadCache({
    required this.store,
    required this.userId,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final ReadCacheStore store;

  /// Who the copy belongs to. Keyed by user so another account on the same
  /// phone gets a miss, never somebody else's history.
  final String? Function() userId;

  final DateTime Function() _now;

  final ValueNotifier<StaleReads> stale = ValueNotifier(const StaleReads({}));

  Future<Rows> rows(String key, Future<Rows> Function() fetch) async {
    final user = userId();
    final storeKey = user == null ? null : '$user/$key';
    try {
      final fresh = await fetch();
      if (storeKey != null) {
        await _keep(storeKey, fresh);
        _unmark(key);
      }
      return fresh;
    } catch (error) {
      // The repository maps whatever the query threw with `AppFailure.from`
      // in its own catch, so what leaves here must be what arrived.
      if (storeKey == null || !AppFailure.from(error).isConnectionFailure) {
        rethrow;
      }
      final copy = await _copy(storeKey);
      if (copy == null) {
        rethrow;
      }
      _mark(key, copy.storedAt);
      return copy.rows;
    }
  }

  /// Forgets every copy and every mark. Sign-out.
  ///
  /// A store that cannot be cleared is recorded and never fails the sign-out:
  /// the marks go regardless, and a copy left behind is keyed by the account
  /// that is leaving, so the next one on the phone gets a miss, not a history.
  Future<void> forget() async {
    try {
      await store.clear();
    } catch (error) {
      reportFailure(
        AppFailure(
          kind: AppFailureKind.unknown,
          debugMessage: 'read cache: could not clear: $error',
        ),
      );
    }
    stale.value = const StaleReads({});
  }

  /// Forgets every mark and keeps every copy. Before a wholesale refetch.
  ///
  /// A mark belongs to a list that was being shown when the copy was served,
  /// and invalidating refetches only what is still watched: a list whose
  /// screen has since been closed would keep its mark for as long as the app
  /// runs. Cleared first, the lists still on screen re-mark themselves if
  /// they are still served from a copy, and the ones nothing shows drop.
  void unmarkAll() {
    stale.value = const StaleReads({});
  }

  Future<void> _keep(String storeKey, Rows rows) async {
    try {
      final json = jsonEncode({
        'stored_at': _now().toUtc().toIso8601String(),
        'rows': rows,
      });
      if (json.length > readCacheMostBytes) {
        await store.remove(storeKey);
        reportFailure(
          AppFailure(
            kind: AppFailureKind.unknown,
            debugMessage:
                'read cache: $storeKey is ${json.length} bytes, not kept',
          ),
        );
        return;
      }
      await store.write(storeKey, json);
    } catch (error) {
      // The read has its rows. A copy that could not be kept costs the next
      // offline read, not this one.
      reportFailure(
        AppFailure(
          kind: AppFailureKind.unknown,
          debugMessage: 'read cache: could not keep $storeKey: $error',
        ),
      );
    }
  }

  Future<({Rows rows, DateTime storedAt})?> _copy(String storeKey) async {
    try {
      final raw = await store.read(storeKey);
      if (raw == null) {
        return null;
      }
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final storedAt = DateTime.parse(json['stored_at'] as String);
      final rows = [
        for (final row in json['rows'] as List<dynamic>)
          Map<String, dynamic>.from(row as Map),
      ];
      return (rows: rows, storedAt: storedAt);
    } catch (_) {
      // A copy that cannot be read is a copy that is not there.
      return null;
    }
  }

  void _mark(String key, DateTime storedAt) {
    stale.value = StaleReads({...stale.value.byKey, key: storedAt});
  }

  void _unmark(String key) {
    if (!stale.value.byKey.containsKey(key)) {
      return;
    }
    stale.value = StaleReads({...stale.value.byKey}..remove(key));
  }
}
