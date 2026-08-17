import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/entities/household.dart';
import 'package:garage/domain/entities/invite.dart';
import 'package:garage/features/auth/data/auth_repository.dart';
import 'package:garage/features/auth/providers/auth_providers.dart';
import 'package:garage/features/household/data/household_repository.dart';
import 'package:garage/features/household/providers/household_providers.dart';
import 'package:garage/features/household/screens/household_screen.dart';
import 'package:garage/domain/household/settlement.dart';
import 'package:garage/features/household/providers/settlement_providers.dart';
import 'package:garage/features/household/screens/onboarding_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import '../../support/pump_screen.dart';

class RecordingHouseholdRepository implements HouseholdRepository {
  /// Members an admin removed.
  final List<String> removed = [];

  RecordingHouseholdRepository({
    this.households = const [testHousehold],
    this.people = const [],
    this.issued = const [],
  });

  /// Codes the household has already handed out.
  List<Invite> issued;

  final List<Household> households;
  final List<HouseholdMember> people;
  final List<String> calls = [];

  @override
  Future<List<Household>> myHouseholds() async => households;

  @override
  Future<String> create(String name) async {
    calls.add('create:$name');
    return 'h1';
  }

  @override
  Future<String> joinWithCode(String code) async {
    calls.add('join:$code');
    return 'h1';
  }

  @override
  Future<String> createInvite(String householdId) async {
    calls.add('invite:$householdId');
    issued = [
      ...issued,
      Invite(
        id: 'i-${issued.length + 1}',
        code: 'ABCD2345',
        createdAt: DateTime.now().toUtc(),
        expiresAt: DateTime.now().toUtc().add(const Duration(days: 14)),
      ),
    ];
    return 'ABCD2345';
  }

  @override
  Future<List<Invite>> invites(String householdId) async => issued;

  @override
  Future<void> revokeInvite(String inviteId) async {
    calls.add('revoke:$inviteId');
    issued = issued.where((invite) => invite.id != inviteId).toList();
  }

  @override
  Future<List<HouseholdMember>> members(String householdId) async => people;

  @override
  Future<void> leave(String householdId) async => calls.add('leave');

  @override
  Future<void> removeMember({
    required String householdId,
    required String userId,
  }) async => removed.add(userId);

  @override
  Future<void> updateSettings(Household household) async {}
}

class SilentAuthRepository implements AuthRepository {
  final List<String> calls = [];

  @override
  User? get currentUser => null;

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {}

  @override
  Future<void> signInWithGoogle() async {}

  @override
  Future<void> signOut() async => calls.add('signOut');

  @override
  Future<void> sendPasswordReset(String email) async {}

  @override
  Future<void> updatePassword(String newPassword) async {}

  @override
  Future<void> deleteAccount() async {}
}

Future<NavigationLog> pumpHousehold(
  WidgetTester tester,
  RecordingHouseholdRepository households, {
  void Function(String link)? onShare,
}) {
  return pumpScreen(
    tester,
    const HouseholdScreen(),
    initialLocation: '/household',
    surface: const Size(420, 1000),
    overrides: [
      householdRepositoryProvider.overrideWithValue(households),
      authRepositoryProvider.overrideWithValue(SilentAuthRepository()),
      if (onShare != null) inviteShareProvider.overrideWithValue(onShare),
    ],
  );
}

Future<NavigationLog> pumpOnboarding(
  WidgetTester tester,
  RecordingHouseholdRepository households, {
  SilentAuthRepository? auth,
}) {
  return pumpScreen(
    tester,
    const OnboardingScreen(),
    initialLocation: '/onboarding',
    surface: const Size(420, 1200),
    household: null,
    overrides: [
      householdRepositoryProvider.overrideWithValue(households),
      authRepositoryProvider.overrideWithValue(auth ?? SilentAuthRepository()),
    ],
  );
}

void main() {
  group('the household screen', () {
    testWidgets('lists the members by name and role', (tester) async {
      final households = RecordingHouseholdRepository(
        people: const [
          HouseholdMember(userId: 'u1', displayName: 'Karlo', role: 'admin'),
          HouseholdMember(userId: 'u2', displayName: 'Ana', role: 'member'),
        ],
      );
      await pumpHousehold(tester, households);
      await tester.pumpAndSettle();

      expect(find.text('Karlo'), findsOneWidget);
      expect(find.text('Ana'), findsOneWidget);
      expect(find.text('Admin'), findsOneWidget);
      expect(find.text('Member'), findsOneWidget);
    });

    testWidgets('creating an invite shows a shareable code', (tester) async {
      final households = RecordingHouseholdRepository();
      await pumpHousehold(tester, households);
      await tester.pumpAndSettle();

      final invite = find.textContaining('Invite');
      await tester.ensureVisible(invite.first);
      await tester.pumpAndSettle();
      await tester.tap(invite.first);
      await tester.pumpAndSettle();

      expect(households.calls, contains('invite:h1'));
      // Listed once, in the invites list — never also in a card above the
      // button, which is what made the same code look like two codes.
      expect(find.text('ABCD2345'), findsOneWidget);
    });

    // Three complaints, one cause: the code was drawn twice. A transient card
    // above the button, and a permanent row below in the list — so with a
    // reusable code already issued, "Invite someone" silently re-surfaced it
    // into a card off the top of the screen. It read as a button that did
    // nothing, or as the code moving somewhere else.
    testWidgets('a code that already exists is not drawn a second time', (
      tester,
    ) async {
      final households = RecordingHouseholdRepository(
        issued: [
          Invite(
            id: 'i1',
            code: 'ABCD2345',
            createdAt: DateTime.now().toUtc(),
            expiresAt: DateTime.now().toUtc().add(const Duration(days: 14)),
          ),
        ],
      );
      await pumpHousehold(tester, households);
      await tester.pumpAndSettle();

      final invite = find.widgetWithText(FilledButton, 'Invite someone');
      await tester.ensureVisible(invite);
      await tester.pumpAndSettle();
      await tester.tap(invite);
      await tester.pumpAndSettle();

      expect(find.text('ABCD2345'), findsOneWidget);
    });

    // What someone wants from "Invite someone" is to hand the invite over, not
    // to look at it. Reusing the existing code rather than minting another is
    // deliberate; doing nothing visible was not.
    testWidgets('inviting hands the link over instead of just showing it', (
      tester,
    ) async {
      final households = RecordingHouseholdRepository(
        issued: [
          Invite(
            id: 'i1',
            code: 'ABCD2345',
            createdAt: DateTime.now().toUtc(),
            expiresAt: DateTime.now().toUtc().add(const Duration(days: 14)),
          ),
        ],
      );
      final shared = <String>[];
      await pumpHousehold(tester, households, onShare: shared.add);
      await tester.pumpAndSettle();

      final invite = find.widgetWithText(FilledButton, 'Invite someone');
      await tester.ensureVisible(invite);
      await tester.pumpAndSettle();
      await tester.tap(invite);
      await tester.pumpAndSettle();

      expect(households.calls, isNot(contains('invite:h1')));
      expect(shared.single, contains('/join/ABCD2345'));
    });

    testWidgets('an admin can remove another member', (tester) async {
      final households = RecordingHouseholdRepository(
        people: const [
          HouseholdMember(userId: 'u1', displayName: 'Karlo', role: 'admin'),
          HouseholdMember(userId: 'u2', displayName: 'Ana', role: 'member'),
        ],
      );
      await pumpScreen(
        tester,
        const HouseholdScreen(),
        initialLocation: '/household',
        surface: const Size(420, 1200),
        overrides: [
          householdRepositoryProvider.overrideWithValue(households),
          authRepositoryProvider.overrideWithValue(SilentAuthRepository()),
        ],
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.person_remove_outlined).first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(households.removed, ['u2']);
    });

    testWidgets('an admin cannot remove themselves that way', (tester) async {
      await pumpScreen(
        tester,
        const HouseholdScreen(),
        initialLocation: '/household',
        surface: const Size(420, 1200),
        overrides: [
          householdRepositoryProvider.overrideWithValue(
            RecordingHouseholdRepository(
              people: const [
                HouseholdMember(
                  userId: 'u1',
                  displayName: 'Karlo',
                  role: 'admin',
                ),
                HouseholdMember(
                  userId: 'u2',
                  displayName: 'Ana',
                  role: 'member',
                ),
              ],
            ),
          ),
          authRepositoryProvider.overrideWithValue(SilentAuthRepository()),
        ],
      );
      await tester.pumpAndSettle();

      // Only Ana's row offers removal; leaving is the way out for yourself.
      expect(find.byIcon(Icons.person_remove_outlined), findsOneWidget);
    });

    testWidgets('an ordinary member is offered no removals at all', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        const HouseholdScreen(),
        initialLocation: '/household',
        surface: const Size(420, 1200),
        overrides: [
          householdRepositoryProvider.overrideWithValue(
            RecordingHouseholdRepository(
              people: const [
                HouseholdMember(
                  userId: 'u1',
                  displayName: 'Karlo',
                  role: 'admin',
                ),
                HouseholdMember(
                  userId: 'u2',
                  displayName: 'Ana',
                  role: 'member',
                ),
              ],
            ),
          ),
          authRepositoryProvider.overrideWithValue(SilentAuthRepository()),
        ],
        userId: 'u2',
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.person_remove_outlined), findsNothing);
    });

    testWidgets('inviting from a narrow phone lays out cleanly', (
      tester,
    ) async {
      final households = RecordingHouseholdRepository();
      await pumpScreen(
        tester,
        const HouseholdScreen(),
        initialLocation: '/household',
        surface: const Size(320, 800),
        overrides: [
          householdRepositoryProvider.overrideWithValue(households),
          authRepositoryProvider.overrideWithValue(SilentAuthRepository()),
        ],
      );
      await tester.pumpAndSettle();

      final invite = find.textContaining('Invite');
      await tester.ensureVisible(invite.first);
      await tester.pumpAndSettle();
      await tester.tap(invite.first);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('shows what each member has put in', (tester) async {
      final households = RecordingHouseholdRepository(
        people: const [
          HouseholdMember(userId: 'u1', displayName: 'Karlo', role: 'admin'),
          HouseholdMember(userId: 'u2', displayName: 'Ana', role: 'member'),
        ],
      );
      await pumpScreen(
        tester,
        const HouseholdScreen(),
        initialLocation: '/household',
        surface: const Size(420, 1200),
        overrides: [
          householdRepositoryProvider.overrideWithValue(households),
          authRepositoryProvider.overrideWithValue(SilentAuthRepository()),
          settlementProvider.overrideWith(
            (ref) async =>
                Settlement.of(spendByMember: const {'u1': 300, 'u2': 100}),
          ),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('Shared spend'), findsOneWidget);
      expect(find.textContaining('300'), findsWidgets);
      expect(find.textContaining('100'), findsWidgets);
    });

    testWidgets('names who owes whom, and how much', (tester) async {
      final households = RecordingHouseholdRepository(
        people: const [
          HouseholdMember(userId: 'u1', displayName: 'Karlo', role: 'admin'),
          HouseholdMember(userId: 'u2', displayName: 'Ana', role: 'member'),
        ],
      );
      await pumpScreen(
        tester,
        const HouseholdScreen(),
        initialLocation: '/household',
        surface: const Size(420, 1200),
        overrides: [
          householdRepositoryProvider.overrideWithValue(households),
          authRepositoryProvider.overrideWithValue(SilentAuthRepository()),
          settlementProvider.overrideWith(
            (ref) async =>
                Settlement.of(spendByMember: const {'u1': 300, 'u2': 0}),
          ),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Ana owes Karlo'), findsOneWidget);
      expect(find.textContaining('150'), findsWidgets);
    });

    testWidgets('a household that is even says so', (tester) async {
      final households = RecordingHouseholdRepository(
        people: const [
          HouseholdMember(userId: 'u1', displayName: 'Karlo', role: 'admin'),
          HouseholdMember(userId: 'u2', displayName: 'Ana', role: 'member'),
        ],
      );
      await pumpScreen(
        tester,
        const HouseholdScreen(),
        initialLocation: '/household',
        surface: const Size(420, 1200),
        overrides: [
          householdRepositoryProvider.overrideWithValue(households),
          authRepositoryProvider.overrideWithValue(SilentAuthRepository()),
          settlementProvider.overrideWith(
            (ref) async =>
                Settlement.of(spendByMember: const {'u1': 150, 'u2': 150}),
          ),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('All square'), findsOneWidget);
    });

    testWidgets('shows spend from a deleted account apart from the split', (
      tester,
    ) async {
      final households = RecordingHouseholdRepository(
        people: const [
          HouseholdMember(userId: 'u1', displayName: 'Karlo', role: 'admin'),
          HouseholdMember(userId: 'u2', displayName: 'Ana', role: 'member'),
        ],
      );
      await pumpScreen(
        tester,
        const HouseholdScreen(),
        initialLocation: '/household',
        surface: const Size(420, 1200),
        overrides: [
          householdRepositoryProvider.overrideWithValue(households),
          authRepositoryProvider.overrideWithValue(SilentAuthRepository()),
          settlementProvider.overrideWith(
            (ref) async => Settlement.of(
              spendByMember: const {'u1': 300, 'u2': 0},
              unattributed: 200,
            ),
          ),
        ],
      );
      await tester.pumpAndSettle();

      // Named as what it is, rather than as a row in the split: the share is
      // still 150 each and Ana still owes Karlo that, not a third of 500.
      expect(find.textContaining('deleted account'), findsOneWidget);
      expect(find.textContaining(RegExp(r'Even share: .*150')), findsOneWidget);
      expect(find.textContaining('Ana owes Karlo'), findsOneWidget);
    });

    testWidgets('says nothing about deleted accounts when there are none', (
      tester,
    ) async {
      final households = RecordingHouseholdRepository(
        people: const [
          HouseholdMember(userId: 'u1', displayName: 'Karlo', role: 'admin'),
          HouseholdMember(userId: 'u2', displayName: 'Ana', role: 'member'),
        ],
      );
      await pumpScreen(
        tester,
        const HouseholdScreen(),
        initialLocation: '/household',
        surface: const Size(420, 1200),
        overrides: [
          householdRepositoryProvider.overrideWithValue(households),
          authRepositoryProvider.overrideWithValue(SilentAuthRepository()),
          settlementProvider.overrideWith(
            (ref) async =>
                Settlement.of(spendByMember: const {'u1': 300, 'u2': 0}),
          ),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('deleted account'), findsNothing);
    });

    testWidgets('leaving asks first', (tester) async {
      final households = RecordingHouseholdRepository();
      await pumpHousehold(tester, households);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Leave household').last);
      await tester.pumpAndSettle();

      expect(find.textContaining('lose access'), findsOneWidget);
      expect(households.calls, isEmpty);
    });

    testWidgets('a cancelled leave keeps the membership', (tester) async {
      final households = RecordingHouseholdRepository();
      await pumpHousehold(tester, households);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Leave household').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(households.calls, isEmpty);
    });
  });

  group('onboarding', () {
    testWidgets('offers both creating and joining', (tester) async {
      await pumpOnboarding(tester, RecordingHouseholdRepository());
      await tester.pumpAndSettle();

      expect(find.text('Create a household'), findsOneWidget);
      expect(find.text('Join with a code'), findsOneWidget);
    });

    testWidgets('a named household is created', (tester) async {
      final households = RecordingHouseholdRepository();
      await pumpOnboarding(tester, households);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, 'Hrvačić');
      await tester.tap(find.widgetWithText(FilledButton, 'Create'));
      await tester.pumpAndSettle();

      expect(households.calls, ['create:Hrvačić']);
    });

    testWidgets('an unnamed household is refused', (tester) async {
      final households = RecordingHouseholdRepository();
      await pumpOnboarding(tester, households);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Create'));
      await tester.pumpAndSettle();

      expect(households.calls, isEmpty);
      expect(find.text('Enter a name'), findsOneWidget);
    });

    testWidgets('an eight-character code joins', (tester) async {
      final households = RecordingHouseholdRepository();
      await pumpOnboarding(tester, households);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).last, 'ABCD2345');
      final join = find.widgetWithText(OutlinedButton, 'Join');
      await tester.ensureVisible(join);
      await tester.pumpAndSettle();
      await tester.tap(join);
      await tester.pumpAndSettle();

      expect(households.calls, ['join:ABCD2345']);
    });

    testWidgets('a short code is refused before any call', (tester) async {
      final households = RecordingHouseholdRepository();
      await pumpOnboarding(tester, households);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).last, 'ABC');
      final join = find.widgetWithText(OutlinedButton, 'Join');
      await tester.ensureVisible(join);
      await tester.pumpAndSettle();
      await tester.tap(join);
      await tester.pumpAndSettle();

      expect(households.calls, isEmpty);
      expect(find.textContaining('8-character'), findsWidgets);
    });

    testWidgets('signing out is available from onboarding', (tester) async {
      final auth = SilentAuthRepository();
      await pumpOnboarding(tester, RecordingHouseholdRepository(), auth: auth);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();

      expect(auth.calls, ['signOut']);
    });
  });

  group('invite codes', () {
    Invite code({
      String id = 'i1',
      String value = 'ABCD2345',
      DateTime? expiresAt,
      DateTime? redeemedAt,
    }) {
      return Invite(
        id: id,
        code: value,
        createdAt: DateTime.now().toUtc().subtract(const Duration(days: 1)),
        expiresAt:
            expiresAt ?? DateTime.now().toUtc().add(const Duration(days: 13)),
        redeemedAt: redeemedAt,
      );
    }

    testWidgets('the codes already issued are listed with their state', (
      tester,
    ) async {
      await pumpHousehold(
        tester,
        RecordingHouseholdRepository(
          issued: [
            code(),
            code(
              id: 'i2',
              value: 'USED1234',
              redeemedAt: DateTime.now().toUtc(),
            ),
            code(
              id: 'i3',
              value: 'OLD12345',
              expiresAt: DateTime.now().toUtc().subtract(
                const Duration(days: 1),
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ABCD2345'), findsOneWidget);
      expect(find.text('Waiting to be used'), findsOneWidget);
      expect(find.text('Used'), findsOneWidget);
      expect(find.text('Expired'), findsOneWidget);
    });

    testWidgets('inviting again hands out the code that already exists', (
      tester,
    ) async {
      final households = RecordingHouseholdRepository(issued: [code()]);
      await pumpHousehold(tester, households);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Invite someone'));
      await tester.pumpAndSettle();

      expect(
        households.calls.where((call) => call.startsWith('invite:')),
        isEmpty,
        reason: 'a pile of live codes nobody can see is the bug being fixed',
      );
      expect(find.textContaining('ABCD2345'), findsWidgets);
    });

    testWidgets('with no code left to reuse, one is created', (tester) async {
      final households = RecordingHouseholdRepository();
      await pumpHousehold(tester, households);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Invite someone'));
      await tester.pumpAndSettle();

      expect(households.calls, contains('invite:h1'));
    });

    testWidgets('a code can be withdrawn', (tester) async {
      final households = RecordingHouseholdRepository(issued: [code()]);
      await pumpHousehold(tester, households);
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Revoke'));
      await tester.pumpAndSettle();

      expect(households.calls, contains('revoke:i1'));
      expect(find.text('ABCD2345'), findsNothing);
    });
  });
}
