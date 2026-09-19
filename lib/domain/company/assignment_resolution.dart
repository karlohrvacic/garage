import '../entities/vehicle_assignment.dart';

/// Who was responsible for a car on a day, read off the assignment log.
///
/// The same rule as `driver_on()` in SQL (migration 0080), which the daily
/// push run and the console ask: the window that holds the day, both ends
/// inclusive. An entry on a day with no window belongs to nobody, and every
/// reader says so — an export prints a blank, a sheet says nobody was
/// assigned — rather than guessing at who typed it. Both sides answer to
/// `test/fixtures/assignment_resolution.json`.
abstract final class AssignmentResolution {
  /// The user id of whoever had the car on [on], or null for nobody.
  ///
  /// The first window that holds the day is the answer, as it is for the
  /// SQL's `limit 1`: the exclusion constraint leaves at most one, so the
  /// order the log arrived in does not matter. A window whose account was
  /// deleted holds the day and names nobody.
  static String? driverOn(
    Iterable<VehicleAssignment> assignments, {
    required String vehicleId,
    required DateTime on,
  }) {
    for (final assignment in assignments) {
      if (assignment.vehicleId == vehicleId && assignment.covers(on)) {
        return assignment.userId;
      }
    }
    return null;
  }

  /// The driver's name on [on], or an empty string.
  ///
  /// What an export cell, a report line and the data screen print, in one
  /// place so the three cannot disagree on what a missing driver looks
  /// like: nobody assigned, a deleted account, and a driver [names] no
  /// longer lists are all a blank. A window outlives the membership behind
  /// it, so the last of those is a real person the profiles policy no
  /// longer shows; a reader that would take a blank for "nobody" passes
  /// [former], the word it prints for them instead.
  static String driverOf(
    Iterable<VehicleAssignment> assignments, {
    required Map<String, String> names,
    required String vehicleId,
    required DateTime on,
    String former = '',
  }) {
    final id = driverOn(assignments, vehicleId: vehicleId, on: on);
    return id == null ? '' : names[id] ?? former;
  }

  /// The assignment a car is under today, for the grid's "current driver".
  static VehicleAssignment? openFor(
    Iterable<VehicleAssignment> assignments, {
    required String vehicleId,
    required DateTime today,
  }) {
    for (final assignment in assignments) {
      if (assignment.vehicleId == vehicleId && assignment.covers(today)) {
        return assignment;
      }
    }
    return null;
  }

  /// Every window a car has had, newest first.
  static List<VehicleAssignment> historyOf(
    Iterable<VehicleAssignment> assignments,
    String vehicleId,
  ) {
    return [
      for (final assignment in assignments)
        if (assignment.vehicleId == vehicleId) assignment,
    ]..sort((a, b) => b.fromDate.compareTo(a.fromDate));
  }
}
