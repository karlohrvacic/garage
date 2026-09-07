/// What a guest pass allows its holder to do.
enum GuestGrant { fuel, trips, costs, history, prices }

/// Where a pass stands. What an owner needs to know is whether it still works,
/// and if not, why.
enum GuestPassState {
  /// Redeemed, inside its window, not withdrawn.
  live,

  /// Minted and handed over, but nobody has claimed it yet.
  waiting,

  /// Claimed, but its window has not opened — a rental booked for Tuesday.
  notStarted,

  /// Ran out on its own.
  expired,

  /// The owner took it back.
  revoked,

  /// The holder gave the car back before it ran out. Their act, not the
  /// owner's, and worth telling apart from both of the others: "who ended
  /// this and when" is the question the row is kept to answer.
  returned,
}

/// Scoped, expiring access to one vehicle, for somebody who is deliberately
/// not a member of the garage.
///
/// Lending a car to a friend and renting one to a customer are the same act
/// here: this car, for this long, and only these actions.
class GuestPass {
  const GuestPass({
    required this.id,
    required this.vehicleId,
    required this.code,
    required this.createdBy,
    required this.createdAt,
    required this.expiresAt,
    this.label,
    this.startsAt,
    this.revokedAt,
    this.redeemedBy,
    this.redeemedAt,
    this.canLogFuel = true,
    this.canLogTrips = true,
    this.canLogCosts = true,
    this.canViewHistory = false,
    this.canViewPrices = false,
    this.returnedAt,
  });

  final String id;
  final String vehicleId;
  final String code;
  final String createdBy;
  final DateTime createdAt;

  /// UTC, like every [DateTime] in the domain layer.
  final DateTime expiresAt;

  /// The owner's own note — "Ivan", or a booking reference. The holder never
  /// sees it.
  final String? label;

  /// Null means usable the moment it is handed over.
  final DateTime? startsAt;

  final DateTime? revokedAt;

  /// When the holder handed it back.
  final DateTime? returnedAt;
  final String? redeemedBy;
  final DateTime? redeemedAt;

  final bool canLogFuel;
  final bool canLogTrips;
  final bool canLogCosts;
  final bool canViewHistory;

  /// Whether the history it opens carries what everything cost.
  ///
  /// A mechanic needs to know the belt was changed at 180,000 km; that the
  /// owner paid 240 euro for it is a different question, and the owner is
  /// entitled to answer only the first. Meaningless without [canViewHistory],
  /// which the table enforces with a check constraint rather than trusting
  /// this class.
  final bool canViewPrices;

  /// Withdrawn outranks everything: the owner took it back, and calling that
  /// "expired" would misdescribe what happened — the same distinction the
  /// invite codes draw between used and expired.
  ///
  /// The comparisons match `guest_vehicle_ids` exactly (`now() < expires_at`,
  /// `now() >= starts_at`). The app must not disagree with the policy about
  /// whether a pass still works.
  GuestPassState stateAt(DateTime now) {
    if (revokedAt != null) {
      return GuestPassState.revoked;
    }
    // Before expiry: a pass given back on Sunday is returned, not expired on
    // Wednesday.
    if (returnedAt != null) {
      return GuestPassState.returned;
    }
    if (!now.isBefore(expiresAt)) {
      return GuestPassState.expired;
    }
    if (redeemedBy == null) {
      return GuestPassState.waiting;
    }
    if (startsAt != null && now.isBefore(startsAt!)) {
      return GuestPassState.notStarted;
    }
    return GuestPassState.live;
  }

  /// How much of the pass is left. Never negative: "expired 3 days ago" is a
  /// different sentence, and this one is used to say "4 days left".
  Duration remainingAt(DateTime now) {
    final left = expiresAt.difference(now);
    return left.isNegative ? Duration.zero : left;
  }

  /// The same pass, running until [endsAt] instead.
  ///
  /// Extending rather than reissuing keeps the code the holder already has,
  /// and keeps everything they logged attached to one loan.
  GuestPass extendedTo(DateTime endsAt) => GuestPass(
    id: id,
    vehicleId: vehicleId,
    code: code,
    createdBy: createdBy,
    createdAt: createdAt,
    expiresAt: endsAt,
    label: label,
    startsAt: startsAt,
    revokedAt: revokedAt,
    redeemedBy: redeemedBy,
    redeemedAt: redeemedAt,
    canLogFuel: canLogFuel,
    canLogTrips: canLogTrips,
    canLogCosts: canLogCosts,
    canViewHistory: canViewHistory,
    canViewPrices: canViewPrices,
    returnedAt: returnedAt,
  );

  Set<GuestGrant> get grants => {
    if (canLogFuel) GuestGrant.fuel,
    if (canLogTrips) GuestGrant.trips,
    if (canLogCosts) GuestGrant.costs,
    if (canViewHistory) GuestGrant.history,
    if (canViewPrices) GuestGrant.prices,
  };
}

abstract final class GuestPasses {
  /// Ordered for a screen: what is working now, then what has been handed out
  /// and not claimed, then everything finished.
  ///
  /// Within the live ones the soonest to run out leads, because that is the
  /// one an owner might act on.
  static List<GuestPass> forDisplay(List<GuestPass> passes, DateTime now) {
    const rank = {
      GuestPassState.live: 0,
      GuestPassState.notStarted: 1,
      GuestPassState.waiting: 2,
      GuestPassState.expired: 3,
      GuestPassState.revoked: 4,
      GuestPassState.returned: 5,
    };
    return [...passes]..sort((a, b) {
      final byState = rank[a.stateAt(now)]!.compareTo(rank[b.stateAt(now)]!);
      if (byState != 0) {
        return byState;
      }
      return a.expiresAt.compareTo(b.expiresAt);
    });
  }
}
