import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/clock.dart';
import 'package:garage/core/notifications/notification_providers.dart';
import 'package:garage/core/notifications/notification_service.dart';
import 'package:garage/domain/maintenance/bundling.dart';
import 'package:garage/domain/maintenance/reminder_projection.dart';
import 'package:garage/features/dashboard/providers/dashboard_providers.dart';
import 'package:garage/features/maintenance/providers/maintenance_providers.dart';
import 'package:garage/features/vehicles/providers/vehicle_providers.dart';
import 'package:garage/l10n/app_localizations_en.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds the permission prompt open, which is what the system dialog does on
/// a first run.
class SlowPermission extends NotificationService {
  final permission = Completer<bool>();

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermission() => permission.future;

  @override
  Future<void> cancelAll() async {}
}

void main() {
  testWidgets('a sync survives the screen going away mid-prompt', (
    tester,
  ) async {
    // Seen on a device: the permission dialog on a first run holds this open
    // long enough for the dashboard to be rebuilt away, and the reads that
    // followed the await threw "Using ref when a widget has been unmounted".
    // Two unhandled exceptions at startup, and no notifications scheduled.
    final service = SlowPermission();
    late Future<void> sync;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationServiceProvider.overrideWithValue(service),
          allVehiclesProvider.overrideWith((ref) async => const []),
          householdProjectionsProvider.overrideWith((ref) async => const []),
          bundlesProvider.overrideWith((ref) async => const []),
          pushRemindersActiveProvider.overrideWithValue(false),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            sync = syncNotifications(ref, AppLocalizationsEn());
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    // The screen is replaced while the prompt is still up.
    await tester.pumpWidget(const SizedBox.shrink());
    service.permission.complete(true);

    await expectLater(sync, completes);
  });

  group('the app\'s own reminders', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    ReminderProjection oil(DateTime day, {int daysOut = 7}) =>
        ReminderProjection(
          ruleId: 'oil',
          vehicleId: 'v1',
          serviceTypeKey: 'service_oil_change',
          projectedDueDate: DateTime(day.year, day.month, day.day + daysOut),
          state: ReminderState.upcoming,
          dueOdometerKm: 58900,
        );
    final brake = ReminderProjection(
      ruleId: 'brake',
      vehicleId: 'v1',
      serviceTypeKey: 'service_brake_fluid',
      projectedDueDate: DateTime(2026, 9, 27),
      state: ReminderState.upcoming,
      dateFromTime: DateTime(2026, 9, 27),
    );

    testWidgets('a week\'s notice is given once, though its date moves daily', (
      tester,
    ) async {
      // A distance reminder's date is counted from today, so on a phone
      // opened every day it stayed seven days out, and every day it was due.
      final service = RecordingService();

      for (final day in [
        DateTime(2026, 9, 21),
        DateTime(2026, 9, 22),
        DateTime(2026, 9, 23),
      ]) {
        await syncOn(tester, service, day, [oil(day)]);
      }

      expect(service.shown, hasLength(1));
      expect(service.pending, isEmpty);
    });

    testWidgets('a moment already gone is shown, and the rest scheduled', (
      tester,
    ) async {
      // The plugin refuses to schedule a moment in the past, and "now" is in
      // the past by the time it checks: the overdue nudge threw, after every
      // notice had been cancelled, and nothing after it was scheduled.
      final service = RecordingService();
      final day = DateTime(2026, 9, 21);

      await syncOn(tester, service, day, [
        oil(day, daysOut: -5),
        brake.copyWithDue(DateTime(2026, 10, 31)),
      ]);

      expect(service.shown, hasLength(1));
      expect(service.pending, hasLength(2));
    });

    testWidgets('one notice refused costs only that notice', (tester) async {
      final service = RecordingService()..refuseNext = true;
      final day = DateTime(2026, 9, 21);

      await syncOn(tester, service, day, [
        oil(day, daysOut: 40),
        brake.copyWithDue(DateTime(2026, 10, 31)),
      ]);

      expect(service.pending, hasLength(3));
    });

    testWidgets('what was given together is not given again apart', (
      tester,
    ) async {
      // Brake fluid on a fixed date and oil on a drifting one bundle one day
      // and split the next, and a key made of the pair was new either side.
      final service = RecordingService();

      await syncOn(
        tester,
        service,
        DateTime(2026, 9, 21),
        [brake, oil(DateTime(2026, 9, 20))],
        bundles: [
          MaintenanceBundle([
            BundleItem(projection: brake, effectiveDate: DateTime(2026, 9, 27)),
            BundleItem(
              projection: oil(DateTime(2026, 9, 20)),
              effectiveDate: DateTime(2026, 9, 27),
            ),
          ]),
        ],
      );
      await syncOn(tester, service, DateTime(2026, 9, 22), [
        brake,
        oil(DateTime(2026, 9, 22)),
      ]);

      expect(service.shown, hasLength(1));
      expect(service.pending, isEmpty);
    });

    testWidgets('a month\'s notice is not given again when its date recedes', (
      tester,
    ) async {
      // The window passed, left the plan, and was forgotten the next day; a
      // distance date that then moved out brought the notice round again.
      final service = RecordingService();

      await syncOn(tester, service, DateTime(2026, 9, 21), [
        oil(DateTime(2026, 9, 21), daysOut: 30),
      ]);
      await syncOn(tester, service, DateTime(2026, 9, 22), [
        oil(DateTime(2026, 9, 22), daysOut: 20),
      ]);
      await syncOn(tester, service, DateTime(2026, 9, 25), [
        oil(DateTime(2026, 9, 25), daysOut: 40),
      ]);

      expect(service.shown, hasLength(1));
      expect(service.pending.values, isNot(contains(DateTime(2026, 10, 5, 9))));
    });

    testWidgets('a notice missed with notifications off is given once on', (
      tester,
    ) async {
      // A moment that passed while they were refused was counted as given,
      // and granting them afterwards never brought that notice back.
      final service = RecordingService()..permitted = false;

      await syncOn(tester, service, DateTime(2026, 9, 21), [
        oil(DateTime(2026, 9, 21)),
      ]);
      service.permitted = true;
      await syncOn(tester, service, DateTime(2026, 9, 22), [
        oil(DateTime(2026, 9, 22)),
      ]);

      expect(service.shown, hasLength(2));
    });
  });
}

/// Syncs as the dashboard does on [day] at ten in the morning, with
/// [projections] due and [bundles] made of them.
Future<void> syncOn(
  WidgetTester tester,
  RecordingService service,
  DateTime day,
  List<ReminderProjection> projections, {
  List<MaintenanceBundle> bundles = const [],
}) async {
  final now = DateTime(day.year, day.month, day.day, 10);
  service.now = () => now;
  late Future<void> sync;
  await tester.pumpWidget(
    ProviderScope(
      key: ValueKey(day),
      overrides: [
        notificationServiceProvider.overrideWithValue(service),
        allVehiclesProvider.overrideWith((ref) async => const []),
        householdProjectionsProvider.overrideWith((ref) async => projections),
        bundlesProvider.overrideWith((ref) async => bundles),
        pushRemindersActiveProvider.overrideWithValue(false),
        todayProvider.overrideWithValue(day),
        clockProvider.overrideWithValue(() => now),
      ],
      child: Consumer(
        builder: (context, ref, _) {
          // Once the projections are in, as the dashboard does it.
          if (ref.watch(householdProjectionsProvider).hasValue &&
              ref.watch(bundlesProvider).hasValue) {
            sync = syncNotifications(ref, AppLocalizationsEn());
          }
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.runAsync(() => sync);
}

extension on ReminderProjection {
  ReminderProjection copyWithDue(DateTime due) => ReminderProjection(
    ruleId: 'due-$due',
    vehicleId: vehicleId,
    serviceTypeKey: serviceTypeKey,
    projectedDueDate: due,
    state: state,
    dateFromTime: due,
  );
}

/// What would have reached the system's notification shade: shown at once,
/// or scheduled and not since cancelled.
///
/// Refuses a moment in the past as `flutter_local_notifications` does, with
/// "Must be a date in the future": a fake that took one was how a sync that
/// threw on every overdue item passed its test.
class RecordingService extends NotificationService {
  DateTime Function() now = DateTime.now;
  bool permitted = true;

  /// Fails the next schedule or show, as a plugin error would.
  bool refuseNext = false;

  final shown = <int>[];
  final pending = <int, DateTime>{};

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermission() async => permitted;

  @override
  Future<void> cancelAll() async => pending.clear();

  @override
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime when,
  }) async {
    if (refuseNext) {
      refuseNext = false;
      throw StateError('the plugin said no');
    }
    if (when.isBefore(now())) {
      throw ArgumentError.value(
        when,
        'scheduledDate',
        'Must be a date in the future',
      );
    }
    pending[id] = when;
  }

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
    bool onlyAlertOnce = false,
  }) async {
    if (refuseNext) {
      refuseNext = false;
      throw StateError('the plugin said no');
    }
    shown.add(id);
  }
}
