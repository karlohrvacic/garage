import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/errors/app_failure.dart';
import 'package:garage/domain/entities/vehicle.dart';
import 'package:garage/features/vehicles/data/vehicle_repository.dart';
import 'package:garage/features/vehicles/providers/vehicle_providers.dart';
import 'package:garage/features/vehicles/screens/vehicle_transfer_screen.dart';

import '../../support/pump_screen.dart';

class FakeTransferRepository implements VehicleRepository {
  FakeTransferRepository({this.failRedeem});

  final Object? failRedeem;
  final List<String> calls = [];

  @override
  Future<String> offerTransfer(String vehicleId) async {
    calls.add('offer:$vehicleId');
    return 'AB23CD45';
  }

  @override
  Future<String> redeemTransfer({
    required String code,
    required String householdId,
  }) async {
    calls.add('redeem:$code:$householdId');
    if (failRedeem != null) {
      throw failRedeem!;
    }
    return 'v1';
  }

  @override
  Future<List<Vehicle>> forHousehold(String householdId) async => const [];

  @override
  Future<Vehicle> create(Vehicle vehicle) async => vehicle;

  @override
  Future<void> update(Vehicle vehicle) async {}

  @override
  Future<void> setArchived(String id, bool archived) async {}

  @override
  Future<void> deleteAllForHousehold(String householdId) async {}
}

Future<void> pumpTransfer(
  WidgetTester tester, {
  required FakeTransferRepository repository,
  String? vehicleId,
}) async {
  await pumpScreen(
    tester,
    VehicleTransferScreen(vehicleId: vehicleId),
    initialLocation: '/transfer',
    overrides: [vehicleRepositoryProvider.overrideWithValue(repository)],
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('offering a car asks before it hands out a code', (tester) async {
    // A code in somebody else's hands is most of the way to the car leaving,
    // and nothing on this side can call it back.
    final repository = FakeTransferRepository();
    await pumpTransfer(tester, repository: repository, vehicleId: 'v1');

    await tester.tap(find.byKey(const Key('offer-transfer')));
    await tester.pumpAndSettle();

    expect(repository.calls, isEmpty);
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('confirming shows the code to hand over', (tester) async {
    final repository = FakeTransferRepository();
    await pumpTransfer(tester, repository: repository, vehicleId: 'v1');

    await tester.tap(find.byKey(const Key('offer-transfer')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();

    expect(repository.calls, ['offer:v1']);
    expect(find.text('AB23CD45'), findsOneWidget);
  });

  testWidgets('a code is redeemed into the household being shown', (
    tester,
  ) async {
    final repository = FakeTransferRepository();
    await pumpTransfer(tester, repository: repository);

    await tester.enterText(find.byKey(const Key('redeem-code')), 'ab23cd45');
    await tester.tap(find.byKey(const Key('redeem-transfer')));
    await tester.pumpAndSettle();

    // Upper-cased on the way out, the way invite codes are: people type them
    // as they read them.
    expect(repository.calls, ['redeem:AB23CD45:h1']);
    expect(find.textContaining('in your garage now'), findsOneWidget);
  });

  testWidgets('a refused code says so rather than looking like it worked', (
    tester,
  ) async {
    final repository = FakeTransferRepository(
      failRedeem: const AppFailure(kind: AppFailureKind.notFound),
    );
    await pumpTransfer(tester, repository: repository);

    await tester.enterText(find.byKey(const Key('redeem-code')), 'ZZZZZZZZ');
    await tester.tap(find.byKey(const Key('redeem-transfer')));
    await tester.pumpAndSettle();

    expect(find.textContaining('in your garage now'), findsNothing);
    expect(find.byKey(const Key('redeem-transfer')), findsOneWidget);
  });

  testWidgets('a buyer with no car yet is only offered the redeem half', (
    tester,
  ) async {
    await pumpTransfer(tester, repository: FakeTransferRepository());

    expect(find.byKey(const Key('offer-transfer')), findsNothing);
    expect(find.byKey(const Key('redeem-transfer')), findsOneWidget);
  });
}
