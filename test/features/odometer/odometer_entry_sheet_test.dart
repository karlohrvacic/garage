import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/format/unit_format.dart';
import 'package:garage/domain/entities/odometer_entry.dart';
import 'package:garage/features/odometer/data/odometer_repository.dart';
import 'package:garage/features/odometer/providers/odometer_providers.dart';
import 'package:garage/features/odometer/widgets/odometer_entry_sheet.dart';
import 'package:garage/features/settings/providers/unit_providers.dart';
import 'package:garage/l10n/app_localizations.dart';

class FakeOdometerRepository implements OdometerRepository {
  FakeOdometerRepository({this.entries = const [], this.failAdd = false});

  List<OdometerEntry> entries;
  final bool failAdd;
  final List<OdometerEntry> added = [];
  final List<OdometerEntry> updated = [];
  final List<String> deleted = [];

  @override
  Future<List<OdometerEntry>> forVehicle(String vehicleId) async => entries;

  @override
  Future<void> add(OdometerEntry entry) async {
    if (failAdd) {
      throw Exception('nope');
    }
    added.add(entry);
  }

  @override
  Future<void> update(OdometerEntry entry) async => updated.add(entry);

  @override
  Future<void> delete(String id) async => deleted.add(id);
}

OdometerEntry reading({int km = 84000}) {
  return OdometerEntry(
    id: 'o1',
    vehicleId: 'v1',
    date: DateTime.utc(2026, 6, 1),
    odometerKm: km,
    createdBy: 'u1',
  );
}

Future<void> pumpSheet(
  WidgetTester tester, {
  required FakeOdometerRepository repository,
  OdometerEntry? existing,
  UnitPreferences preferences = const UnitPreferences(
    distance: DistanceUnit.km,
    volume: VolumeUnit.liter,
    currencyCode: 'EUR',
  ),
}) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        odometerRepositoryProvider.overrideWithValue(repository),
        odometerEntriesProvider(
          'v1',
        ).overrideWith((ref) async => repository.entries),
        unitPreferencesProvider.overrideWithValue(preferences),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: OdometerEntrySheet(vehicleId: 'v1', existing: existing),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('a reading is saved in kilometres', (tester) async {
    final repository = FakeOdometerRepository();
    await pumpSheet(tester, repository: repository);

    await tester.enterText(find.byKey(const Key('odometer-reading')), '84210');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repository.added.single.odometerKm, 84210);
    expect(repository.added.single.vehicleId, 'v1');
  });

  testWidgets('a reading typed in miles is stored in kilometres', (
    tester,
  ) async {
    // Units are canonical in storage and converted at the edge; a household
    // reading miles off its dashboard must not put miles in the database.
    final repository = FakeOdometerRepository();
    await pumpSheet(
      tester,
      repository: repository,
      preferences: const UnitPreferences(
        distance: DistanceUnit.mi,
        volume: VolumeUnit.liter,
        currencyCode: 'EUR',
      ),
    );

    await tester.enterText(find.byKey(const Key('odometer-reading')), '100');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repository.added.single.odometerKm, 161);
  });

  testWidgets('an empty reading is refused rather than saved as zero', (
    tester,
  ) async {
    final repository = FakeOdometerRepository();
    await pumpSheet(tester, repository: repository);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repository.added, isEmpty);
    expect(find.text('Enter the odometer reading'), findsOneWidget);
  });

  testWidgets('editing an existing reading updates rather than adds', (
    tester,
  ) async {
    final repository = FakeOdometerRepository(entries: [reading()]);
    await pumpSheet(tester, repository: repository, existing: reading());

    expect(find.text('84000'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('odometer-reading')), '85000');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repository.added, isEmpty);
    expect(repository.updated.single.odometerKm, 85000);
    expect(repository.updated.single.id, 'o1');
  });

  testWidgets('a rejected save says so instead of closing silently', (
    tester,
  ) async {
    final repository = FakeOdometerRepository(failAdd: true);
    await pumpSheet(tester, repository: repository);

    await tester.enterText(find.byKey(const Key('odometer-reading')), '84210');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.byType(OdometerEntrySheet), findsOneWidget);
    expect(find.textContaining('Something went wrong'), findsOneWidget);
  });
}
