import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/entities/invite.dart';

final now = DateTime.utc(2026, 8, 16, 12);

Invite invite({DateTime? expiresAt, DateTime? redeemedAt}) {
  return Invite(
    id: 'i1',
    code: 'ABCD2345',
    createdAt: DateTime.utc(2026, 8, 1),
    expiresAt: expiresAt ?? DateTime.utc(2026, 8, 15),
    redeemedAt: redeemedAt,
  );
}

void main() {
  test('a fresh code is waiting to be used', () {
    final subject = invite(expiresAt: DateTime.utc(2026, 8, 30));

    expect(subject.statusAt(now), InviteStatus.active);
  });

  test('a code someone joined with is used, and stays used', () {
    final subject = invite(
      expiresAt: DateTime.utc(2026, 8, 30),
      redeemedAt: DateTime.utc(2026, 8, 10),
    );

    expect(subject.statusAt(now), InviteStatus.used);
  });

  test('a code past its date is expired', () {
    final subject = invite(expiresAt: DateTime.utc(2026, 8, 15));

    expect(subject.statusAt(now), InviteStatus.expired);
  });

  test('being used outranks having expired, because that is what happened', () {
    final subject = invite(
      expiresAt: DateTime.utc(2026, 8, 15),
      redeemedAt: DateTime.utc(2026, 8, 10),
    );

    expect(subject.statusAt(now), InviteStatus.used);
  });

  test('a code expiring this very moment is no longer offered', () {
    final subject = invite(expiresAt: now);

    expect(subject.statusAt(now), InviteStatus.expired);
  });

  group('the code to hand someone', () {
    test(
      'is the oldest one still waiting, so codes are reused not piled up',
      () {
        final invites = [
          Invite(
            id: 'new',
            code: 'NEWCODE1',
            createdAt: DateTime.utc(2026, 8, 14),
            expiresAt: DateTime.utc(2026, 8, 28),
          ),
          Invite(
            id: 'old',
            code: 'OLDCODE1',
            createdAt: DateTime.utc(2026, 8, 10),
            expiresAt: DateTime.utc(2026, 8, 24),
          ),
        ];

        expect(Invites.reusable(invites, now)?.id, 'old');
      },
    );

    test('is none when every code was used or has expired', () {
      final invites = [
        invite(redeemedAt: DateTime.utc(2026, 8, 10)),
        invite(expiresAt: DateTime.utc(2026, 8, 2)),
      ];

      expect(Invites.reusable(invites, now), isNull);
    });
  });
}
