import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The things a person wants to remember before a long drive, beyond what the
/// garage's records know.
///
/// Kept on the device rather than in the database, and the screen says so.
/// "Take the roof box down" is a note to oneself; putting it in a shared
/// garage would make one person's packing list everybody's, and a table for it
/// is more schema than the thing deserves until somebody asks.
class TripChecklist extends AsyncNotifier<List<String>> {
  static String _key(String vehicleId) => 'trip_checklist_$vehicleId';

  late String _vehicleId;

  @override
  Future<List<String>> build() async => const [];

  Future<void> load(String vehicleId) async {
    _vehicleId = vehicleId;
    final prefs = await SharedPreferences.getInstance();
    state = AsyncValue.data(prefs.getStringList(_key(vehicleId)) ?? const []);
  }

  Future<void> add(String item) async {
    final trimmed = item.trim();
    if (trimmed.isEmpty) {
      return;
    }
    final next = [...state.value ?? const <String>[], trimmed];
    await _save(next);
  }

  Future<void> removeAt(int index) async {
    final current = [...state.value ?? const <String>[]];
    if (index < 0 || index >= current.length) {
      return;
    }
    current.removeAt(index);
    await _save(current);
  }

  Future<void> _save(List<String> items) async {
    state = AsyncValue.data(items);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key(_vehicleId), items);
  }
}

final tripChecklistProvider =
    AsyncNotifierProvider<TripChecklist, List<String>>(TripChecklist.new);
