import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/format/unit_format.dart';
import 'package:garage/domain/entities/income_entry.dart';
import 'package:garage/features/income/data/income_repository.dart';
import 'package:garage/features/income/providers/income_providers.dart';
import 'package:garage/features/income/widgets/income_entry_sheet.dart';
import 'package:garage/features/settings/providers/unit_providers.dart';
import 'package:garage/l10n/app_localizations.dart';

class FakeIncomeRepository implements IncomeRepository {
  FakeIncomeRepository({this.entries = const [], this.failAdd = false});

  List<IncomeEntry> entries;
  final bool failAdd;
  final List<IncomeEntry> added = [];
  final List<IncomeEntry> updated = [];
  final List<String> deleted = [];

  @override
  Future<List<IncomeEntry>> forVehicle(String vehicleId) async => entries;

  @override
  Future<void> add(IncomeEntry entry) async {
    if (failAdd) {
      throw Exception('nope');
    }
    added.add(entry);
  }

  @override
  Future<void> update(IncomeEntry entry) async => updated.add(entry);

  @override
  Future<void> delete(String id) async => deleted.add(id);
}

Future<void> pumpSheet(
  WidgetTester tester, {
  required FakeIncomeRepository repository,
  IncomeEntry? existing,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(500, 1400);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        incomeRepositoryProvider.overrideWithValue(repository),
        incomeEntriesProvider(
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
          body: IncomeEntrySheet(vehicleId: 'v1', existing: existing),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('income is saved with its amount and kind', (tester) async {
    final repository = FakeIncomeRepository();
    await pumpSheet(tester, repository: repository);

    await tester.enterText(find.byKey(const Key('income-amount')), '25');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repository.added.single.amount, 25);
    expect(repository.added.single.category, IncomeCategories.ride);
  });

  testWidgets('a sale is one of the kinds offered', (tester) async {
    // The one entry that closes the book on a vehicle, and the reason running
    // cost can ever be a complete figure.
    final repository = FakeIncomeRepository();
    await pumpSheet(tester, repository: repository);

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();

    expect(find.text('Sold the vehicle'), findsWidgets);
  });

  testWidgets('an empty amount is refused rather than saved as zero', (
    tester,
  ) async {
    final repository = FakeIncomeRepository();
    await pumpSheet(tester, repository: repository);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repository.added, isEmpty);
    expect(find.textContaining('Enter an amount'), findsOneWidget);
  });

  testWidgets('a rejected save says so instead of closing silently', (
    tester,
  ) async {
    final repository = FakeIncomeRepository(failAdd: true);
    await pumpSheet(tester, repository: repository);

    await tester.enterText(find.byKey(const Key('income-amount')), '25');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.byType(IncomeEntrySheet), findsOneWidget);
    expect(find.textContaining('Something went wrong'), findsOneWidget);
  });
}
