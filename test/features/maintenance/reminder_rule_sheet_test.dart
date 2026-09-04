import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/format/unit_format.dart';
import 'package:garage/features/settings/providers/unit_providers.dart';
import 'package:garage/domain/entities/reminder_rule.dart';
import 'package:garage/domain/entities/service_entry.dart';
import 'package:garage/domain/entities/vehicle.dart';
import 'package:garage/features/maintenance/data/maintenance_repository.dart';
import 'package:garage/features/maintenance/providers/maintenance_providers.dart';
import 'package:garage/features/maintenance/widgets/reminder_rule_sheet.dart';
import 'package:garage/features/vehicles/providers/vehicle_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/domain/entities/household.dart';
import 'package:garage/features/household/providers/household_providers.dart';
import 'package:garage/l10n/app_localizations.dart';
import '../../support/pump_screen.dart';

class RecordingMaintenanceRepository implements MaintenanceRepository {
  RecordingMaintenanceRepository({this.fails = false});

  final bool fails;
  final List<ReminderRule> upserted = [];
  final List<ServiceEntry> services = [];

  @override
  Future<List<ServiceType>> serviceTypes() async => const [
    ServiceType(
      key: 'service_oil_change',
      defaultIntervalKm: 15000,
      defaultIntervalMonths: 12,
    ),
    ServiceType(
      key: 'service_timing_belt',
      defaultIntervalKm: 120000,
      defaultIntervalMonths: 72,
    ),
    ServiceType(key: 'service_registration', isStatutory: true),
  ];

  @override
  Future<List<ReminderRule>> rulesForVehicle(String vehicleId) async =>
      const [];

  @override
  Future<List<ServiceEntry>> serviceEntriesForVehicle(String vehicleId) async =>
      const [];

  @override
  Future<void> upsertRule(ReminderRule rule) async {
    if (fails) {
      throw Exception('nope');
    }
    upserted.add(rule);
  }

  @override
  Future<void> deleteRule(String id) async {}

  @override
  Future<void> completeOneTimeRules(
    String vehicleId,
    List<String> serviceTypeKeys,
  ) async {}

  @override
  Future<void> addServiceEntry(ServiceEntry entry) async => services.add(entry);

  @override
  Future<void> updateServiceEntry(ServiceEntry entry) async {}

  @override
  Future<void> deleteServiceEntry(String id) async {}
}

/// The sheet is pumped behind a page that can pop it, because saving pops —
/// a sheet pumped as the only route would assert instead.
/// A catalogue that arrives only when the test says so.
class LateMaintenanceRepository extends RecordingMaintenanceRepository {
  final _catalogue = Completer<List<ServiceType>>();

  void release() => _catalogue.complete(const [
    ServiceType(key: 'service_oil_change', defaultIntervalKm: 15000),
  ]);

  @override
  Future<List<ServiceType>> serviceTypes() => _catalogue.future;
}

/// The catalogue with the two types that are logged, not scheduled.
class OneOffMaintenanceRepository extends RecordingMaintenanceRepository {
  @override
  Future<List<ServiceType>> serviceTypes() async => const [
    ServiceType(key: 'service_oil_change', defaultIntervalKm: 15000),
    ServiceType(key: 'service_issue'),
    ServiceType(key: 'service_modification'),
  ];
}

Future<void> pumpSheet(
  WidgetTester tester,
  RecordingMaintenanceRepository repository, {
  List<ServiceEntry> serviceEntries = const [],
  ReminderRule? existing,
  Vehicle? vehicle,

  /// The garage's cars, when the test needs more than the one the sheet is
  /// for. Each is served by its own [vehicleProvider].
  List<Vehicle> vehicles = const [],
  UnitPreferences? preferences,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(420, 1000);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        maintenanceRepositoryProvider.overrideWithValue(repository),
        serviceEntriesProvider(
          'v1',
        ).overrideWith((ref) async => serviceEntries),
        currentHouseholdProvider.overrideWith(
          (ref) async => const Household(id: 'h1', name: 'Test'),
        ),
        vehicleProvider('v1').overrideWith((ref) async => vehicle),
        for (final other in vehicles)
          if (other.id != 'v1')
            vehicleProvider(other.id).overrideWith((ref) async => other),
        vehiclesProvider.overrideWith(
          (ref) async => vehicles.isEmpty ? [?vehicle] : vehicles,
        ),
        if (preferences != null)
          unitPreferencesProvider.overrideWithValue(preferences),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Navigator(
              onGenerateRoute: (_) => MaterialPageRoute<void>(
                builder: (_) =>
                    ReminderRuleSheet(vehicleId: 'v1', existing: existing),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> pickServiceType(WidgetTester tester, String label) async {
  await tester.tap(find.byKey(const Key('rule-service-type')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Future<void> tapSave(WidgetTester tester) async {
  final save = find.widgetWithText(FilledButton, 'Save');
  await tester.ensureVisible(save);
  await tester.pumpAndSettle();
  await tester.tap(save);
  await tester.pumpAndSettle();
}

ReminderRule rule({
  int? intervalKm = 15000,
  int? intervalMonths = 12,
  bool oneTime = false,
  DateTime? dueDate,
  int? dueOdometerKm,
}) {
  return ReminderRule(
    id: 'r1',
    vehicleId: 'v1',
    serviceTypeKey: 'service_oil_change',
    intervalKm: intervalKm,
    intervalMonths: intervalMonths,
    oneTime: oneTime,
    dueDate: dueDate,
    dueOdometerKm: dueOdometerKm,
  );
}

Vehicle car({String? make, String? timingDrive, String fuel = 'fuel_petrol'}) {
  return Vehicle(
    id: 'v1',
    householdId: 'h1',
    nickname: 'Car',
    fuelTypeKey: fuel,
    baselineOdometerKm: 0,
    baselineDate: DateTime.utc(2026, 1, 1),
    make: make,
    timingDrive: timingDrive,
  );
}

void main() {
  group('the service-type picker', () {
    testWidgets('fills in when the catalogue lands, not when it opened', (
      tester,
    ) async {
      // Opened a second after the sheet on a cold load, the picker showed
      // "Nothing matches" under an empty search and stayed that way: it
      // had copied the list before the catalogue arrived.
      final repository = LateMaintenanceRepository();
      await pumpSheet(tester, repository);
      await tester.pump();

      await tester.tap(find.byKey(const Key('rule-service-type')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Nothing matches'), findsNothing);

      repository.release();
      await tester.pumpAndSettle();
      expect(find.text('Oil change'), findsOneWidget);
    });

    testWidgets('leads with the common items and can be searched', (
      tester,
    ) async {
      // A flat alphabetical menu of thirty put "Oil change" seventeenth,
      // on the third thing a new user does.
      await pumpSheet(tester, RecordingMaintenanceRepository());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('rule-service-type')));
      await tester.pumpAndSettle();
      expect(find.text('COMMON'), findsOneWidget);
      expect(find.text('EVERYTHING ELSE'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('service-type-search')),
        'timing',
      );
      await tester.pumpAndSettle();
      expect(find.text('Timing belt'), findsOneWidget);
      expect(find.text('Oil change'), findsNothing);

      await tester.tap(find.text('Timing belt'));
      await tester.pumpAndSettle();
      expect(find.text('Timing belt'), findsOneWidget);
    });

    testWidgets('does not offer what nobody schedules', (tester) async {
      await pumpSheet(tester, OneOffMaintenanceRepository());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('rule-service-type')));
      await tester.pumpAndSettle();
      expect(find.text('Oil change'), findsOneWidget);
      expect(find.text('Fault noted'), findsNothing);
      expect(find.text('Modification'), findsNothing);
    });

    testWidgets('still shows a saved rule of such a type', (tester) async {
      // Hidden from the menu is not the same as unopenable: a rule made
      // before the change must still be editable.
      await pumpSheet(
        tester,
        OneOffMaintenanceRepository(),
        existing: ReminderRule(
          id: 'r1',
          vehicleId: 'v1',
          serviceTypeKey: 'service_issue',
          intervalKm: null,
          intervalMonths: 6,
          oneTime: false,
          active: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Fault noted'), findsOneWidget);
    });
  });

  testWidgets('moving a new rule to another car re-resolves its defaults', (
    tester,
  ) async {
    // The first car's make-aware interval stayed in the boxes after the
    // switch, with the note that explained it gone, so 15 000 km from one
    // catalogue looked typed and saved against a car whose own answer is
    // 25 000.
    final golf = car(make: 'Volkswagen');
    final astra = Vehicle(
      id: 'v2',
      householdId: 'h1',
      nickname: 'Astra',
      fuelTypeKey: 'fuel_petrol',
      baselineOdometerKm: 0,
      baselineDate: DateTime.utc(2026, 1, 1),
      make: 'Opel',
    );
    await pumpSheet(
      tester,
      RecordingMaintenanceRepository(),
      vehicle: golf,
      vehicles: [golf, astra],
    );
    await tester.pumpAndSettle();
    await pickServiceType(tester, 'Oil change');
    expect(find.text('15000'), findsOneWidget);

    await tester.tap(find.byKey(const Key('sheet-vehicle')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Astra').last);
    await tester.pumpAndSettle();

    expect(find.text('25000'), findsOneWidget);
    expect(find.text('15000'), findsNothing);
  });

  testWidgets('takes "last done" from a service already logged', (
    tester,
  ) async {
    // The sheet asked for a date the app already knew: the Reminders tab
    // prints "Previously: …" two rows below.
    final repository = RecordingMaintenanceRepository();
    await pumpSheet(
      tester,
      repository,
      vehicle: car(),
      serviceEntries: [
        ServiceEntry(
          id: 's1',
          vehicleId: 'v1',
          date: DateTime.utc(2026, 8, 10),
          odometerKm: 120400,
          serviceTypeKeys: const ['service_oil_change'],
          createdBy: 'u1',
        ),
      ],
    );
    await tester.pumpAndSettle();
    await pickServiceType(tester, 'Oil change');

    expect(find.text('120400'), findsOneWidget);
    expect(find.textContaining('service you logged'), findsOneWidget);
  });

  testWidgets('names the vehicle the rule is for', (tester) async {
    await pumpSheet(
      tester,
      RecordingMaintenanceRepository(),
      vehicle: testVehicle('v1', nickname: 'Golf'),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const Key('sheet-vehicle')),
        matching: find.text('Golf'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('an unset date asks for one rather than reporting nothing', (
    tester,
  ) async {
    // "Nothing here yet" is the empty-list line; under a date it read as a
    // missing value the app was waiting on.
    await pumpSheet(tester, RecordingMaintenanceRepository());
    await tester.pumpAndSettle();

    final date = find.byKey(const Key('rule-last-done-date'));
    await tester.ensureVisible(date);
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: date, matching: find.text('Pick a date')),
      findsOneWidget,
    );
    expect(find.text('Nothing here yet'), findsNothing);
  });

  testWidgets('picking a service type fills in its preset intervals', (
    tester,
  ) async {
    final repository = RecordingMaintenanceRepository();
    await pumpSheet(tester, repository);
    await tester.pumpAndSettle();

    await pickServiceType(tester, 'Oil change');

    expect(find.text('15000'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
  });

  testWidgets('a recurring rule saves its intervals', (tester) async {
    final repository = RecordingMaintenanceRepository();
    await pumpSheet(tester, repository);
    await tester.pumpAndSettle();

    await pickServiceType(tester, 'Oil change');
    await tapSave(tester);

    expect(repository.upserted.single.serviceTypeKey, 'service_oil_change');
    expect(repository.upserted.single.intervalKm, 15000);
    expect(repository.upserted.single.intervalMonths, 12);
    expect(repository.upserted.single.oneTime, isFalse);
  });

  testWidgets('a rule with no interval at all is refused', (tester) async {
    final repository = RecordingMaintenanceRepository();
    await pumpSheet(tester, repository);
    await tester.pumpAndSettle();

    await pickServiceType(tester, 'Registration');
    await tapSave(tester);

    expect(repository.upserted, isEmpty);
    expect(find.text('Set a distance or a time interval'), findsOneWidget);
  });

  testWidgets('saving without a service type does nothing', (tester) async {
    final repository = RecordingMaintenanceRepository();
    await pumpSheet(tester, repository);
    await tester.pumpAndSettle();

    await tapSave(tester);

    expect(repository.upserted, isEmpty);
  });

  testWidgets('a one-off rule needs a date or an odometer target', (
    tester,
  ) async {
    final repository = RecordingMaintenanceRepository();
    await pumpSheet(tester, repository);
    await tester.pumpAndSettle();

    await pickServiceType(tester, 'Registration');
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    await tapSave(tester);

    expect(repository.upserted, isEmpty);
    expect(find.textContaining('Set a due date or odometer'), findsOneWidget);
  });

  testWidgets('a one-off rule with an odometer target saves', (tester) async {
    final repository = RecordingMaintenanceRepository();
    await pumpSheet(tester, repository);
    await tester.pumpAndSettle();

    await pickServiceType(tester, 'Registration');
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '60000');
    await tapSave(tester);

    expect(repository.upserted.single.oneTime, isTrue);
    // Its own id, so a save retried after a timeout is the same rule.
    expect(repository.upserted.single.id, isNotEmpty);
    expect(repository.upserted.single.dueOdometerKm, 60000);
    expect(repository.upserted.single.intervalKm, isNull);
  });

  testWidgets('an existing rule prefills its intervals', (tester) async {
    final repository = RecordingMaintenanceRepository();
    await pumpSheet(tester, repository, existing: rule(intervalKm: 20000));
    await tester.pumpAndSettle();

    expect(find.text('20000'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
  });

  testWidgets('an existing rule keeps its id when saved', (tester) async {
    final repository = RecordingMaintenanceRepository();
    await pumpSheet(tester, repository, existing: rule());
    await tester.pumpAndSettle();

    await tapSave(tester);

    expect(repository.upserted.single.id, 'r1');
  });

  testWidgets('an existing rule on a type this fuel hides still opens', (
    tester,
  ) async {
    // A car recorded as electric with an oil-change rule, or one whose fuel
    // was corrected after its rules were made. The picker must still show
    // the rule's own type, or the sheet asserts and the rule cannot be
    // edited at all.
    await pumpSheet(
      tester,
      RecordingMaintenanceRepository(),
      existing: rule(),
      vehicle: car(fuel: 'fuel_electric'),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Oil change'), findsOneWidget);
  });

  testWidgets('a refused save is reported in the sheet', (tester) async {
    final repository = RecordingMaintenanceRepository(fails: true);
    await pumpSheet(tester, repository, existing: rule());
    await tester.pumpAndSettle();

    await tapSave(tester);

    expect(
      find.textContaining('Something went wrong. Please try again.'),
      findsOneWidget,
    );
  });

  group('recording what was already done', () {
    // A rule for something serviced last month projected from the vehicle
    // baseline, so it read as long overdue. Rather than storing an anchor on
    // the rule, which would be a second version of history able to contradict
    // it, the sheet logs the service that actually happened.
    testWidgets('an interval can start from the service you already did', (
      tester,
    ) async {
      final repository = RecordingMaintenanceRepository();
      await pumpSheet(tester, repository);
      await tester.pumpAndSettle();

      await pickServiceType(tester, 'Oil change');
      await tester.enterText(
        find.byKey(const Key('rule-last-done-km')),
        '42000',
      );
      await tapSave(tester);

      expect(
        repository.services,
        hasLength(1),
        reason: 'the service is history, and history is what projections read',
      );
      expect(repository.services.single.odometerKm, 42000);
      expect(repository.services.single.serviceTypeKeys, [
        'service_oil_change',
      ]);
      expect(repository.upserted, hasLength(1));
    });

    testWidgets('leaving it blank logs no service', (tester) async {
      final repository = RecordingMaintenanceRepository();
      await pumpSheet(tester, repository);
      await tester.pumpAndSettle();

      await pickServiceType(tester, 'Oil change');
      await tapSave(tester);

      expect(repository.services, isEmpty);
      expect(repository.upserted, hasLength(1));
    });
  });

  group('where a default comes from', () {
    testWidgets('a Mazda starts oil at 20,000 / 12 and says why', (
      tester,
    ) async {
      await pumpSheet(
        tester,
        RecordingMaintenanceRepository(),
        vehicle: car(make: 'Mazda'),
      );
      await tester.pumpAndSettle();

      await pickServiceType(tester, 'Oil change');

      expect(find.text('20000'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(
        find.text('Typical for Mazda — confirm in your service book'),
        findsOneWidget,
      );
    });

    testWidgets('the make is shown as typed, not as its key', (tester) async {
      await pumpSheet(
        tester,
        RecordingMaintenanceRepository(),
        vehicle: car(make: 'VW'),
      );
      await tester.pumpAndSettle();

      await pickServiceType(tester, 'Oil change');

      expect(find.textContaining('Typical for VW'), findsOneWidget);
    });

    testWidgets('a chain fills nothing for a timing belt and says so', (
      tester,
    ) async {
      await pumpSheet(
        tester,
        RecordingMaintenanceRepository(),
        vehicle: car(timingDrive: 'chain'),
      );
      await tester.pumpAndSettle();

      await pickServiceType(tester, 'Timing belt');

      expect(find.text('120000'), findsNothing);
      expect(
        find.text('This engine has a timing chain, so no interval is needed'),
        findsOneWidget,
      );
    });

    testWidgets('an unset timing drive keeps the preset and asks for it', (
      tester,
    ) async {
      await pumpSheet(tester, RecordingMaintenanceRepository(), vehicle: car());
      await tester.pumpAndSettle();

      await pickServiceType(tester, 'Timing belt');

      expect(find.text('120000'), findsOneWidget);
      expect(
        find.text('Set the timing drive on the vehicle for a better default'),
        findsOneWidget,
      );
    });

    testWidgets('an unknown make is generic and says nothing', (tester) async {
      await pumpSheet(
        tester,
        RecordingMaintenanceRepository(),
        vehicle: car(make: 'Geely'),
      );
      await tester.pumpAndSettle();

      await pickServiceType(tester, 'Oil change');

      expect(find.text('15000'), findsOneWidget);
      expect(find.textContaining('Typical for'), findsNothing);
    });

    testWidgets('with no vehicle loaded the preset applies as before', (
      tester,
    ) async {
      // vehicle: null — the provider resolves to nothing, which is the case
      // on a screen that opened the sheet before the car arrived.
      await pumpSheet(tester, RecordingMaintenanceRepository());
      await tester.pumpAndSettle();

      await pickServiceType(tester, 'Oil change');

      expect(find.text('15000'), findsOneWidget);
    });

    testWidgets('editing an interval drops the note', (tester) async {
      await pumpSheet(
        tester,
        RecordingMaintenanceRepository(),
        vehicle: car(make: 'Mazda'),
      );
      await tester.pumpAndSettle();
      await pickServiceType(tester, 'Oil change');
      expect(find.byKey(const Key('rule-default-note')), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, '18000');
      await tester.pump();

      expect(find.byKey(const Key('rule-default-note')), findsNothing);
    });

    testWidgets('an existing rule shows no note', (tester) async {
      await pumpSheet(
        tester,
        RecordingMaintenanceRepository(),
        existing: rule(intervalKm: 20000, intervalMonths: 12),
        vehicle: car(make: 'Mazda'),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('rule-default-note')), findsNothing);
    });
  });

  testWidgets('distance fields say their unit', (tester) async {
    await pumpSheet(tester, RecordingMaintenanceRepository());
    await tester.pumpAndSettle();

    // The interval and the last-done odometer, both in the household's unit.
    expect(find.text('km'), findsNWidgets(2));
  });

  group('a household that reads miles', () {
    // The three km fields showed and stored kilometres whatever the
    // household read, which the new "mi" suffix made a visible lie.
    const imperial = UnitPreferences(
      distance: DistanceUnit.mi,
      volume: VolumeUnit.usGallon,
      currencyCode: 'USD',
    );

    testWidgets('sees an existing interval in miles and saves it back in km', (
      tester,
    ) async {
      final repository = RecordingMaintenanceRepository();
      await pumpSheet(
        tester,
        repository,
        existing: rule(intervalKm: 16093, intervalMonths: 12),
        preferences: imperial,
      );
      await tester.pumpAndSettle();

      expect(find.text('10000'), findsOneWidget);
      expect(find.text('mi'), findsNWidgets(2));

      await tapSave(tester);

      expect(repository.upserted.single.intervalKm, 16093);
    });

    testWidgets('a typed interval is stored in kilometres', (tester) async {
      final repository = RecordingMaintenanceRepository();
      await pumpSheet(tester, repository, preferences: imperial);
      await tester.pumpAndSettle();

      await pickServiceType(tester, 'Oil change');
      await tester.enterText(find.byType(TextField).first, '100');
      await tapSave(tester);

      expect(repository.upserted.single.intervalKm, 161);
    });

    testWidgets('a preset is shown in miles', (tester) async {
      await pumpSheet(
        tester,
        RecordingMaintenanceRepository(),
        preferences: imperial,
      );
      await tester.pumpAndSettle();

      await pickServiceType(tester, 'Oil change');

      expect(find.text('9321'), findsOneWidget);
    });
  });

  testWidgets('saving says what was set', (tester) async {
    // The sheet closed silently and the planner said "Nothing due" for a
    // rule a year out, which read as a failed save.
    final repository = RecordingMaintenanceRepository();
    await pumpSheet(tester, repository);
    await tester.pumpAndSettle();

    await pickServiceType(tester, 'Oil change');
    await tapSave(tester);

    expect(find.text('Reminder set: Oil change'), findsOneWidget);
  });

  testWidgets('an overdue reminder can still open its date picker', (
    tester,
  ) async {
    // The picker's floor was today while its initial date came off the rule,
    // so any reminder already past its date asserted on open.
    final repository = RecordingMaintenanceRepository();
    await pumpSheet(
      tester,
      repository,
      existing: rule(
        intervalKm: null,
        intervalMonths: null,
        oneTime: true,
        dueDate: DateTime.utc(2020, 5, 1),
      ),
    );
    await tester.pumpAndSettle();

    final due = find.widgetWithText(ListTile, 'Due date');
    await tester.ensureVisible(due);
    await tester.pumpAndSettle();
    await tester.tap(due);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(DatePickerDialog), findsOneWidget);
  });
}
