import 'dart:typed_data';
import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/format/unit_format.dart';
import 'package:garage/core/errors/app_failure.dart';
import 'package:garage/domain/entities/reminder_rule.dart';
import 'package:garage/domain/entities/service_entry.dart';
import 'package:garage/domain/entities/vehicle.dart';
import 'package:garage/features/maintenance/data/maintenance_repository.dart';
import 'package:garage/features/maintenance/providers/maintenance_providers.dart';
import 'package:garage/features/maintenance/widgets/service_entry_sheet.dart';
import 'package:garage/domain/entities/household.dart';
import 'package:garage/domain/maintenance/tracking_level.dart';
import 'package:garage/features/household/providers/household_providers.dart';
import 'package:garage/core/files/file_picker.dart';
import 'package:garage/features/attachments/providers/attachment_providers.dart';
import 'package:garage/features/settings/providers/unit_providers.dart';
import 'package:garage/features/vehicles/providers/vehicle_providers.dart';
import 'package:garage/l10n/app_localizations.dart';
import 'package:riverpod/misc.dart';

import '../../support/fake_attachments.dart';
import '../../support/pump_screen.dart';

class FakeMaintenanceRepository implements MaintenanceRepository {
  FakeMaintenanceRepository(this.entries, {this.failDelete = false});

  List<ServiceEntry> entries;
  final bool failDelete;
  final List<String> calls = [];

  /// The entry as handed over, for fields `calls` does not spell out.
  final List<ServiceEntry> saved = [];

  @override
  Future<List<ServiceType>> serviceTypes() async => const [
    ServiceType(key: 'service_oil_change'),
    ServiceType(key: 'service_brake_fluid'),
    ServiceType(key: 'service_technical_inspection', isStatutory: true),
  ];

  /// What is standing on the vehicle. A paperwork reminder is offered as a
  /// chip so the visit that satisfies it can say so.
  List<ReminderRule> rules = const [];

  @override
  Future<List<ReminderRule>> rulesForVehicle(String vehicleId) async => rules;

  @override
  Future<List<ServiceEntry>> serviceEntriesForVehicle(String vehicleId) async =>
      entries;

  @override
  Future<void> upsertRule(ReminderRule rule) async {}

  @override
  Future<void> deleteRule(String id) async {}

  @override
  Future<void> completeOneTimeRules(
    String vehicleId,
    List<String> serviceTypeKeys,
  ) async => calls.add('completeOneTime:${serviceTypeKeys.join(",")}');

  @override
  Future<void> addServiceEntry(ServiceEntry entry) async {
    saved.add(entry);
    calls.add('add:${entry.serviceTypeKeys.join(",")}:${entry.odometerKm}');
  }

  @override
  Future<void> updateServiceEntry(ServiceEntry entry) async =>
      calls.add('update:${entry.id}');

  @override
  Future<void> deleteServiceEntry(String id) async {
    calls.add('delete:$id');
    if (failDelete) {
      throw Exception('nope');
    }
    entries = entries.where((e) => e.id != id).toList();
  }
}

ServiceEntry service({String id = 's1', int odometerKm = 120000}) {
  return ServiceEntry(
    id: id,
    vehicleId: 'v1',
    date: DateTime.utc(2026, 4, 2),
    odometerKm: odometerKm,
    serviceTypeKeys: const ['service_oil_change'],
    createdBy: 'u1',
    cost: 210.5,
  );
}

Future<void> pumpSheet(
  WidgetTester tester, {
  required FakeMaintenanceRepository repository,
  ServiceEntry? existing,
  TrackingLevel level = TrackingLevel.beginner,
  Vehicle? vehicle,
  List<Vehicle>? vehicles,

  /// What is already attached, and what the file picker hands back.
  FakeAttachmentRepository? attachments,
  XFile? pickedFile,

  /// Overrides applied after the defaults, so a test can make one of the
  /// sheet's fetches fail.
  List<Override> extraOverrides = const [],
}) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        maintenanceRepositoryProvider.overrideWithValue(repository),
        attachmentRepositoryProvider.overrideWithValue(
          attachments ?? FakeAttachmentRepository(),
        ),
        filePickerProvider.overrideWithValue(() async => pickedFile),
        currentHouseholdProvider.overrideWith(
          (ref) async =>
              Household(id: 'h1', name: 'Test', trackingLevel: level.key),
        ),
        if (vehicles == null)
          vehicleProvider('v1').overrideWith((ref) async => vehicle),
        for (final other in vehicles ?? const <Vehicle>[])
          vehicleProvider(other.id).overrideWith((ref) async => other),
        allVehiclesProvider.overrideWith((ref) async => vehicles ?? [?vehicle]),
        unitPreferencesProvider.overrideWithValue(
          const UnitPreferences(
            distance: DistanceUnit.km,
            volume: VolumeUnit.liter,
            currencyCode: 'EUR',
          ),
        ),
        ...extraOverrides,
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ServiceEntrySheet(vehicleId: 'v1', existing: existing),
        ),
      ),
    ),
  );
}

Future<void> tapDelete(WidgetTester tester) async {
  final deleteButton = find.widgetWithText(OutlinedButton, 'Delete');
  await tester.ensureVisible(deleteButton);
  await tester.pumpAndSettle();
  await tester.tap(deleteButton);
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
  await tester.pumpAndSettle();
}

Future<void> tapSave(WidgetTester tester) async {
  final save = find.widgetWithText(FilledButton, 'Save');
  await tester.ensureVisible(save);
  await tester.pumpAndSettle();
  await tester.tap(save);
  await tester.pumpAndSettle();
}

/// A catalogue with paperwork and an uncommon job before the common one.
class PaperworkMaintenanceRepository extends FakeMaintenanceRepository {
  PaperworkMaintenanceRepository() : super(const []);

  @override
  Future<List<ServiceType>> serviceTypes() async => const [
    ServiceType(key: 'service_brake_fluid'),
    ServiceType(key: 'service_registration', isStatutory: true),
    // Not flagged statutory in the catalogue, and still paperwork: cover
    // is optional, so the flag alone left these among the workshop jobs.
    ServiceType(key: 'service_insurance_comprehensive'),
    ServiceType(key: 'service_vignette'),
    ServiceType(key: 'service_oil_change'),
  ];
}

void main() {
  testWidgets('a statutory type already on an entry can be re-ticked', (
    tester,
  ) async {
    // Hidden from a new entry, it vanished from an old one the moment it was
    // unticked, and only discarding the sheet brought it back.
    await pumpSheet(
      tester,
      repository: PaperworkMaintenanceRepository(),
      existing: ServiceEntry(
        id: 's1',
        vehicleId: 'v1',
        date: DateTime.utc(2026, 8, 1),
        odometerKm: 50000,
        serviceTypeKeys: const ['service_registration'],
        createdBy: 'u1',
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Registration'));
    await tester.pumpAndSettle();
    expect(find.text('Registration'), findsOneWidget);
  });

  testWidgets('offers work, not paperwork, common jobs first', (tester) async {
    // Thirty chips in one weight with Insurance beside Oil change was a
    // wall; the cost sheet owns the paperwork and its reminders.
    await pumpSheet(tester, repository: PaperworkMaintenanceRepository());
    await tester.pumpAndSettle();

    expect(find.text('Registration'), findsNothing);
    expect(find.text('Comprehensive insurance'), findsNothing);
    expect(find.text('Vignette expires'), findsNothing);
    final oil = tester.getTopLeft(find.text('Oil change'));
    final brake = tester.getTopLeft(find.text('Brake fluid'));
    expect(
      oil.dy < brake.dy || (oil.dy == brake.dy && oil.dx < brake.dx),
      isTrue,
    );
  });

  testWidgets('a new entry offers no delete', (tester) async {
    await pumpSheet(tester, repository: FakeMaintenanceRepository([]));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(OutlinedButton, 'Delete'), findsNothing);
  });

  testWidgets('an existing entry prefills odometer and cost', (tester) async {
    await pumpSheet(
      tester,
      repository: FakeMaintenanceRepository([service()]),
      existing: service(),
    );
    await tester.pumpAndSettle();

    expect(find.text('120000'), findsOneWidget);
    expect(find.text('210.50'), findsOneWidget);
  });

  testWidgets('an existing entry keeps a chip for a type this fuel hides', (
    tester,
  ) async {
    // An oil change logged on a car recorded as electric. Without its chip
    // the item could never be deselected, and the entry would keep it
    // silently on every save.
    await pumpSheet(
      tester,
      repository: FakeMaintenanceRepository([service()]),
      existing: service(),
      vehicle: Vehicle(
        id: 'v1',
        householdId: 'h1',
        nickname: 'Car',
        fuelTypeKey: 'fuel_electric',
        baselineOdometerKm: 0,
        baselineDate: DateTime.utc(2026, 1, 1),
      ),
    );
    await tester.pumpAndSettle();

    final chip = find.widgetWithText(FilterChip, 'Oil change');
    expect(chip, findsOneWidget);
    expect(tester.widget<FilterChip>(chip).selected, isTrue);
  });

  testWidgets('deleting asks first, then removes the entry', (tester) async {
    final repository = FakeMaintenanceRepository([service()]);
    await pumpSheet(tester, repository: repository, existing: service());
    await tester.pumpAndSettle();

    await tapDelete(tester);

    expect(repository.calls, ['delete:s1']);
    expect(repository.entries, isEmpty);
  });

  testWidgets('a cancelled confirmation deletes nothing', (tester) async {
    final repository = FakeMaintenanceRepository([service()]);
    await pumpSheet(tester, repository: repository, existing: service());
    await tester.pumpAndSettle();

    final deleteButton = find.widgetWithText(OutlinedButton, 'Delete');
    await tester.ensureVisible(deleteButton);
    await tester.pumpAndSettle();
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(repository.calls, isEmpty);
    expect(find.byType(ServiceEntrySheet), findsOneWidget);
  });

  testWidgets('reports a refused delete instead of throwing', (tester) async {
    final repository = FakeMaintenanceRepository([service()], failDelete: true);
    await pumpSheet(tester, repository: repository, existing: service());
    await tester.pumpAndSettle();

    await tapDelete(tester);

    expect(
      find.textContaining('Something went wrong. Please try again.'),
      findsOneWidget,
    );
    expect(find.byType(ServiceEntrySheet), findsOneWidget);
  });

  testWidgets('saving without a service item selected is refused', (
    tester,
  ) async {
    final repository = FakeMaintenanceRepository([]);
    await pumpSheet(tester, repository: repository);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '150000');
    await tapSave(tester);

    expect(repository.calls, isEmpty);
  });

  testWidgets('saving without an odometer reading is refused', (tester) async {
    final repository = FakeMaintenanceRepository([]);
    await pumpSheet(tester, repository: repository);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilterChip, 'Oil change'));
    await tester.pumpAndSettle();
    await tapSave(tester);

    expect(repository.calls, isEmpty);
    expect(find.text('Enter the odometer reading'), findsOneWidget);
  });

  testWidgets('a saved service also completes matching one-off rules', (
    tester,
  ) async {
    final repository = FakeMaintenanceRepository([]);
    await pumpSheet(tester, repository: repository);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilterChip, 'Oil change'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '150000');
    await tapSave(tester);

    expect(repository.calls, [
      'add:service_oil_change:150000',
      'completeOneTime:service_oil_change',
    ]);
  });

  group('tracking depth', () {
    testWidgets('a basic household is asked for nothing extra', (tester) async {
      await pumpSheet(tester, repository: FakeMaintenanceRepository([]));
      await tester.pumpAndSettle();

      expect(find.text('Parts'), findsNothing);
      expect(find.text('Done at home'), findsNothing);
      expect(find.text('Readings'), findsNothing);
    });

    testWidgets('a detailed household is asked for parts and labour', (
      tester,
    ) async {
      await pumpSheet(
        tester,
        repository: FakeMaintenanceRepository([]),
        level: TrackingLevel.intermediate,
      );
      await tester.pumpAndSettle();

      expect(find.text('Parts'), findsOneWidget);
      expect(find.text('Labour'), findsOneWidget);
      expect(find.text('Done at home'), findsOneWidget);
      expect(find.text('Readings'), findsNothing);
    });

    testWidgets('a full household is asked for readings too', (tester) async {
      await pumpSheet(
        tester,
        repository: FakeMaintenanceRepository([]),
        level: TrackingLevel.advanced,
      );
      await tester.pumpAndSettle();

      expect(find.text('Readings'), findsOneWidget);
      expect(find.textContaining('Front brake pads'), findsOneWidget);
    });

    testWidgets('an existing entry shows the detail it carries', (
      tester,
    ) async {
      final entry = ServiceEntry(
        id: 's1',
        vehicleId: 'v1',
        date: DateTime.utc(2026, 4, 2),
        odometerKm: 120000,
        serviceTypeKeys: const ['service_oil_change'],
        createdBy: 'u1',
        cost: 210.5,
        diy: true,
        partsCost: 42.5,
        partsDetail: 'Castrol 5W-30',
        measurements: const {'brake_pad_front_mm': 6.5},
      );
      await pumpSheet(
        tester,
        repository: FakeMaintenanceRepository([entry]),
        existing: entry,
        level: TrackingLevel.advanced,
      );
      await tester.pumpAndSettle();

      expect(find.text('42.50'), findsOneWidget);
      expect(find.text('Castrol 5W-30'), findsOneWidget);
      expect(find.text('6.5'), findsOneWidget);
    });
  });

  group('the title says which it is', () {
    testWidgets('adding', (tester) async {
      await pumpSheet(tester, repository: FakeMaintenanceRepository([]));
      await tester.pumpAndSettle();

      expect(find.text('Log service'), findsOneWidget);
    });

    testWidgets('editing', (tester) async {
      await pumpSheet(
        tester,
        repository: FakeMaintenanceRepository([service()]),
        existing: service(),
      );
      await tester.pumpAndSettle();

      expect(find.text('Edit service'), findsOneWidget);
    });
  });

  testWidgets('the odometer and the cost say their units', (tester) async {
    await pumpSheet(tester, repository: FakeMaintenanceRepository([]));
    await tester.pumpAndSettle();

    expect(find.text('km'), findsOneWidget);
    expect(find.text('€'), findsWidgets);
  });

  group('the vehicle it is for', () {
    testWidgets('names the car the service lands on', (tester) async {
      await pumpSheet(
        tester,
        repository: FakeMaintenanceRepository([]),
        vehicles: [testVehicle('v1', nickname: 'Golf')],
      );
      await tester.pumpAndSettle();

      final row = find.byKey(const Key('sheet-vehicle'));
      expect(row, findsOneWidget);
      expect(find.descendant(of: row, matching: find.text('Golf')), findsOne);
    });

    testWidgets('a new service can be moved to the other car', (tester) async {
      // Two cars, one + button: the sheet gave no clue which one the oil
      // change was about to be recorded against.
      final repository = FakeMaintenanceRepository([]);
      await pumpSheet(
        tester,
        repository: repository,
        vehicles: [
          testVehicle('v1', nickname: 'Golf'),
          testVehicle('v2', nickname: 'Passat'),
        ],
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('sheet-vehicle')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Passat').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Oil change'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '130000');
      await tester.pumpAndSettle();
      await tapSave(tester);

      expect(repository.saved.single.vehicleId, 'v2');
    });
  });

  group('paperwork that is done, not paid', () {
    testWidgets('a standing technical-inspection reminder gets a chip', (
      tester,
    ) async {
      // Paperwork chips were dropped on the argument that the cost sheet
      // settles them. A technical inspection has no cost category at all, so
      // nothing could complete it and the reminder stood for ever.
      final repository = FakeMaintenanceRepository([])
        ..rules = const [
          ReminderRule(
            id: 'r1',
            vehicleId: 'v1',
            serviceTypeKey: 'service_technical_inspection',
            intervalMonths: 12,
          ),
        ];
      await pumpSheet(tester, repository: repository);
      await tester.pumpAndSettle();

      expect(find.text('Technical inspection'), findsOneWidget);
    });

    testWidgets('with nothing standing, paperwork stays off the chips', (
      tester,
    ) async {
      await pumpSheet(tester, repository: FakeMaintenanceRepository([]));
      await tester.pumpAndSettle();

      expect(find.text('Technical inspection'), findsNothing);
    });
  });

  group('a receipt on a service that is not saved yet', () {
    testWidgets('is deleted again when the sheet is abandoned', (tester) async {
      final attachments = FakeAttachmentRepository();
      await pumpSheet(
        tester,
        repository: FakeMaintenanceRepository([]),
        attachments: attachments,
        pickedFile: XFile.fromData(
          Uint8List.fromList([1, 2, 3]),
          name: 'receipt.jpg',
          mimeType: 'image/jpeg',
        ),
      );
      await tester.pumpAndSettle();

      final add = find.byTooltip('Attach a receipt or document');
      await tester.ensureVisible(add);
      await tester.pumpAndSettle();
      await tester.tap(add);
      await tester.pumpAndSettle();
      expect(attachments.stored, hasLength(1));

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();

      expect(attachments.stored, isEmpty);
    });

    testWidgets('is kept once the service is saved', (tester) async {
      final attachments = FakeAttachmentRepository();
      await pumpSheet(
        tester,
        repository: FakeMaintenanceRepository([]),
        attachments: attachments,
        pickedFile: XFile.fromData(
          Uint8List.fromList([1, 2, 3]),
          name: 'receipt.jpg',
          mimeType: 'image/jpeg',
        ),
      );
      await tester.pumpAndSettle();

      final add = find.byTooltip('Attach a receipt or document');
      await tester.ensureVisible(add);
      await tester.pumpAndSettle();
      await tester.tap(add);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Oil change'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '130000');
      await tester.pumpAndSettle();
      await tapSave(tester);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();

      expect(attachments.stored, hasLength(1));
    });
  });

  testWidgets('a catalogue that fails to load says so, instead of no chips', (
    tester,
  ) async {
    // The chips came from `.value ?? []`, so a failed fetch of the household,
    // the catalogue or the vehicle showed an empty item list with nothing to
    // read: indistinguishable from a car with no services to offer.
    await pumpSheet(
      tester,
      repository: FakeMaintenanceRepository(const []),
      extraOverrides: [
        availableServiceTypesProvider('v1').overrideWith(
          (ref) async => throw const AppFailure(kind: AppFailureKind.network),
        ),
      ],
    );
    await tester.pumpAndSettle();

    final items = find.text('What was done');
    await tester.ensureVisible(items);
    await tester.pumpAndSettle();

    expect(find.textContaining('No connection'), findsOneWidget);
    expect(find.byType(FilterChip), findsNothing);
  });

  group('a service that repeats one already logged', () {
    DateTime todayUtc() {
      final now = DateTime.now();
      return DateTime.utc(now.year, now.month, now.day);
    }

    ServiceEntry loggedToday() => ServiceEntry(
      id: 's9',
      vehicleId: 'v1',
      date: todayUtc(),
      odometerKm: 120000,
      serviceTypeKeys: const ['service_oil_change'],
      createdBy: 'u1',
    );

    testWidgets('says so once the same job and odometer are entered', (
      tester,
    ) async {
      final repository = FakeMaintenanceRepository([loggedToday()]);
      await pumpSheet(tester, repository: repository);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('service-odometer')),
        '120000',
      );
      await tester.pumpAndSettle();
      final chip = find.widgetWithText(FilterChip, 'Oil change');
      await tester.ensureVisible(chip);
      await tester.pumpAndSettle();
      await tester.tap(chip);
      await tester.pumpAndSettle();

      expect(find.textContaining('already logged'), findsOneWidget);
    });

    testWidgets('and stays quiet at a different odometer', (tester) async {
      final repository = FakeMaintenanceRepository([loggedToday()]);
      await pumpSheet(tester, repository: repository);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('service-odometer')),
        '124000',
      );
      await tester.pumpAndSettle();
      final chip = find.widgetWithText(FilterChip, 'Oil change');
      await tester.ensureVisible(chip);
      await tester.pumpAndSettle();
      await tester.tap(chip);
      await tester.pumpAndSettle();

      expect(find.textContaining('already logged'), findsNothing);
    });

    testWidgets('and never refuses the save', (tester) async {
      final repository = FakeMaintenanceRepository([loggedToday()]);
      await pumpSheet(tester, repository: repository);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('service-odometer')),
        '120000',
      );
      await tester.pumpAndSettle();
      final chip = find.widgetWithText(FilterChip, 'Oil change');
      await tester.ensureVisible(chip);
      await tester.pumpAndSettle();
      await tester.tap(chip);
      await tester.pumpAndSettle();
      await tapSave(tester);

      expect(repository.calls, contains('add:service_oil_change:120000'));
    });
  });
}
