import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/format/unit_format.dart';
import 'package:garage/domain/entities/reminder_rule.dart';
import 'package:garage/domain/entities/service_entry.dart';
import 'package:garage/features/maintenance/data/maintenance_repository.dart';
import 'package:garage/features/maintenance/providers/maintenance_providers.dart';
import 'package:garage/features/maintenance/widgets/service_entry_sheet.dart';
import 'package:garage/domain/entities/household.dart';
import 'package:garage/domain/maintenance/tracking_level.dart';
import 'package:garage/features/household/providers/household_providers.dart';
import 'package:garage/features/settings/providers/unit_providers.dart';
import 'package:garage/l10n/app_localizations.dart';

class FakeMaintenanceRepository implements MaintenanceRepository {
  FakeMaintenanceRepository(this.entries, {this.failDelete = false});

  List<ServiceEntry> entries;
  final bool failDelete;
  final List<String> calls = [];

  @override
  Future<List<ServiceType>> serviceTypes() async => const [
    ServiceType(key: 'service_oil_change'),
    ServiceType(key: 'service_brake_fluid'),
  ];

  @override
  Future<List<ReminderRule>> rulesForVehicle(String vehicleId) async =>
      const [];

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
  Future<void> addServiceEntry(ServiceEntry entry) async =>
      calls.add('add:${entry.serviceTypeKeys.join(",")}:${entry.odometerKm}');

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
}) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        maintenanceRepositoryProvider.overrideWithValue(repository),
        currentHouseholdProvider.overrideWith(
          (ref) async =>
              Household(id: 'h1', name: 'Test', trackingLevel: level.key),
        ),
        unitPreferencesProvider.overrideWithValue(
          const UnitPreferences(
            distance: DistanceUnit.km,
            volume: VolumeUnit.liter,
            currencyCode: 'EUR',
          ),
        ),
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

void main() {
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
      find.text('Something went wrong. Please try again.'),
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
}
