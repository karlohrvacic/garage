import '../../domain/maintenance/bundling.dart';
import '../../domain/maintenance/date_math.dart';
import '../../domain/maintenance/reminder_projection.dart';

/// One notification to be fired.
class ScheduledReminder {
  const ScheduledReminder({
    required this.id,
    required this.when,
    required this.serviceTypeKeys,
    required this.vehicleId,
    this.leadDays,
    this.remainingKm,
  });

  final int id;
  final DateTime when;
  final List<String> serviceTypeKeys;
  final String vehicleId;

  /// How far ahead of the due date this nudge is, for the ones the calendar
  /// produced. Null for a reminder raised by an odometer reading, which is
  /// not measured in days at all.
  final int? leadDays;

  /// How far the vehicle still has to run before the item comes due, for the
  /// ones a reading raised. Negative once it is past.
  final int? remainingKm;

  int get itemCount => serviceTypeKeys.length;
}

/// How far ahead of a due date reminders fire.
///
/// Two nudges, because one number was doing two jobs and failing the first.
/// Seven days claimed to be "enough notice to book a shop visit" and is not —
/// a service centre rarely has an appointment inside a week. A month is enough
/// to book one and too long to be remembered on its own, so both are sent:
/// **30 to arrange it, 7 to keep it.**
///
/// The server sends on exactly these days too, and
/// `test/ci/entry_kinds_wired_test.dart` fails if the two lists drift apart.
/// Ordered furthest-out first, which is also the order they fire in.
const List<int> notificationLeadDays = [30, 7];

/// The hour a scheduled reminder fires, local time.
///
/// Anything built from a date alone lands at midnight, which is how a
/// maintenance nudge ends up waking somebody at 00:00 for an oil change three
/// weeks away. Nine in the morning is close enough to when a shop could
/// actually be called.
const int notificationHour = 9;

/// How close by distance an item has to come before a reading is worth saying
/// anything about.
///
/// Roughly a tankful, and the same 500 km the bundling window uses for "near
/// enough to do in one visit". A distance rule reaches its odometer whenever
/// the car is driven, which the projected date only guesses at, so this is the
/// point where the guess stops mattering and the reading takes over.
const int notificationLeadKm = 500;

/// What makes two notifications the same notification.
///
/// Derived from the reminder itself — which car, which work, due when, and
/// which of the two nudges this is — rather than from the order things
/// happened to be planned in. Three consequences, all wanted: a resync
/// replaces the notification it already showed instead of numbering a new one;
/// a reminder that arrives as a push lands on the same id the device would
/// have used itself; and the month's notice and the week's notice stay two
/// notifications rather than the second quietly replacing the first while it
/// was still pending.
int notificationId({
  required String vehicleId,
  required Iterable<String> serviceTypeKeys,
  required DateTime dueDate,
  required int leadDays,
}) {
  final day = DateMath.dateOnly(dueDate);
  return _hash(
    '$vehicleId|${_sorted(serviceTypeKeys)}|'
    '${day.year}-${day.month}-${day.day}|${leadDays}d',
  );
}

/// The identity of a reminder raised by an odometer reading.
///
/// Keyed on the odometer it comes due at, not on the reading that revealed it
/// or on a projected date: every fill-up recomputes this, and an id that moved
/// with the reading would stack a fresh notification per fill-up instead of
/// updating the one already on screen.
int distanceNotificationId({
  required String vehicleId,
  required Iterable<String> serviceTypeKeys,
  required int dueOdometerKm,
}) {
  return _hash('$vehicleId|${_sorted(serviceTypeKeys)}|${dueOdometerKm}km');
}

String _sorted(Iterable<String> keys) => ([...keys]..sort()).join(',');

/// FNV-1a, masked to 31 bits: the notification plugin takes a 32-bit signed
/// int, and `Object.hash` is neither stable across runs nor bounded.
int _hash(String identity) {
  var hash = 0x811c9dc5;
  for (final unit in identity.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash & 0x7fffffff;
}

/// Turns due items into notifications.
///
/// A bundle becomes a single notification rather than one per item: the whole
/// point of bundling is to replace several scattered nudges with one, and
/// firing both would undo it.
List<ScheduledReminder> plan({
  required List<MaintenanceBundle> bundles,
  required List<ReminderProjection> loose,
  required DateTime today,
}) {
  final day = DateMath.dateOnly(today);
  final planned = <ScheduledReminder>[];
  final bundledRuleIds = <String>{};

  /// The lead days still ahead of us, or the shortest one if the item is
  /// already inside every window.
  ///
  /// A month's notice for something due in a fortnight would be a lie, and
  /// firing both leads at once is noise rather than notice — but an item that
  /// has missed all its windows still deserves the one nudge it can get.
  List<({int lead, DateTime when})> firings(DateTime dueDate) {
    // Calendar subtraction, not Duration subtraction: a lead window crossing
    // the spring-forward DST change would otherwise land at 23:00 a day early.
    DateTime fireAt(int lead) => DateTime(
      dueDate.year,
      dueDate.month,
      dueDate.day - lead,
      notificationHour,
    );

    final ahead = [
      for (final lead in notificationLeadDays)
        if (!DateMath.dateOnly(fireAt(lead)).isBefore(day))
          (lead: lead, when: fireAt(lead)),
    ];
    if (ahead.isNotEmpty) {
      return ahead;
    }
    return [
      (
        lead: notificationLeadDays.last,
        when: DateTime(day.year, day.month, day.day, notificationHour),
      ),
    ];
  }

  void add(String vehicleId, List<String> keys, DateTime dueDate) {
    for (final firing in firings(dueDate)) {
      planned.add(
        ScheduledReminder(
          id: notificationId(
            vehicleId: vehicleId,
            serviceTypeKeys: keys,
            dueDate: dueDate,
            leadDays: firing.lead,
          ),
          when: firing.when,
          serviceTypeKeys: keys,
          vehicleId: vehicleId,
          leadDays: firing.lead,
        ),
      );
    }
  }

  for (final bundle in bundles) {
    for (final item in bundle.items) {
      bundledRuleIds.add(item.projection.ruleId);
    }
    add(
      bundle.items.first.projection.vehicleId,
      bundle.items
          .map((item) => item.projection.serviceTypeKey)
          .toList(growable: false),
      bundle.visitDate,
    );
  }

  for (final projection in loose) {
    if (bundledRuleIds.contains(projection.ruleId)) {
      continue;
    }
    add(projection.vehicleId, [
      projection.serviceTypeKey,
    ], DateMath.dateOnly(projection.projectedDueDate));
  }

  return planned;
}

/// What a fresh odometer reading has just made true.
///
/// A rule with a distance interval comes due when the car reaches an odometer,
/// not when a calendar says so. The projector turns one into a date by
/// guessing a driving rate, and a household that drives more than the guess
/// arrives at the odometer well before the date does — which is precisely the
/// case where a week's notice becomes no notice.
///
/// So the moment a reading lands, anything now within [notificationLeadKm] is
/// said out loud, in kilometres, with no guessing involved. Items already past
/// their odometer are included: that is the most useful thing this can say.
///
/// [currentKm] is keyed by vehicle id. A vehicle with no reading yields
/// nothing rather than a guess.
List<ScheduledReminder> planByDistance({
  required List<ReminderProjection> projections,
  required Map<String, int> currentKm,
  required DateTime today,
}) {
  final planned = <ScheduledReminder>[];

  for (final projection in projections) {
    final dueKm = projection.dueOdometerKm;
    final current = currentKm[projection.vehicleId];
    if (dueKm == null || current == null) {
      continue;
    }
    final remaining = dueKm - current;
    if (remaining > notificationLeadKm) {
      continue;
    }
    final keys = [projection.serviceTypeKey];
    planned.add(
      ScheduledReminder(
        id: distanceNotificationId(
          vehicleId: projection.vehicleId,
          serviceTypeKeys: keys,
          dueOdometerKm: dueKm,
        ),
        // Now: this is a response to something that just happened, not a date
        // in the diary.
        when: today,
        serviceTypeKeys: keys,
        vehicleId: projection.vehicleId,
        remainingKm: remaining,
      ),
    );
  }

  return planned;
}
