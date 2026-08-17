import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/errors/app_failure.dart';
import 'package:garage/domain/entities/vehicle.dart';
import 'package:garage/domain/entities/vehicle_transfer.dart';
import 'package:garage/features/vehicles/data/vehicle_repository.dart';
import 'package:garage/features/vehicles/providers/vehicle_providers.dart';
import 'package:garage/features/vehicles/screens/vehicle_transfer_screen.dart';

import '../../support/pump_screen.dart';

class FakeTransferRepository implements VehicleRepository {
  @override
  Future<List<VehicleTransfer>> transfersOffered(String householdId) async =>
      const [];

  @override
  Future<void> delete(String id) async {}

  FakeTransferRepository({this.failRedeem, this.outstanding});

  final Object? failRedeem;

  /// A code already handed out for this vehicle, as the server would report.
  final String? outstanding;

  final List<String> calls = [];

  @override
  Future<String?> outstandingTransferCode(String vehicleId) async {
    calls.add('outstanding:$vehicleId');
    return outstanding;
  }

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

    expect(
      repository.calls.where((call) => call.startsWith('offer:')),
      isEmpty,
      reason: 'nothing is offered until the dialog is answered',
    );
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('the confirmation names transferring, not deleting', (
    tester,
  ) async {
    // It borrowed the deletion dialog, so offering a vehicle asked "Delete
    // entry? This cannot be undone." over a red Delete button. Nothing is
    // deleted here, and a seller could read that as being about to destroy the
    // car's history rather than hand it over.
    final repository = FakeTransferRepository();
    await pumpTransfer(tester, repository: repository, vehicleId: 'v1');

    await tester.tap(find.byKey(const Key('offer-transfer')));
    await tester.pumpAndSettle();

    expect(find.text('Hand this vehicle over?'), findsOneWidget);
    expect(find.text('Delete entry?'), findsNothing);
    expect(
      find.text('Delete'),
      findsNothing,
      reason: 'the button must name the act it performs',
    );
  });

  testWidgets('a code already handed out is shown, not asked for again', (
    tester,
  ) async {
    // The server has reused an outstanding code since migration 0030. The
    // screen kept it in local state only, so leaving and coming back offered
    // to generate one — with the seller unable to see the code already in a
    // buyer's hands.
    final repository = FakeTransferRepository(outstanding: 'ZZ99YY88');
    await pumpTransfer(tester, repository: repository, vehicleId: 'v1');

    expect(find.text('ZZ99YY88'), findsOneWidget);
    expect(
      find.byKey(const Key('offer-transfer')),
      findsNothing,
      reason: 'there is nothing to generate; one is already live',
    );
  });

  testWidgets('with no code outstanding the offer is still the way in', (
    tester,
  ) async {
    final repository = FakeTransferRepository();
    await pumpTransfer(tester, repository: repository, vehicleId: 'v1');

    expect(find.byKey(const Key('offer-transfer')), findsOneWidget);
  });

  testWidgets('confirming shows the code to hand over', (tester) async {
    final repository = FakeTransferRepository();
    await pumpTransfer(tester, repository: repository, vehicleId: 'v1');

    await tester.tap(find.byKey(const Key('offer-transfer')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Get a transfer code').last);
    await tester.pumpAndSettle();

    // The load-time read for an already-outstanding code comes first; what
    // this is about is that confirming offers exactly once.
    expect(repository.calls, ['outstanding:v1', 'offer:v1']);
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
