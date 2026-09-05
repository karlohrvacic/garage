import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/entities/household.dart';
import 'package:garage/features/household/data/household_repository.dart';
import 'package:garage/features/household/providers/household_providers.dart';
import 'package:garage/features/household/screens/merge_garages_screen.dart';

import 'package:garage/features/vehicles/data/vehicle_photo_repository.dart';
import 'package:garage/features/vehicles/providers/vehicle_providers.dart';

import '../../support/fake_repositories.dart';
import '../../support/pump_screen.dart';

const _ours = Household(id: 'h1', name: 'Ours');
const _theirs = Household(id: 'h2', name: 'Theirs');
const _dollars = Household(id: 'h3', name: 'Dollars', currencyCode: 'USD');

class RecordingMergeRepository implements HouseholdRepository {
  RecordingMergeRepository({this.households = const [_ours, _theirs]});

  final List<Household> households;
  final List<String> calls = [];

  @override
  Future<List<Household>> myHouseholds() async => households;

  @override
  Future<List<HouseholdMember>> members(String householdId) async => const [
    HouseholdMember(userId: 'u1', displayName: 'Karlo', role: 'admin'),
    HouseholdMember(userId: 'u2', displayName: 'Ana', role: 'member'),
  ];

  @override
  Future<MergeOutcome> merge({
    required String absorbedHouseholdId,
    required String survivingHouseholdId,
  }) async {
    calls.add('merge:$absorbedHouseholdId->$survivingHouseholdId');
    return const MergeOutcome(
      vehiclesMoved: 2,
      membersMoved: 1,
      keysRevoked: 0,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

/// The merge re-homes vehicle photos before it runs, so both of these are on
/// its path even when no car has a photo.
class SilentPhotos implements VehiclePhotoRepository {
  @override
  Future<Uint8List?> download(String path) async => null;

  @override
  Future<String> upload({
    required String householdId,
    required String vehicleId,
    required Uint8List bytes,
    String? contentType,
  }) async => '$householdId/$vehicleId.jpg';

  @override
  Future<Uri?> viewUrl(String? path) async => null;

  @override
  Future<void> delete(String path) async {}
}

Future<void> pumpMerge(
  WidgetTester tester,
  RecordingMergeRepository repository,
) async {
  await pumpScreen(
    tester,
    const MergeGaragesScreen(),
    initialLocation: '/household/merge',
    surface: const Size(420, 1200),
    household: _ours,
    vehicles: [testVehicle('v1'), testVehicle('v2')],
    extraRoutes: const {'/household'},
    overrides: [
      householdRepositoryProvider.overrideWithValue(repository),
      // The garage list is derived from the startup fetch, not from the
      // repository, so overriding the repository alone leaves the screen
      // seeing only the garage the harness put the user in.
      myHouseholdsProvider.overrideWith((ref) async => repository.households),
      vehicleRepositoryProvider.overrideWithValue(FakeVehicleRepository()),
      vehiclePhotoRepositoryProvider.overrideWithValue(SilentPhotos()),
    ],
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the garage you are in is not offered as a candidate', (
    tester,
  ) async {
    await pumpMerge(tester, RecordingMergeRepository());

    expect(find.byKey(const Key('merge-h2')), findsOneWidget);
    expect(
      find.byKey(const Key('merge-h1')),
      findsNothing,
      reason: 'a garage cannot be merged into itself',
    );
  });

  testWidgets('with nowhere to merge from, it says so', (tester) async {
    await pumpMerge(
      tester,
      RecordingMergeRepository(households: const [_ours]),
    );

    expect(
      find.text('You are not an admin of any other garage.'),
      findsOneWidget,
    );
  });

  testWidgets('the confirmation names what moves, not just "are you sure"', (
    tester,
  ) async {
    final repository = RecordingMergeRepository();
    await pumpMerge(tester, repository);

    await tester.tap(find.byKey(const Key('merge-h2')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Move everything from Theirs'), findsOneWidget);
    expect(find.textContaining('2 people'), findsOneWidget);
    expect(
      find.textContaining('Theirs is deleted'),
      findsOneWidget,
      reason: 'the confirmation names the garage that disappears',
    );
    expect(repository.calls, isEmpty, reason: 'nothing has happened yet');
  });

  testWidgets('backing out of the confirmation merges nothing', (tester) async {
    final repository = RecordingMergeRepository();
    await pumpMerge(tester, repository);

    await tester.tap(find.byKey(const Key('merge-h2')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(repository.calls, isEmpty);
  });

  testWidgets('confirming merges into the garage you are in', (tester) async {
    final repository = RecordingMergeRepository();
    await pumpMerge(tester, repository);

    await tester.tap(find.byKey(const Key('merge-h2')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Merge into this garage').last);
    await tester.pumpAndSettle();

    expect(repository.calls, ['merge:h2->h1']);
  });

  testWidgets('a different currency is refused before the confirmation', (
    tester,
  ) async {
    // Being told what is about to happen and then refused is worse than being
    // told why it cannot happen.
    final repository = RecordingMergeRepository(
      households: const [_ours, _dollars],
    );
    await pumpMerge(tester, repository);

    await tester.tap(find.byKey(const Key('merge-h3')));
    await tester.pumpAndSettle();

    expect(find.textContaining('different currencies'), findsOneWidget);
    expect(find.text('Merge into this garage'), findsNothing);
    expect(repository.calls, isEmpty);
  });
}
