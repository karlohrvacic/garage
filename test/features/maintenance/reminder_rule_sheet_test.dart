import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/entities/reminder_rule.dart';
import 'package:garage/domain/entities/service_entry.dart';
import 'package:garage/features/maintenance/data/maintenance_repository.dart';
import 'package:garage/features/maintenance/providers/maintenance_providers.dart';
import 'package:garage/features/maintenance/widgets/reminder_rule_sheet.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/domain/entities/household.dart';
import 'package:garage/features/household/providers/household_providers.dart';
import 'package:garage/l10n/app_localizations.dart';

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
Future<void> pumpSheet(
  WidgetTester tester,
  RecordingMaintenanceRepository repository, {
  ReminderRule? existing,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(420, 1000);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        maintenanceRepositoryProvider.overrideWithValue(repository),
        currentHouseholdProvider.overrideWith(
          (ref) async => const Household(id: 'h1', name: 'Test'),
        ),
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
  await tester.tap(find.byType(DropdownButtonFormField<String>));
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

void main() {
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

  testWidgets('a refused save is reported in the sheet', (tester) async {
    final repository = RecordingMaintenanceRepository(fails: true);
    await pumpSheet(tester, repository, existing: rule());
    await tester.pumpAndSettle();

    await tapSave(tester);

    expect(
      find.text('Something went wrong. Please try again.'),
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
}
