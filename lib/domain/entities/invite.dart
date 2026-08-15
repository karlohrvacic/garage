/// Where an invite code stands. What a household needs to know about a code is
/// whether it still works, and if not, why.
enum InviteStatus { active, used, expired }

/// A code issued to bring someone into a household.
///
/// Codes are minted, not consumed on creation: one that nobody redeemed is
/// still good until it expires. The app lists them so a household can hand out
/// the code it already has instead of generating another every time, and
/// revoke one that went to the wrong person.
class Invite {
  const Invite({
    required this.id,
    required this.code,
    required this.createdAt,
    required this.expiresAt,
    this.redeemedAt,
  });

  final String id;
  final String code;
  final DateTime createdAt;
  final DateTime expiresAt;

  /// When someone joined with it. Null while it is still outstanding.
  final DateTime? redeemedAt;

  /// Used outranks expired: a code that let someone in did its job, and saying
  /// "expired" about it would misdescribe what happened.
  InviteStatus statusAt(DateTime now) {
    if (redeemedAt != null) {
      return InviteStatus.used;
    }
    return expiresAt.isAfter(now) ? InviteStatus.active : InviteStatus.expired;
  }
}

abstract final class Invites {
  /// The code to show when someone asks to invite a person — the oldest one
  /// still waiting, so an existing code gets handed out again instead of the
  /// household accumulating a pile of live codes it cannot see.
  ///
  /// Oldest rather than newest because it expires soonest: using it up first
  /// leaves the longer-lived codes available.
  static Invite? reusable(List<Invite> invites, DateTime now) {
    final active = invites
        .where((invite) => invite.statusAt(now) == InviteStatus.active)
        .toList();
    if (active.isEmpty) {
      return null;
    }
    return active.reduce((a, b) => a.createdAt.isBefore(b.createdAt) ? a : b);
  }
}
