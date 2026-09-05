import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/entities/guest_pass.dart';
import 'package:garage/features/vehicles/data/guest_pass_repository.dart';
import 'package:garage/features/vehicles/providers/guest_pass_providers.dart';
import 'package:garage/features/vehicles/screens/guest_passes_screen.dart';
import 'package:garage/features/vehicles/screens/guest_redeem_screen.dart';
import 'package:garage/features/vehicles/screens/vehicles_screen.dart';
import 'package:garage/features/vehicles/providers/vehicle_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../support/pump_screen.dart';

class RecordingGuestPassRepository implements GuestPassRepository {
  RecordingGuestPassRepository({this.passes = const []});

  List<GuestPass> passes;
  final List<String> calls = [];
  Map<String, Object?>? created;
  Object? redeemFailsWith;

  @override
  Future<List<GuestPass>> forVehicle(String vehicleId) async => passes;

  @override
  Future<List<GuestPass>> mine() async => const [];

  @override
  Future<String> create({
    required String vehicleId,
    required int validDays,
    String? label,
    DateTime? startsAt,
    bool canLogFuel = true,
    bool canLogTrips = true,
    bool canLogCosts = true,
    bool canViewHistory = false,
  }) async {
    created = {
      'vehicleId': vehicleId,
      'validDays': validDays,
      'label': label,
      'canLogFuel': canLogFuel,
      'canLogTrips': canLogTrips,
      'canLogCosts': canLogCosts,
      'canViewHistory': canViewHistory,
    };
    return 'WXYZ7788';
  }

  @override
  Future<void> revoke(String id) async => calls.add('revoke:$id');

  @override
  Future<String> redeem(String code) async {
    calls.add('redeem:$code');
    if (redeemFailsWith != null) {
      throw redeemFailsWith!;
    }
    return 'v1';
  }
}

final _now = DateTime.now().toUtc();

GuestPass livePass({String id = 'p1', String? label}) {
  return GuestPass(
    id: id,
    vehicleId: 'v1',
    code: 'ABCD2345',
    createdBy: 'u1',
    createdAt: _now.subtract(const Duration(days: 1)),
    expiresAt: _now.add(const Duration(days: 4)),
    redeemedBy: 'g1',
    redeemedAt: _now.subtract(const Duration(hours: 2)),
    label: label,
  );
}

Future<void> pumpPasses(
  WidgetTester tester,
  RecordingGuestPassRepository repository,
) async {
  await pumpScreen(
    tester,
    const GuestPassesScreen(vehicleId: 'v1'),
    initialLocation: '/vehicles/v1/lending',
    surface: const Size(500, 1600),
    vehicles: [testVehicle('v1', nickname: 'Golf')],
    overrides: [guestPassRepositoryProvider.overrideWithValue(repository)],
  );
  await tester.pumpAndSettle();
}

void main() {
  group('the owner side', () {
    testWidgets('a car nobody has borrowed says so', (tester) async {
      await pumpPasses(tester, RecordingGuestPassRepository());

      expect(find.text('This car has never been lent out.'), findsOneWidget);
      expect(find.byKey(const Key('lend-car')), findsOneWidget);
    });

    testWidgets('a live pass shows its code, who it is for, and its days', (
      tester,
    ) async {
      await pumpPasses(
        tester,
        RecordingGuestPassRepository(passes: [livePass(label: 'Ivan')]),
      );

      expect(find.text('In use'), findsOneWidget);
      expect(find.text('ABCD2345'), findsOneWidget);
      expect(find.text('Ivan'), findsOneWidget);
      expect(find.textContaining('days left'), findsOneWidget);
    });

    testWidgets('minting sends exactly what the switches say', (tester) async {
      final repository = RecordingGuestPassRepository();
      await pumpPasses(tester, repository);

      await tester.tap(find.byKey(const Key('lend-car')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('lend-label')), 'Ivan');
      await tester.tap(find.text('3'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('lend-costs')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('lend-create')));
      await tester.pumpAndSettle();

      expect(repository.created, {
        'vehicleId': 'v1',
        'validDays': 3,
        'label': 'Ivan',
        'canLogFuel': true,
        'canLogTrips': true,
        'canLogCosts': false,
        'canViewHistory': false,
      });
    });

    testWidgets('history is off unless it is deliberately switched on', (
      tester,
    ) async {
      final repository = RecordingGuestPassRepository();
      await pumpPasses(tester, repository);

      await tester.tap(find.byKey(const Key('lend-car')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('lend-create')));
      await tester.pumpAndSettle();

      expect(repository.created!['canViewHistory'], false);
    });

    testWidgets('the code is shown for handing over, not just saved', (
      tester,
    ) async {
      // A pass whose code nobody read is a pass nobody can use.
      await pumpPasses(tester, RecordingGuestPassRepository());

      await tester.tap(find.byKey(const Key('lend-car')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('lend-create')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('lend-code')), findsOneWidget);
      expect(find.text('WXYZ7788'), findsOneWidget);
    });

    testWidgets('withdrawing asks first', (tester) async {
      final repository = RecordingGuestPassRepository(passes: [livePass()]);
      await pumpPasses(tester, repository);

      await tester.tap(find.text('Withdraw'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Everything they logged stays.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Withdraw').last);
      await tester.pumpAndSettle();
      expect(repository.calls, contains('revoke:p1'));
    });

    testWidgets('a finished pass offers no way to withdraw it', (tester) async {
      await pumpPasses(
        tester,
        RecordingGuestPassRepository(
          passes: [
            GuestPass(
              id: 'p2',
              vehicleId: 'v1',
              code: 'OLDCODE1',
              createdBy: 'u1',
              createdAt: _now.subtract(const Duration(days: 30)),
              expiresAt: _now.subtract(const Duration(days: 20)),
              redeemedBy: 'g1',
              redeemedAt: _now.subtract(const Duration(days: 29)),
            ),
          ],
        ),
      );

      expect(find.text('Finished'), findsOneWidget);
      expect(find.text('Withdraw'), findsNothing);
    });
  });

  group('the borrower side', () {
    Future<void> pumpRedeem(
      WidgetTester tester,
      RecordingGuestPassRepository repository,
    ) async {
      await pumpScreen(
        tester,
        const GuestRedeemScreen(),
        initialLocation: '/borrowed',
        surface: const Size(500, 1200),
        extraRoutes: const {'/vehicles/v1'},
        overrides: [guestPassRepositoryProvider.overrideWithValue(repository)],
      );
      await tester.pumpAndSettle();
    }

    testWidgets('a good code opens the car', (tester) async {
      final repository = RecordingGuestPassRepository();
      final log = await pumpScreen(
        tester,
        const GuestRedeemScreen(),
        initialLocation: '/borrowed',
        surface: const Size(500, 1200),
        extraRoutes: const {'/vehicles/v1'},
        overrides: [guestPassRepositoryProvider.overrideWithValue(repository)],
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('redeem-code')), 'abcd2345');
      await tester.tap(find.byKey(const Key('redeem-submit')));
      await tester.pumpAndSettle();

      expect(repository.calls, contains('redeem:abcd2345'));
      expect(log.visited.last, '/vehicles/v1');
    });

    testWidgets('every refusal reads the same', (tester) async {
      // Telling somebody holding a code whether it expired or is already in
      // use tells them something about a car that is not theirs.
      final repository = RecordingGuestPassRepository()
        ..redeemFailsWith = Exception('already in use');
      await pumpRedeem(tester, repository);

      await tester.enterText(find.byKey(const Key('redeem-code')), 'NOPE1234');
      await tester.tap(find.byKey(const Key('redeem-submit')));
      await tester.pumpAndSettle();

      expect(find.textContaining('That code does not work.'), findsOneWidget);
    });
  });

  group('a car somebody lent you', () {
    testWidgets('appears under its own heading, not among your own', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        const VehiclesScreen(),
        initialLocation: '/vehicles',
        surface: const Size(500, 1600),
        vehicles: [testVehicle('v1', nickname: 'My Golf')],
        borrowedVehicles: [
          testVehicle('v9', nickname: 'Sister Clio', householdId: 'hers'),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('vehicle-v1')), findsOneWidget);
      expect(find.byKey(const Key('borrowed-v9')), findsOneWidget);
      expect(
        find.byKey(const Key('vehicle-v9')),
        findsNothing,
        reason: 'a borrowed car is not one of the garage\'s own',
      );
      expect(find.text('LENT TO YOU'), findsOneWidget);
    });

    testWidgets('is not shown at all when nothing is borrowed', (tester) async {
      await pumpScreen(
        tester,
        const VehiclesScreen(),
        initialLocation: '/vehicles',
        surface: const Size(500, 1600),
        vehicles: [testVehicle('v1', nickname: 'My Golf')],
      );
      await tester.pumpAndSettle();

      expect(find.text('LENT TO YOU'), findsNothing);
    });

    testWidgets('has a page of its own, so redeeming can land on it', (
      tester,
    ) async {
      // Redeeming navigates straight to /vehicles/<id>. The vehicle lookup
      // used to search only the garage's own cars, so that page rendered as
      // "no such vehicle" for the one car the pass had just opened.
      await pumpScreen(
        tester,
        const VehiclesScreen(),
        initialLocation: '/vehicles',
        surface: const Size(500, 1600),
        vehicles: const [],
        borrowedVehicles: [
          testVehicle('v9', nickname: 'Sister Clio', householdId: 'hers'),
        ],
      );
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(VehiclesScreen)),
      );
      expect(
        (await container.read(vehicleProvider('v9').future))?.nickname,
        'Sister Clio',
      );
    });
  });
}
