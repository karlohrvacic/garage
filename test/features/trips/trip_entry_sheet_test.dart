import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/format/unit_format.dart';
import 'package:garage/domain/entities/trip_entry.dart';
import 'package:garage/features/trips/data/trip_repository.dart';
import 'package:garage/features/trips/providers/trip_providers.dart';
import 'package:garage/features/trips/widgets/trip_entry_sheet.dart';
import 'package:garage/features/settings/providers/unit_providers.dart';
import 'package:garage/l10n/app_localizations.dart';
import 'package:garage/domain/entities/trip_draft.dart';

class FakeTripRepository implements TripRepository {
  FakeTripRepository({this.entries = const []});

  List<TripEntry> entries;
  final List<TripEntry> added = [];
  final List<TripEntry> updated = [];
  final List<String> deleted = [];

  @override
  Future<List<TripEntry>> forVehicle(String vehicleId) async => entries;

  @override
  Future<void> add(TripEntry entry) async => added.add(entry);

  @override
  Future<void> update(TripEntry entry) async => updated.add(entry);

  @override
  Future<void> delete(String id) async => deleted.add(id);

  @override
  Future<TripDraft?> openDraft(String vehicleId) async => null;

  @override
  Future<void> startDraft(TripDraft draft) async {}

  @override
  Future<void> discardDraft(String id) async {}
}

Future<void> pumpSheet(
  WidgetTester tester, {
  required FakeTripRepository repository,
  TripEntry? existing,
  Size surface = const Size(500, 1600),
  double textScale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = surface;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        tripRepositoryProvider.overrideWithValue(repository),
        tripEntriesProvider(
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
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: Scaffold(
              body: TripEntrySheet(vehicleId: 'v1', existing: existing),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('a trip is saved with its distance and purpose', (tester) async {
    final repository = FakeTripRepository();
    await pumpSheet(tester, repository: repository);

    await tester.enterText(find.byKey(const Key('trip-distance')), '188');
    await tester.tap(find.text('Business'));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repository.added.single.distanceKm, 188);
    expect(repository.added.single.purpose, TripPurpose.business);
  });

  testWidgets('two odometer readings fill the distance in', (tester) async {
    // A driver who has just read the trip off the dashboard should not then be
    // asked to subtract.
    final repository = FakeTripRepository();
    await pumpSheet(tester, repository: repository);

    await tester.enterText(
      find.byKey(const Key('trip-start-odometer')),
      '46818',
    );
    await tester.enterText(find.byKey(const Key('trip-end-odometer')), '47006');
    await tester.pump();

    expect(find.text('188.0'), findsOneWidget);
  });

  testWidgets('a trip with neither a distance nor a range is refused', (
    tester,
  ) async {
    final repository = FakeTripRepository();
    await pumpSheet(tester, repository: repository);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repository.added, isEmpty);
    expect(find.textContaining('Enter a distance'), findsOneWidget);
  });

  testWidgets('a range that runs backwards cannot be saved', (tester) async {
    final repository = FakeTripRepository();
    await pumpSheet(tester, repository: repository);

    await tester.enterText(
      find.byKey(const Key('trip-start-odometer')),
      '47006',
    );
    await tester.enterText(find.byKey(const Key('trip-end-odometer')), '46818');
    await tester.pump();

    expect(find.textContaining('cannot be lower'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
      reason: 'the save button is the thing that has to refuse, not the server',
    );
  });

  testWidgets('a distance typed in miles is stored in kilometres', (
    tester,
  ) async {
    final repository = FakeTripRepository();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(500, 1600);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tripRepositoryProvider.overrideWithValue(repository),
          tripEntriesProvider('v1').overrideWith((ref) async => const []),
          unitPreferencesProvider.overrideWithValue(
            const UnitPreferences(
              distance: DistanceUnit.mi,
              volume: VolumeUnit.liter,
              currencyCode: 'EUR',
            ),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: TripEntrySheet(vehicleId: 'v1')),
        ),
      ),
    );

    await tester.enterText(find.byKey(const Key('trip-distance')), '100');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repository.added.single.distanceKm, closeTo(160.9, 0.1));
  });

  testWidgets('editing an existing trip updates rather than adds', (
    tester,
  ) async {
    final existing = TripEntry(
      id: 't1',
      vehicleId: 'v1',
      date: DateTime.utc(2026, 6, 1),
      distanceKm: 50,
      purpose: TripPurpose.private,
      createdBy: 'u1',
    );
    final repository = FakeTripRepository(entries: [existing]);
    await pumpSheet(tester, repository: repository, existing: existing);

    await tester.enterText(find.byKey(const Key('trip-distance')), '75');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repository.added, isEmpty);
    expect(repository.updated.single.distanceKm, 75);
    expect(repository.updated.single.id, 't1');
  });

  group('the title says which it is', () {
    TripEntry existing() => TripEntry(
      id: 't1',
      vehicleId: 'v1',
      date: DateTime.utc(2026, 6, 1),
      distanceKm: 50,
      purpose: TripPurpose.private,
      createdBy: 'u1',
    );

    testWidgets('adding', (tester) async {
      await pumpSheet(tester, repository: FakeTripRepository());
      await tester.pumpAndSettle();

      expect(find.text('Log a trip'), findsOneWidget);
    });

    testWidgets('editing', (tester) async {
      await pumpSheet(
        tester,
        repository: FakeTripRepository(entries: [existing()]),
        existing: existing(),
      );
      await tester.pumpAndSettle();

      expect(find.text('Edit trip'), findsOneWidget);
    });
  });

  testWidgets('odometers, distance and duration say their units', (
    tester,
  ) async {
    await pumpSheet(tester, repository: FakeTripRepository());
    await tester.pumpAndSettle();

    expect(find.text('km'), findsNWidgets(3));
    expect(find.text('min'), findsOneWidget);
  });

  group('a distance and a time that cannot describe a journey', () {
    testWidgets('says what the pair works out at', (tester) async {
      // Hours typed into a field that counts minutes: 188 km in 4 minutes.
      final repository = FakeTripRepository();
      await pumpSheet(tester, repository: repository);

      await tester.enterText(find.byKey(const Key('trip-distance')), '188');
      await tester.enterText(find.byKey(const Key('trip-minutes')), '4');
      await tester.pump();

      expect(find.textContaining('That works out at'), findsOneWidget);
    });

    testWidgets('and says nothing about an ordinary run', (tester) async {
      final repository = FakeTripRepository();
      await pumpSheet(tester, repository: repository);

      await tester.enterText(find.byKey(const Key('trip-distance')), '188');
      await tester.enterText(find.byKey(const Key('trip-minutes')), '115');
      await tester.pump();

      expect(find.textContaining('That works out at'), findsNothing);
    });

    testWidgets('and never refuses the save', (tester) async {
      // A trip left timing through a two-hour stop is real, and only the
      // person who drove it knows.
      final repository = FakeTripRepository();
      await pumpSheet(tester, repository: repository);

      await tester.enterText(find.byKey(const Key('trip-distance')), '188');
      await tester.enterText(find.byKey(const Key('trip-minutes')), '4');
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(repository.added.single.minutes, 4);
    });
  });

  testWidgets('a trip records who was driving, not only who typed it', (
    tester,
  ) async {
    // A mileage logbook for tax names the driver, and in a shared garage one
    // person routinely logs the journey another one made.
    final repository = FakeTripRepository();
    await pumpSheet(tester, repository: repository);

    await tester.enterText(find.byKey(const Key('trip-distance')), '188');
    final driver = find.byKey(const Key('trip-driver'));
    await tester.ensureVisible(driver);
    await tester.pumpAndSettle();
    await tester.enterText(driver, 'Ana Horvat');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repository.added.single.driver, 'Ana Horvat');
  });

  testWidgets('and leaving the driver blank stores nothing', (tester) async {
    final repository = FakeTripRepository();
    await pumpSheet(tester, repository: repository);

    await tester.enterText(find.byKey(const Key('trip-distance')), '188');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repository.added.single.driver, isNull);
  });

  testWidgets('the sheet survives a narrow phone at the largest text', (
    tester,
  ) async {
    // Distance and minutes share a Row, and the driver field was added under
    // them: the two-across row is where doubling the text runs out of width.
    await pumpSheet(
      tester,
      repository: FakeTripRepository(),
      existing: TripEntry(
        id: 't1',
        vehicleId: 'v1',
        date: DateTime.utc(2026, 5, 4),
        distanceKm: 188,
        purpose: TripPurpose.business,
        createdBy: 'u1',
        title: 'Split — client',
        fromPlace: 'Zagreb',
        toPlace: 'Split',
        minutes: 235,
        driver: 'Ana Horvat',
      ),
      surface: const Size(320, 900),
      textScale: 2,
    );

    expect(tester.takeException(), isNull);
  });
}
