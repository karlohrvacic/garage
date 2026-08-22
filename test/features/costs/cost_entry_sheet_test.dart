import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/format/unit_format.dart';
import 'package:garage/domain/entities/cost_entry.dart';
import 'package:garage/features/costs/data/cost_repository.dart';
import 'package:garage/features/costs/providers/cost_providers.dart';
import 'package:garage/domain/entities/reminder_rule.dart';
import 'package:garage/domain/entities/service_entry.dart';
import 'package:garage/domain/maintenance/recurring_costs.dart';
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

  /// The entry as it was actually handed to the repository, so a test can
  /// assert on fields `calls` does not spell out — the vignette country and
  /// validity in particular.
  final List<CostEntry> saved = [];

  @override
  Future<List<CostEntry>> forVehicle(String vehicleId) async => entries;

  @override
  Future<void> add(CostEntry entry) async {
    calls.add('add:${entry.category}:${entry.amount}');
    saved.add(entry);
  }

  @override
  Future<void> update(CostEntry entry) async {
    calls.add('update:${entry.id}');
    saved.add(entry);
  }

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

  /// Service type keys whose outstanding one-off rules were cleared, in order.
  final List<List<String>> completed = [];

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
  ) async {
    completed.add(serviceTypeKeys);
  }

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

    testWidgets('paying clears the reminder that asked you to', (tester) async {
      // The reminder was raised by a cost and could only be cleared by
      // logging a *service*, so the way to be rid of "Vignette expires" was to
      // record having serviced a vignette. Buying the next one is the act that
      // settles it.
      final maintenance = RecordingMaintenanceRepository();
      await pumpSheet(
        tester,
        repository: FakeCostRepository([]),
        maintenance: maintenance,
      );
      await tester.pumpAndSettle();

      await saveCost(tester, 'Insurance');

      expect(maintenance.completed, [
        ['service_insurance'],
      ]);
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

    // A vignette is bought for a stated period, not for a year, and the day it
    // stops being valid is the whole point of recording it. Croatia charges at
    // the barrier, so this matters exactly when the car leaves the country.
    testWidgets('a vignette reminds on its last valid day, once asked to', (
      tester,
    ) async {
      // The switch has to be turned on deliberately: see "a vignette does
      // not remind by default" below for why.
      final maintenance = RecordingMaintenanceRepository();
      await pumpSheet(
        tester,
        repository: FakeCostRepository([]),
        maintenance: maintenance,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vignette').last);
      await tester.pumpAndSettle();

      // The country comes first, because it decides which periods exist.
      await tester.tap(find.byType(DropdownButtonFormField<VignetteCountry>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Slovenia').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<VignetteValidity>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('7 days').last);
      await tester.pumpAndSettle();

      final remindSwitch = find.byType(SwitchListTile);
      await tester.ensureVisible(remindSwitch);
      await tester.pumpAndSettle();
      await tester.tap(remindSwitch);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, '16');
      final save = find.widgetWithText(FilledButton, 'Save');
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(maintenance.upserted, hasLength(1));
      final rule = maintenance.upserted.single;
      expect(rule.serviceTypeKey, 'service_vignette');
      expect(rule.oneTime, isTrue);
      // Seven days including today, so the last valid day is six days out.
      expect(
        rule.dueDate!.difference(DateTime.now().toUtc()).inDays,
        inInclusiveRange(5, 6),
      );
    });

    // Switzerland sells only the annual; Slovenia has no two-month. Offering
    // every period for every country would invent products.
    testWidgets('only the periods that country sells are offered', (
      tester,
    ) async {
      await pumpSheet(tester, repository: FakeCostRepository([]));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vignette').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<VignetteCountry>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Switzerland').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<VignetteValidity>));
      await tester.pumpAndSettle();

      expect(find.text('1 year'), findsWidgets);
      expect(find.text('10 days'), findsNothing);
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

  // Registration and insurance recur for every car, every year, near
  // certainly — a household forgetting one is the thing worth nagging about.
  // A vignette recurs only if the same trip does, and the common case is a
  // single crossing: buy it once, use it once, never again. Defaulting the
  // switch on for both alike is what turned one Slovenian week into a
  // standing "payment is late" notice nobody asked for.
  group('whether a vignette nags by default', () {
    testWidgets('does not, unlike a yearly obligation', (tester) async {
      final maintenance = RecordingMaintenanceRepository();
      await pumpSheet(
        tester,
        repository: FakeCostRepository([]),
        maintenance: maintenance,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vignette').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<VignetteCountry>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Slovenia').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<VignetteValidity>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('7 days').last);
      await tester.pumpAndSettle();

      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isFalse,
      );

      await tester.enterText(find.byType(TextField).first, '16');
      final save = find.widgetWithText(FilledButton, 'Save');
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(maintenance.upserted, isEmpty);
    });

    testWidgets('an insurance policy still nags by default', (tester) async {
      await pumpSheet(tester, repository: FakeCostRepository([]));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Insurance').last);
      await tester.pumpAndSettle();

      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isTrue,
      );
    });
  });

  // The country and validity used to live only in the sheet's own state, so
  // closing it threw them away — an edit restored the amount and the notes and
  // silently forgot what the vignette was even for.
  group('what a vignette purchase was for', () {
    testWidgets('is saved onto the entry, not just used to compute a date', (
      tester,
    ) async {
      final repository = FakeCostRepository([]);
      await pumpSheet(tester, repository: repository);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vignette').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<VignetteCountry>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Slovenia').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<VignetteValidity>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('7 days').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '16');
      final save = find.widgetWithText(FilledButton, 'Save');
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(repository.saved.single.vignetteCountry, VignetteCountry.slovenia);
      expect(repository.saved.single.vignetteValidity, VignetteValidity.days7);
    });

    testWidgets('is restored when the entry is reopened to edit', (
      tester,
    ) async {
      final existing = CostEntry(
        id: 'c1',
        vehicleId: 'v1',
        date: DateTime.utc(2026, 5, 23),
        category: CostCategories.vignette,
        amount: 16,
        createdBy: 'u1',
        vignetteCountry: VignetteCountry.slovenia,
        vignetteValidity: VignetteValidity.days7,
      );
      await pumpSheet(
        tester,
        repository: FakeCostRepository([existing]),
        existing: existing,
      );
      await tester.pumpAndSettle();

      expect(find.text('Slovenia'), findsOneWidget);
      expect(find.text('7 days'), findsOneWidget);
    });

    // The stale reminder the fix's own report was about: a vignette entry
    // saved before the switch defaulted off left an active "expires" rule
    // behind. Reopening it and saving again, switch left where it now
    // defaults, is the only way to clear that rule short of deleting the row.
    testWidgets(
      'saving an edit with the switch off retracts an earlier reminder',
      (tester) async {
        final existing = CostEntry(
          id: 'c1',
          vehicleId: 'v1',
          date: DateTime.utc(2026, 5, 23),
          category: CostCategories.vignette,
          amount: 16,
          createdBy: 'u1',
          vignetteCountry: VignetteCountry.slovenia,
          vignetteValidity: VignetteValidity.days7,
        );
        final maintenance = RecordingMaintenanceRepository();
        await pumpSheet(
          tester,
          repository: FakeCostRepository([existing]),
          existing: existing,
          maintenance: maintenance,
        );
        await tester.pumpAndSettle();

        final save = find.widgetWithText(FilledButton, 'Save');
        await tester.ensureVisible(save);
        await tester.pumpAndSettle();
        await tester.tap(save);
        await tester.pumpAndSettle();

        expect(maintenance.completed, [
          ['service_vignette'],
        ]);
        expect(maintenance.upserted, isEmpty);
      },
    );

    testWidgets('editing with the switch turned on reschedules it', (
      tester,
    ) async {
      final existing = CostEntry(
        id: 'c1',
        vehicleId: 'v1',
        date: DateTime.utc(2026, 5, 23),
        category: CostCategories.vignette,
        amount: 16,
        createdBy: 'u1',
        vignetteCountry: VignetteCountry.slovenia,
        vignetteValidity: VignetteValidity.days7,
      );
      final maintenance = RecordingMaintenanceRepository();
      await pumpSheet(
        tester,
        repository: FakeCostRepository([existing]),
        existing: existing,
        maintenance: maintenance,
      );
      await tester.pumpAndSettle();

      final remindSwitch = find.byType(SwitchListTile);
      await tester.ensureVisible(remindSwitch);
      await tester.pumpAndSettle();
      await tester.tap(remindSwitch);
      await tester.pumpAndSettle();
      final save = find.widgetWithText(FilledButton, 'Save');
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(maintenance.upserted, hasLength(1));
      expect(maintenance.upserted.single.serviceTypeKey, 'service_vignette');
    });
  });
}
