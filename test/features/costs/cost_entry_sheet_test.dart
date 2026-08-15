import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/format/unit_format.dart';
import 'package:garage/domain/entities/cost_entry.dart';
import 'package:garage/features/costs/data/cost_repository.dart';
import 'package:garage/features/costs/providers/cost_providers.dart';
import 'package:garage/domain/entities/reminder_rule.dart';
import 'package:garage/domain/entities/service_entry.dart';
import 'package:garage/features/costs/widgets/cost_entry_sheet.dart';
import 'package:garage/features/maintenance/data/maintenance_repository.dart';
import 'package:garage/features/maintenance/providers/maintenance_providers.dart';
import 'package:garage/features/settings/providers/unit_providers.dart';
import 'package:garage/l10n/app_localizations.dart';

class FakeCostRepository implements CostRepository {
  FakeCostRepository(this.entries, {this.failDelete = false});

  List<CostEntry> entries;
  final bool failDelete;
  final List<String> calls = [];

  @override
  Future<List<CostEntry>> forVehicle(String vehicleId) async => entries;

  @override
  Future<void> add(CostEntry entry) async =>
      calls.add('add:${entry.category}:${entry.amount}');

  @override
  Future<void> update(CostEntry entry) async => calls.add('update:${entry.id}');

  @override
  Future<void> delete(String id) async {
    calls.add('delete:$id');
    if (failDelete) {
      throw Exception('nope');
    }
    entries = entries.where((e) => e.id != id).toList();
  }
}

CostEntry cost({String id = 'c1', double amount = 120.5}) {
  return CostEntry(
    id: id,
    vehicleId: 'v1',
    date: DateTime.utc(2026, 6, 1),
    category: CostCategories.insurance,
    amount: amount,
    createdBy: 'u1',
  );
}

/// Records the reminder rules a saved cost asks for.
class RecordingMaintenanceRepository implements MaintenanceRepository {
  RecordingMaintenanceRepository({this.failUpsert = false});

  final bool failUpsert;
  final List<ReminderRule> upserted = [];

  @override
  Future<List<ServiceType>> serviceTypes() async => const [];

  @override
  Future<List<ReminderRule>> rulesForVehicle(String vehicleId) async =>
      const [];

  @override
  Future<List<ServiceEntry>> serviceEntriesForVehicle(String vehicleId) async =>
      const [];

  @override
  Future<void> upsertRule(ReminderRule rule) async {
    if (failUpsert) {
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
  Future<void> addServiceEntry(ServiceEntry entry) async {}

  @override
  Future<void> updateServiceEntry(ServiceEntry entry) async {}

  @override
  Future<void> deleteServiceEntry(String id) async {}
}

Future<void> pumpSheet(
  WidgetTester tester, {
  required FakeCostRepository repository,
  CostEntry? existing,
  RecordingMaintenanceRepository? maintenance,
}) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        costRepositoryProvider.overrideWithValue(repository),
        maintenanceRepositoryProvider.overrideWithValue(
          maintenance ?? RecordingMaintenanceRepository(),
        ),
        costEntriesProvider(
          'v1',
        ).overrideWith((ref) async => repository.entries),
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
          body: CostEntrySheet(vehicleId: 'v1', existing: existing),
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

void main() {
  testWidgets('a new entry offers no delete', (tester) async {
    await pumpSheet(tester, repository: FakeCostRepository([]));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(OutlinedButton, 'Delete'), findsNothing);
  });

  testWidgets('an existing entry prefills its amount', (tester) async {
    await pumpSheet(
      tester,
      repository: FakeCostRepository([cost()]),
      existing: cost(),
    );
    await tester.pumpAndSettle();

    expect(find.text('120.50'), findsOneWidget);
  });

  testWidgets('deleting asks first, then closes the sheet', (tester) async {
    final repository = FakeCostRepository([cost()]);
    await pumpSheet(tester, repository: repository, existing: cost());
    await tester.pumpAndSettle();

    await tapDelete(tester);

    expect(repository.calls, ['delete:c1']);
    expect(repository.entries, isEmpty);
  });

  testWidgets('a cancelled confirmation deletes nothing', (tester) async {
    final repository = FakeCostRepository([cost()]);
    await pumpSheet(tester, repository: repository, existing: cost());
    await tester.pumpAndSettle();

    final deleteButton = find.widgetWithText(OutlinedButton, 'Delete');
    await tester.ensureVisible(deleteButton);
    await tester.pumpAndSettle();
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(repository.calls, isEmpty);
    expect(find.byType(CostEntrySheet), findsOneWidget);
  });

  testWidgets('reports a refused delete instead of throwing', (tester) async {
    final repository = FakeCostRepository([cost()], failDelete: true);
    await pumpSheet(tester, repository: repository, existing: cost());
    await tester.pumpAndSettle();

    await tapDelete(tester);

    expect(
      find.text('Something went wrong. Please try again.'),
      findsOneWidget,
    );
    expect(find.byType(CostEntrySheet), findsOneWidget);
  });

  testWidgets('an amount that is not a number is refused', (tester) async {
    final repository = FakeCostRepository([]);
    await pumpSheet(tester, repository: repository);
    await tester.pumpAndSettle();

    final save = find.widgetWithText(FilledButton, 'Save');
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(repository.calls, isEmpty);
  });

  testWidgets('a comma decimal separator is accepted', (tester) async {
    final repository = FakeCostRepository([]);
    await pumpSheet(tester, repository: repository);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '99,90');
    final save = find.widgetWithText(FilledButton, 'Save');
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(repository.calls, ['add:${CostCategories.registration}:99.9']);
  });

  group('a recurring expense', () {
    Future<void> saveCost(WidgetTester tester, String category) async {
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(category).last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '320');
      final save = find.widgetWithText(FilledButton, 'Save');
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();
    }

    testWidgets('offers a reminder for insurance', (tester) async {
      await pumpSheet(tester, repository: FakeCostRepository([]));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Insurance').last);
      await tester.pumpAndSettle();

      expect(find.text('Remind me when it is due again'), findsOneWidget);
    });

    testWidgets('offers nothing for a car wash', (tester) async {
      await pumpSheet(tester, repository: FakeCostRepository([]));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Car wash').last);
      await tester.pumpAndSettle();

      expect(find.text('Remind me when it is due again'), findsNothing);
    });

    testWidgets('saving one creates the reminder a year out', (tester) async {
      final maintenance = RecordingMaintenanceRepository();
      await pumpSheet(
        tester,
        repository: FakeCostRepository([]),
        maintenance: maintenance,
      );
      await tester.pumpAndSettle();

      await saveCost(tester, 'Insurance');

      expect(maintenance.upserted, hasLength(1));
      final rule = maintenance.upserted.single;
      expect(rule.serviceTypeKey, 'service_insurance');
      expect(rule.oneTime, isTrue);
      expect(rule.dueDate!.year, DateTime.now().year + 1);
    });

    testWidgets('a wash creates no reminder', (tester) async {
      final maintenance = RecordingMaintenanceRepository();
      await pumpSheet(
        tester,
        repository: FakeCostRepository([]),
        maintenance: maintenance,
      );
      await tester.pumpAndSettle();

      await saveCost(tester, 'Car wash');

      expect(maintenance.upserted, isEmpty);
    });

    testWidgets('declining the reminder creates none', (tester) async {
      final maintenance = RecordingMaintenanceRepository();
      await pumpSheet(
        tester,
        repository: FakeCostRepository([]),
        maintenance: maintenance,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Insurance').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '320');
      final save = find.widgetWithText(FilledButton, 'Save');
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(maintenance.upserted, isEmpty);
    });
  });

  testWidgets('a reminder that cannot be created does not lose the cost', (
    tester,
  ) async {
    // The cost is the thing the user came to record; a reminder is a courtesy
    // on top. Failing the save would invite a retry and a duplicate entry.
    final repository = FakeCostRepository([]);
    await pumpSheet(
      tester,
      repository: repository,
      maintenance: RecordingMaintenanceRepository(failUpsert: true),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Insurance').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '320');
    final save = find.widgetWithText(FilledButton, 'Save');
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(repository.calls, ['add:${CostCategories.insurance}:320.0']);
    expect(find.text('Something went wrong. Please try again.'), findsNothing);
  });
}
