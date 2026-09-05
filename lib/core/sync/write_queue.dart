import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'pending_write.dart';

/// Where entries wait when there is nothing to send them to.
abstract interface class PendingWriteStore {
  Future<List<PendingWrite>> all();

  /// Fires whenever the queue changes.
  ///
  /// Without it nothing tells the banner that a write was just kept: the
  /// decorator queues silently by design, so the only other way to notice is
  /// to reopen the app. On a device that reads as the entry having vanished,
  /// which is the exact fear this feature exists to remove.
  Stream<void> get changes;

  /// Upsert by id. Re-saving the same entry replaces it rather than queueing
  /// it twice — the id is the entry's own, so a second attempt is the same
  /// row.
  Future<void> put(PendingWrite write);

  Future<void> remove(String id);
}

/// The queue is small — the entries somebody typed between one signal and the
/// next — so it lives as a JSON list in the preferences the app already
/// carries, rather than bringing in a database for tens of rows.
class SharedPreferencesPendingWriteStore implements PendingWriteStore {
  static const _key = 'pending_writes_v1';

  final _changes = StreamController<void>.broadcast();

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Future<List<PendingWrite>> all() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) {
      return const [];
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return const [];
    }
    return [
      for (final item in decoded)
        // A row this build cannot read is dropped, not thrown: one unreadable
        // entry must not strand the rest of somebody's unsent work.
        if (item is Map<String, dynamic>) ?PendingWrite.fromJson(item),
    ];
  }

  @override
  Future<void> put(PendingWrite write) async {
    final writes = [...await all()]
      ..removeWhere((it) => it.id == write.id)
      ..add(write);
    await _save(writes);
  }

  @override
  Future<void> remove(String id) async {
    final writes = [...await all()]..removeWhere((it) => it.id == id);
    await _save(writes);
  }

  Future<void> _save(List<PendingWrite> writes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode([for (final write in writes) write.toJson()]),
    );
    _changes.add(null);
  }
}

/// A queue that forgets on restart. For tests, and for the web build, where
/// there is nothing durable to hold a photo alongside its entry anyway.
class InMemoryPendingWriteStore implements PendingWriteStore {
  final List<PendingWrite> _writes = [];
  final _changes = StreamController<void>.broadcast();

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Future<List<PendingWrite>> all() async => List.unmodifiable(_writes);

  @override
  Future<void> put(PendingWrite write) async {
    _writes
      ..removeWhere((it) => it.id == write.id)
      ..add(write);
    _changes.add(null);
  }

  @override
  Future<void> remove(String id) async {
    _writes.removeWhere((it) => it.id == id);
    _changes.add(null);
  }
}
