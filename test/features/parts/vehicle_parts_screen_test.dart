import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/entities/vehicle_part.dart';
import 'package:garage/features/parts/data/vehicle_part_repository.dart';
import 'package:garage/features/parts/providers/vehicle_part_providers.dart';
import 'package:garage/features/parts/screens/vehicle_parts_screen.dart';

import '../../support/pump_screen.dart';

class FakeVehiclePartRepository implements VehiclePartRepository {
  FakeVehiclePartRepository({this.parts = const []});

  List<VehiclePart> parts;
  final List<VehiclePart> saved = [];
  final List<String> deleted = [];

  @override
  Future<List<VehiclePart>> forVehicle(String vehicleId) async => parts;

  @override
  Future<void> save(VehiclePart part) async => saved.add(part);

  @override
  Future<void> delete(String id) async => deleted.add(id);
}

VehiclePart oil() => const VehiclePart(
  id: 'p1',
  vehicleId: 'v1',
  serviceTypeKey: 'service_oil_change',
  spec: '5W-30 ACEA C3',
  notes: '4.3 l with filter',
  createdBy: 'u1',
);

Future<void> pumpParts(
  WidgetTester tester,
  FakeVehiclePartRepository repository, {
  Locale? locale,
  double textScale = 1,
  Size surface = const Size(420, 1000),
}) async {
  await pumpScreen(
    tester,
    const VehiclePartsScreen(vehicleId: 'v1'),
    initialLocation: '/vehicles/v1/parts',
    locale: locale,
    textScale: textScale,
    surface: surface,
    vehicles: [testVehicle('v1', nickname: 'Golf')],
    overrides: [vehiclePartRepositoryProvider.overrideWithValue(repository)],
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the title names the car', (tester) async {
    await pumpParts(tester, FakeVehiclePartRepository());

    expect(find.text('Golf · What this car takes'), findsOneWidget);
  });

  // Roadmap item 12, the half that needs no data: a household looks a part
  // number up once and the app remembers it, keyed by the job it is for.
  testWidgets('a car with nothing recorded offers the first lookup', (
    tester,
  ) async {
    await pumpParts(tester, FakeVehiclePartRepository());

    expect(find.byKey(const Key('part-add-first')), findsOneWidget);
    expect(find.byKey(const Key('part-add')), findsNothing);
  });

  testWidgets('a recorded spec is shown under the job it is for', (
    tester,
  ) async {
    await pumpParts(tester, FakeVehiclePartRepository(parts: [oil()]));

    expect(find.text('Oil change'), findsOneWidget);
    expect(find.text('5W-30 ACEA C3'), findsOneWidget);
    expect(find.text('4.3 l with filter'), findsOneWidget);
  });

  testWidgets('deleting asks first, then goes through the repository', (
    tester,
  ) async {
    final repository = FakeVehiclePartRepository(parts: [oil()]);
    await pumpParts(tester, repository);

    await tester.tap(find.byKey(const Key('part-menu-p1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(repository.deleted, isEmpty, reason: 'not before confirming');

    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    expect(repository.deleted, ['p1']);
  });

  testWidgets('a new spec cannot be saved without saying what it is', (
    tester,
  ) async {
    final repository = FakeVehiclePartRepository();
    await pumpParts(tester, repository);

    await tester.tap(find.byKey(const Key('part-add-first')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('part-save')));
    await tester.pumpAndSettle();

    expect(repository.saved, isEmpty);
  });

  for (final language in ['hr', 'it']) {
    testWidgets('lays out in $language on a narrow phone at a large font', (
      tester,
    ) async {
      await pumpParts(
        tester,
        FakeVehiclePartRepository(parts: [oil()]),
        locale: Locale(language),
        textScale: 1.5,
        surface: const Size(320, 2000),
      );

      expect(tester.takeException(), isNull);
    });
  }
}
