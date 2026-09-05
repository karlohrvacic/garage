import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/entities/guest_pass.dart';

final _now = DateTime.utc(2026, 9, 5, 12);

GuestPass pass({
  DateTime? startsAt,
  DateTime? expiresAt,
  DateTime? revokedAt,
  String? redeemedBy = 'g1',
  bool canLogFuel = true,
  bool canLogTrips = true,
  bool canLogCosts = true,
  bool canViewHistory = false,
}) {
  return GuestPass(
    id: 'p1',
    vehicleId: 'v1',
    code: 'ABCD2345',
    createdBy: 'u1',
    createdAt: _now.subtract(const Duration(days: 1)),
    startsAt: startsAt,
    expiresAt: expiresAt ?? _now.add(const Duration(days: 6)),
    revokedAt: revokedAt,
    redeemedBy: redeemedBy,
    redeemedAt: redeemedBy == null
        ? null
        : _now.subtract(const Duration(hours: 2)),
    canLogFuel: canLogFuel,
    canLogTrips: canLogTrips,
    canLogCosts: canLogCosts,
    canViewHistory: canViewHistory,
  );
}

void main() {
  group('where a pass stands', () {
    test('a redeemed pass inside its window is live', () {
      expect(pass().stateAt(_now), GuestPassState.live);
    });

    test('one nobody has claimed is waiting', () {
      expect(pass(redeemedBy: null).stateAt(_now), GuestPassState.waiting);
    });

    test('one whose window has not opened is not live yet', () {
      expect(
        pass(startsAt: _now.add(const Duration(days: 2))).stateAt(_now),
        GuestPassState.notStarted,
      );
    });

    test('one past its date has expired', () {
      expect(
        pass(expiresAt: _now.subtract(const Duration(hours: 1))).stateAt(_now),
        GuestPassState.expired,
      );
    });

    test('withdrawn outranks expired, because that is what happened', () {
      expect(
        pass(
          revokedAt: _now.subtract(const Duration(hours: 3)),
          expiresAt: _now.subtract(const Duration(hours: 1)),
        ).stateAt(_now),
        GuestPassState.revoked,
      );
    });

    test('withdrawn outranks live too', () {
      expect(
        pass(revokedAt: _now.subtract(const Duration(hours: 1))).stateAt(_now),
        GuestPassState.revoked,
      );
    });

    test('a pass expiring this very second is no longer live', () {
      expect(pass(expiresAt: _now).stateAt(_now), GuestPassState.expired);
    });

    test('a pass starting this very second is live', () {
      expect(pass(startsAt: _now).stateAt(_now), GuestPassState.live);
    });

    test('an unclaimed pass that ran out reads as expired, not waiting', () {
      expect(
        pass(
          redeemedBy: null,
          expiresAt: _now.subtract(const Duration(hours: 1)),
        ).stateAt(_now),
        GuestPassState.expired,
      );
    });
  });

  group('what a pass is worth', () {
    test('a live pass has time left on it', () {
      expect(
        pass(expiresAt: _now.add(const Duration(days: 2))).remainingAt(_now),
        const Duration(days: 2),
      );
    });

    test('a lapsed one has none, rather than a negative amount', () {
      expect(
        pass(
          expiresAt: _now.subtract(const Duration(days: 2)),
        ).remainingAt(_now),
        Duration.zero,
      );
    });

    test('it lists what it actually allows', () {
      expect(pass(canLogTrips: false, canLogCosts: false).grants, {
        GuestGrant.fuel,
      });
      expect(pass(canViewHistory: true).grants, {
        GuestGrant.fuel,
        GuestGrant.trips,
        GuestGrant.costs,
        GuestGrant.history,
      });
    });

    test('a pass that allows nothing is still a pass, and says so', () {
      expect(
        pass(canLogFuel: false, canLogTrips: false, canLogCosts: false).grants,
        isEmpty,
      );
    });
  });

  group('which passes to show first', () {
    test('live ones lead, then waiting, then everything finished', () {
      final live = pass();
      final waiting = pass(redeemedBy: null);
      final done = pass(expiresAt: _now.subtract(const Duration(days: 1)));

      final sorted = GuestPasses.forDisplay([done, waiting, live], _now);

      expect(sorted.map((it) => it.stateAt(_now)), [
        GuestPassState.live,
        GuestPassState.waiting,
        GuestPassState.expired,
      ]);
    });

    test('among live ones, the one running out soonest comes first', () {
      final later = pass(expiresAt: _now.add(const Duration(days: 5)));
      final sooner = pass(expiresAt: _now.add(const Duration(days: 1)));

      final sorted = GuestPasses.forDisplay([later, sooner], _now);

      expect(sorted.first.expiresAt, sooner.expiresAt);
    });
  });
}
