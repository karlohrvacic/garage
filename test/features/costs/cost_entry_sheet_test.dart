import 'dart:typed_data';
import 'package:cross_file/cross_file.dart';
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
import 'package:garage/domain/entities/vehicle.dart';
import 'package:garage/core/files/file_picker.dart';
import 'package:garage/features/attachments/providers/attachment_providers.dart';
import 'package:garage/features/settings/providers/unit_providers.dart';
import 'package:garage/features/vehicles/providers/vehicle_providers.dart';
import 'package:garage/l10n/app_localizations.dart';

import '../../support/fake_attachments.dart';
import '../../support/pump_screen.dart';

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
  RecordingMaintenanceRepository({
    this.failUpsert = false,
    this.rules = const [],
  });

  /// What is already standing on the vehicle. The sheet has to read this to
  /// know whether the household wanted a reminder, rather than assuming the
  /// category's default and writing the assumption back.
  final List<ReminderRule> rules;
  final bool failUpsert;
  final List<ReminderRule> upserted = [];

  /// Service type keys whose outstanding one-off rules were cleared, in order.
  final List<List<String>> completed = [];

  @override
  Future<List<ServiceType>> serviceTypes() async => const [];

  @override
  Future<List<ReminderRule>> rulesForVehicle(String vehicleId) async => rules;

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
  List<Vehicle>? vehicles,

  /// What is already attached, and what the file picker hands back.
  FakeAttachmentRepository? attachments,
  XFile? pickedFile,
}) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        costRepositoryProvider.overrideWithValue(repository),
        attachmentRepositoryProvider.overrideWithValue(
          attachments ?? FakeAttachmentRepository(),
        ),
        filePickerProvider.overrideWithValue(() async => pickedFile),
        maintenanceRepositoryProvider.overrideWithValue(
          maintenance ?? RecordingMaintenanceRepository(),
        ),
        costEntriesProvider(
          'v1',
        ).overrideWith((ref) async => repository.entries),
        allVehiclesProvider.overrideWith(
          (ref) async => vehicles ?? [testVehicle('v1', nickname: 'Golf')],
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
      find.textContaining('Something went wrong. Please try again.'),
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
    await tester.pumpAndSettle();
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
      await tester.pumpAndSettle();
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
      // The day actually paid, not the day the row is written — a backdated
      // premium is not freshly issued just because it was typed in today.
      expect(rule.issuedDate, isNotNull);
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
      final vignetteCountryField = find.byType(
        DropdownButtonFormField<VignetteCountry>,
      );
      await tester.ensureVisible(vignetteCountryField);
      await tester.pumpAndSettle();
      await tester.tap(vignetteCountryField);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Slovenia').last);
      await tester.pumpAndSettle();

      final vignetteValidityField = find.byType(
        DropdownButtonFormField<VignetteValidity>,
      );
      await tester.ensureVisible(vignetteValidityField);
      await tester.pumpAndSettle();
      await tester.tap(vignetteValidityField);
      await tester.pumpAndSettle();
      await tester.tap(find.text('7 days').last);
      await tester.pumpAndSettle();

      final remindSwitch = find.byType(SwitchListTile);
      await tester.ensureVisible(remindSwitch);
      await tester.pumpAndSettle();
      await tester.tap(remindSwitch);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, '16');
      await tester.pumpAndSettle();
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

      final vignetteCountryField = find.byType(
        DropdownButtonFormField<VignetteCountry>,
      );
      await tester.ensureVisible(vignetteCountryField);
      await tester.pumpAndSettle();
      await tester.tap(vignetteCountryField);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Switzerland').last);
      await tester.pumpAndSettle();

      final vignetteValidityField = find.byType(
        DropdownButtonFormField<VignetteValidity>,
      );
      await tester.ensureVisible(vignetteValidityField);
      await tester.pumpAndSettle();
      await tester.tap(vignetteValidityField);
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
      await tester.pumpAndSettle();
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
    await tester.pumpAndSettle();
    final save = find.widgetWithText(FilledButton, 'Save');
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(repository.calls, ['add:${CostCategories.insurance}:320.0']);
    expect(
      find.textContaining('Something went wrong. Please try again.'),
      findsNothing,
    );
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

      final vignetteCountryField = find.byType(
        DropdownButtonFormField<VignetteCountry>,
      );
      await tester.ensureVisible(vignetteCountryField);
      await tester.pumpAndSettle();
      await tester.tap(vignetteCountryField);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Slovenia').last);
      await tester.pumpAndSettle();

      final vignetteValidityField = find.byType(
        DropdownButtonFormField<VignetteValidity>,
      );
      await tester.ensureVisible(vignetteValidityField);
      await tester.pumpAndSettle();
      await tester.tap(vignetteValidityField);
      await tester.pumpAndSettle();
      await tester.tap(find.text('7 days').last);
      await tester.pumpAndSettle();

      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isFalse,
      );

      await tester.enterText(find.byType(TextField).first, '16');
      await tester.pumpAndSettle();
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
      final vignetteCountryField = find.byType(
        DropdownButtonFormField<VignetteCountry>,
      );
      await tester.ensureVisible(vignetteCountryField);
      await tester.pumpAndSettle();
      await tester.tap(vignetteCountryField);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Slovenia').last);
      await tester.pumpAndSettle();
      final vignetteValidityField = find.byType(
        DropdownButtonFormField<VignetteValidity>,
      );
      await tester.ensureVisible(vignetteValidityField);
      await tester.pumpAndSettle();
      await tester.tap(vignetteValidityField);
      await tester.pumpAndSettle();
      await tester.tap(find.text('7 days').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '16');
      await tester.pumpAndSettle();
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

  // The switch was seeded from the category's default on an edit as well as on
  // a new entry, so it showed what a vignette usually does rather than what
  // this household actually chose — and saving wrote that assumption back.
  group('reopening an entry that already has a reminder', () {
    CostEntry vignette() => CostEntry(
      id: 'c1',
      vehicleId: 'v1',
      date: DateTime.utc(2026, 5, 23),
      category: CostCategories.vignette,
      amount: 16,
      createdBy: 'u1',
      vignetteCountry: VignetteCountry.slovenia,
      vignetteValidity: VignetteValidity.days7,
    );

    ReminderRule standing({
      String key = RecurringCosts.vignetteServiceTypeKey,
      DateTime? issued,
      bool active = true,
    }) => ReminderRule(
      id: 'r1',
      vehicleId: 'v1',
      serviceTypeKey: key,
      oneTime: true,
      active: active,
      dueDate: DateTime.utc(2026, 5, 29),
      issuedDate: issued ?? DateTime.utc(2026, 5, 23),
    );

    testWidgets('shows the switch on, not the category default', (
      tester,
    ) async {
      await pumpSheet(
        tester,
        repository: FakeCostRepository([vignette()]),
        existing: vignette(),
        maintenance: RecordingMaintenanceRepository(rules: [standing()]),
      );
      await tester.pumpAndSettle();

      final remindSwitch = find.byType(SwitchListTile);
      await tester.ensureVisible(remindSwitch);
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(remindSwitch).value, isTrue);
    });

    // The damaging half: correcting the amount on a vignette whose reminder
    // was deliberately switched on used to retract that reminder, because the
    // sheet reopened showing off and saved what it showed.
    testWidgets('correcting the amount keeps that reminder', (tester) async {
      final maintenance = RecordingMaintenanceRepository(rules: [standing()]);
      await pumpSheet(
        tester,
        repository: FakeCostRepository([vignette()]),
        existing: vignette(),
        maintenance: maintenance,
      );
      await tester.pumpAndSettle();

      final save = find.widgetWithText(FilledButton, 'Save');
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(maintenance.upserted, hasLength(1));
    });

    // And the other direction: a yearly obligation whose nag was declined has
    // no standing rule, so reopening it must not offer to recreate one.
    testWidgets('a declined yearly reminder stays declined', (tester) async {
      final maintenance = RecordingMaintenanceRepository();
      await pumpSheet(
        tester,
        repository: FakeCostRepository([cost()]),
        existing: cost(),
        maintenance: maintenance,
      );
      await tester.pumpAndSettle();

      final remindSwitch = find.byType(SwitchListTile);
      await tester.ensureVisible(remindSwitch);
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(remindSwitch).value, isFalse);

      final save = find.widgetWithText(FilledButton, 'Save');
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(maintenance.upserted, isEmpty);
    });

    // A rule already settled is not a wish to be restored.
    testWidgets('a completed rule does not turn the switch back on', (
      tester,
    ) async {
      await pumpSheet(
        tester,
        repository: FakeCostRepository([vignette()]),
        existing: vignette(),
        maintenance: RecordingMaintenanceRepository(
          rules: [standing(active: false)],
        ),
      );
      await tester.pumpAndSettle();

      final remindSwitch = find.byType(SwitchListTile);
      await tester.ensureVisible(remindSwitch);
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(remindSwitch).value, isFalse);
    });
  });

  // Deleting the expense that raised a reminder left the reminder standing,
  // with nothing behind it and no way to settle it: clearing "Vignette
  // expires" meant logging a *service* of a thing nobody services.
  group('deleting an expense that raised a reminder', () {
    CostEntry vignette() => CostEntry(
      id: 'c1',
      vehicleId: 'v1',
      date: DateTime.utc(2026, 5, 23),
      category: CostCategories.vignette,
      amount: 16,
      createdBy: 'u1',
      vignetteCountry: VignetteCountry.slovenia,
      vignetteValidity: VignetteValidity.days7,
    );

    testWidgets('retracts it', (tester) async {
      final maintenance = RecordingMaintenanceRepository(
        rules: [
          ReminderRule(
            id: 'r1',
            vehicleId: 'v1',
            serviceTypeKey: RecurringCosts.vignetteServiceTypeKey,
            oneTime: true,
            dueDate: DateTime.utc(2026, 5, 29),
            issuedDate: DateTime.utc(2026, 5, 23),
          ),
        ],
      );
      await pumpSheet(
        tester,
        repository: FakeCostRepository([vignette()]),
        existing: vignette(),
        maintenance: maintenance,
      );
      await tester.pumpAndSettle();

      await tapDelete(tester);

      expect(maintenance.completed, [
        [RecurringCosts.vignetteServiceTypeKey],
      ]);
    });

    // Precision matters more than tidiness here: a household that buys a
    // second vignette in the same year and then deletes the *first*, older
    // entry must keep the reminder the newer purchase raised. The rule names
    // the day it was issued, so it can say which entry it belongs to.
    testWidgets('leaves a reminder raised by a different purchase', (
      tester,
    ) async {
      final maintenance = RecordingMaintenanceRepository(
        rules: [
          ReminderRule(
            id: 'r1',
            vehicleId: 'v1',
            serviceTypeKey: RecurringCosts.vignetteServiceTypeKey,
            oneTime: true,
            dueDate: DateTime.utc(2026, 8, 30),
            issuedDate: DateTime.utc(2026, 8, 24),
          ),
        ],
      );
      await pumpSheet(
        tester,
        repository: FakeCostRepository([vignette()]),
        existing: vignette(),
        maintenance: maintenance,
      );
      await tester.pumpAndSettle();

      await tapDelete(tester);

      expect(maintenance.completed, isEmpty);
    });

    // Nothing standing, nothing to retract.
    testWidgets('touches no rules when none is outstanding', (tester) async {
      final maintenance = RecordingMaintenanceRepository();
      await pumpSheet(
        tester,
        repository: FakeCostRepository([cost()]),
        existing: cost(),
        maintenance: maintenance,
      );
      await tester.pumpAndSettle();

      await tapDelete(tester);

      expect(maintenance.completed, isEmpty);
    });
  });

  // Every sheet in the app titled itself "Add …" while editing, on a form
  // that was also offering a Delete button. The title is the one line that
  // says which of the two things is happening.
  group('the title says which it is', () {
    testWidgets('adding', (tester) async {
      await pumpSheet(tester, repository: FakeCostRepository([]));
      await tester.pumpAndSettle();

      expect(find.text('Add cost'), findsOneWidget);
    });

    testWidgets('editing', (tester) async {
      await pumpSheet(
        tester,
        repository: FakeCostRepository([cost()]),
        existing: cost(),
      );
      await tester.pumpAndSettle();

      expect(find.text('Edit cost'), findsOneWidget);
    });
  });

  // Every other numeric field in the app clears its error as you type; this
  // one left "Amount is required" sitting under the box while you corrected
  // it, which reads as though the correction is not being accepted.
  testWidgets('the amount error clears as soon as you type', (tester) async {
    await pumpSheet(tester, repository: FakeCostRepository([]));
    await tester.pumpAndSettle();

    final save = find.widgetWithText(FilledButton, 'Save');
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.text('Enter an amount.'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('cost-amount')), '1');
    await tester.pumpAndSettle();

    expect(find.text('Enter an amount.'), findsNothing);
  });

  testWidgets('the amount says its currency', (tester) async {
    await pumpSheet(tester, repository: FakeCostRepository([]));
    await tester.pumpAndSettle();

    expect(find.text('€'), findsOneWidget);
  });

  group('the vehicle it is for', () {
    testWidgets('names the car the expense lands on', (tester) async {
      // Two cars, one + button: the sheet never said which one was about to be
      // charged for the insurance.
      await pumpSheet(tester, repository: FakeCostRepository([]));
      await tester.pumpAndSettle();

      final row = find.byKey(const Key('sheet-vehicle'));
      expect(row, findsOneWidget);
      expect(find.descendant(of: row, matching: find.text('Golf')), findsOne);
    });

    testWidgets('a new expense can be moved to the other car', (tester) async {
      final repository = FakeCostRepository([]);
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

      await tester.enterText(find.byType(TextField).first, '90');
      await tester.pumpAndSettle();
      final save = find.widgetWithText(FilledButton, 'Save');
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(repository.saved.single.vehicleId, 'v2');
    });
  });

  group('a receipt on an expense that is not saved yet', () {
    testWidgets('is deleted again when the sheet is abandoned', (tester) async {
      final attachments = FakeAttachmentRepository();
      await pumpSheet(
        tester,
        repository: FakeCostRepository([]),
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

    testWidgets('is kept once the expense is saved', (tester) async {
      final attachments = FakeAttachmentRepository();
      await pumpSheet(
        tester,
        repository: FakeCostRepository([]),
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

      await tester.enterText(find.byType(TextField).first, '90');
      await tester.pumpAndSettle();
      final save = find.widgetWithText(FilledButton, 'Save');
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();

      expect(attachments.stored, hasLength(1));
    });
  });

  group('a cost that repeats one already logged', () {
    /// Today, as the sheet stamps it: the date picker starts on the local day
    /// and the entry stores that day in UTC.
    DateTime todayUtc() {
      final now = DateTime.now();
      return DateTime.utc(now.year, now.month, now.day);
    }

    testWidgets('says so while the amount is being typed', (tester) async {
      final repository = FakeCostRepository([
        CostEntry(
          id: 'c1',
          vehicleId: 'v1',
          date: todayUtc(),
          category: CostCategories.registration,
          amount: 210,
          createdBy: 'u1',
        ),
      ]);
      await pumpSheet(tester, repository: repository);
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('cost-amount')), '210');
      await tester.pumpAndSettle();

      expect(find.textContaining('already logged'), findsOneWidget);
    });

    testWidgets('and stays quiet for a different amount', (tester) async {
      final repository = FakeCostRepository([
        CostEntry(
          id: 'c1',
          vehicleId: 'v1',
          date: todayUtc(),
          category: CostCategories.registration,
          amount: 210,
          createdBy: 'u1',
        ),
      ]);
      await pumpSheet(tester, repository: repository);
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('cost-amount')), '215');
      await tester.pumpAndSettle();

      expect(find.textContaining('already logged'), findsNothing);
    });

    testWidgets('and never refuses the save', (tester) async {
      // Two parking charges of the same size on one day are ordinary.
      final repository = FakeCostRepository([
        CostEntry(
          id: 'c1',
          vehicleId: 'v1',
          date: todayUtc(),
          category: CostCategories.registration,
          amount: 210,
          createdBy: 'u1',
        ),
      ]);
      await pumpSheet(tester, repository: repository);
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('cost-amount')), '210');
      await tester.pumpAndSettle();
      final save = find.widgetWithText(FilledButton, 'Save');
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(repository.saved.single.amount, 210);
    });

    testWidgets('an entry being edited does not accuse itself', (tester) async {
      final existing = CostEntry(
        id: 'c1',
        vehicleId: 'v1',
        date: todayUtc(),
        category: CostCategories.registration,
        amount: 210,
        createdBy: 'u1',
      );
      await pumpSheet(
        tester,
        repository: FakeCostRepository([existing]),
        existing: existing,
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('already logged'), findsNothing);
    });
  });
}
