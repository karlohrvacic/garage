import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/auth/email_link.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/core/errors/app_failure.dart';
import 'package:garage/domain/entities/household.dart';
import 'package:garage/features/settings/providers/settings_providers.dart';
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

/// A garage that has asked for the settlement. It is off by default now, so
/// the tests that exercise it have to say so.
const settlingHousehold = Household(
  id: 'h1',
  name: 'Test',
  settlementEnabled: true,
);

class RecordingHouseholdRepository implements HouseholdRepository {
  @override
  Future<void> deleteHousehold(String householdId) async {
    calls.add('deleteHousehold:$householdId');
  }

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
  Future<bool> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async => false;

  @override
  Future<void> signInWithGoogle() async {}

  @override
  Future<void> signOut() async => calls.add('signOut');

  @override
  Future<void> confirmEmailLink(EmailLink link) async =>
      calls.add('confirmEmailLink:${link.purpose.name}');

  @override
  Future<void> sendPasswordReset(String email) async {}

  @override
  Future<void> updateDisplayName(String name) async =>
      calls.add('updateDisplayName:$name');

  @override
  Future<void> updatePassword(String newPassword) async {}

  @override
  Future<void> deleteAccount() async {}
}

/// A settings controller whose every save fails the same way, so a screen's
/// handling of a refusal can be tested without a backend to refuse it.
class _FailingSettings extends SettingsController {
  _FailingSettings(this.failure);

  final AppFailure failure;

  @override
  Future<AppFailure?> save(Household Function(Household) patch) async {
    state = AsyncError(failure, StackTrace.current);
    return failure;
  }
}

Future<NavigationLog> pumpHousehold(
  WidgetTester tester,
  RecordingHouseholdRepository households, {
  void Function(String link)? onShare,
  AppFailure? settingsFailure,
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
      if (settingsFailure != null)
        settingsControllerProvider.overrideWith(
          () => _FailingSettings(settingsFailure),
        ),
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
  group('having more than one garage', () {
    testWidgets('a code can be used to join one that already exists', (
      tester,
    ) async {
      // Creating a second garage was offered and joining one was not, so
      // somebody handed a code for a garage that already exists — the ordinary
      // way a second garage is acquired — could only make a third one.
      final households = RecordingHouseholdRepository();
      await pumpHousehold(tester, households);
      await tester.pumpAndSettle();

      final join = find.byKey(const Key('join-another-garage'));
      await tester.scrollUntilVisible(join, 200);
      await tester.tap(join);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('join-garage-code')),
        'AB23CD45',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Join'));
      await tester.pumpAndSettle();

      expect(households.calls, contains('join:AB23CD45'));
    });

    testWidgets('a code of the wrong length is not sent', (tester) async {
      final households = RecordingHouseholdRepository();
      await pumpHousehold(tester, households);
      await tester.pumpAndSettle();

      final join = find.byKey(const Key('join-another-garage'));
      await tester.scrollUntilVisible(join, 200);
      await tester.tap(join);
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('join-garage-code')), 'AB2');
      await tester.tap(find.widgetWithText(FilledButton, 'Join'));
      await tester.pumpAndSettle();

      expect(
        households.calls.where((call) => call.startsWith('join:')),
        isEmpty,
        reason:
            'a short code is a typo, and sending it buys a round trip '
            'to be told so',
      );
    });
  });

  group('the household screen', () {
    testWidgets('lists the members by name and role', (tester) async {
      final households = RecordingHouseholdRepository(
        households: const [settlingHousehold],
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
        households: const [settlingHousehold],
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
        // pumpScreen overrides the current household directly, so the
        // repository's copy never reaches the screen.
        household: settlingHousehold,
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
        // pumpScreen overrides the current household directly, so the
        // repository's copy never reaches the screen.
        household: settlingHousehold,
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
        // pumpScreen overrides the current household directly, so the
        // repository's copy never reaches the screen.
        household: settlingHousehold,
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

    testWidgets('a garage that has not asked for it sees no settlement', (
      tester,
    ) async {
      // Dividing every expense equally and naming who owes whom suits people
      // sharing a car and keeping separate money. For a couple with joint
      // finances it read as one partner owing the other half of everything,
      // decided by who happened to log it.
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
          settlementProvider.overrideWith(
            (ref) async =>
                Settlement.of(spendByMember: const {'u1': 300, 'u2': 100}),
          ),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('Shared spend'), findsNothing);
      expect(find.textContaining('owes'), findsNothing);
    });

    testWidgets('shows what each member has put in', (tester) async {
      final households = RecordingHouseholdRepository(
        households: const [settlingHousehold],
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
        // pumpScreen overrides the current household directly, so the
        // repository's copy never reaches the screen.
        household: settlingHousehold,
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
        households: const [settlingHousehold],
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
        // pumpScreen overrides the current household directly, so the
        // repository's copy never reaches the screen.
        household: settlingHousehold,
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
        households: const [settlingHousehold],
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
        // pumpScreen overrides the current household directly, so the
        // repository's copy never reaches the screen.
        household: settlingHousehold,
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
        households: const [settlingHousehold],
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
        // pumpScreen overrides the current household directly, so the
        // repository's copy never reaches the screen.
        household: settlingHousehold,
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
        households: const [settlingHousehold],
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
        // pumpScreen overrides the current household directly, so the
        // repository's copy never reaches the screen.
        household: settlingHousehold,
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

      await tester.tap(find.text('Leave garage').last);
      await tester.pumpAndSettle();

      expect(find.textContaining('lose access'), findsOneWidget);
      expect(households.calls, isEmpty);
    });

    testWidgets('a cancelled leave keeps the membership', (tester) async {
      final households = RecordingHouseholdRepository();
      await pumpHousehold(tester, households);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Leave garage').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(households.calls, isEmpty);
    });
  });

  /// A repository whose signed-in user (`u1`, from the shared harness) is an
  /// admin — which the delete and rename controls require.
  RecordingHouseholdRepository adminOf() => RecordingHouseholdRepository(
    people: const [
      HouseholdMember(userId: 'u1', displayName: 'Karlo', role: 'admin'),
      HouseholdMember(userId: 'u2', displayName: 'Ana', role: 'member'),
    ],
  );

  group('renaming a garage', () {
    // The trigger `enforce_household_rename_is_admin` refuses a rename from a
    // member and raises 42501. The screen showed the generic permission
    // sentence, which leaves the member guessing which of the settings they
    // just changed was refused — the units on the same screen go through the
    // same write and are allowed.
    testWidgets('a refused rename says it is an admin thing', (tester) async {
      // An admin, because the row is only drawn for one. The message is the
      // defensive half: the app's admin check is a convenience and the trigger
      // is the rule, so the two can disagree — a role revoked in another
      // session leaves this screen still offering the control.
      await pumpHousehold(
        tester,
        RecordingHouseholdRepository(
          people: const [
            HouseholdMember(userId: 'u1', displayName: 'Karlo', role: 'admin'),
          ],
        ),
        settingsFailure: const AppFailure(kind: AppFailureKind.permission),
      );
      await tester.pumpAndSettle();

      final rename = find.byKey(const Key('rename-garage'));
      await tester.scrollUntilVisible(rename, 200);
      await tester.tap(rename);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('rename-garage-name')),
        'The other garage',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(find.text('Only an admin can rename the garage'), findsOneWidget);
    });
  });

  group('ending a garage', () {
    testWidgets('an admin is offered delete as well as leave', (tester) async {
      // An admin could leave a garage but never end one. Leaving hands it to
      // whoever is left, which is right for a member and wrong for somebody
      // whose garage has outlived its reason to exist.
      await pumpHousehold(tester, adminOf());
      await tester.pumpAndSettle();

      final delete = find.byKey(const Key('delete-garage'));
      await tester.scrollUntilVisible(delete, 200);

      expect(delete, findsOneWidget);
      expect(find.text('Leave garage'), findsOneWidget);
    });

    testWidgets('deleting says it takes everyone else down with it', (
      tester,
    ) async {
      final households = adminOf();
      await pumpHousehold(tester, households);
      await tester.pumpAndSettle();

      final delete = find.byKey(const Key('delete-garage'));
      await tester.scrollUntilVisible(delete, 200);
      await tester.tap(delete);
      await tester.pumpAndSettle();

      expect(find.text('Delete this garage?'), findsOneWidget);
      expect(
        find.textContaining('not just for you'),
        findsOneWidget,
        reason:
            'that it ends for the other members is the part nobody thinks '
            'about when deleting their own thing',
      );
      expect(
        households.calls.where((c) => c.startsWith('deleteHousehold:')),
        isEmpty,
        reason: 'nothing happens until the dialog is answered',
      );
    });

    testWidgets('confirming ends it', (tester) async {
      final households = adminOf();
      await pumpHousehold(tester, households);
      await tester.pumpAndSettle();

      final delete = find.byKey(const Key('delete-garage'));
      await tester.scrollUntilVisible(delete, 200);
      await tester.tap(delete);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(households.calls, contains('deleteHousehold:h1'));
    });
  });

  group('onboarding', () {
    testWidgets('offers both creating and joining, without scrolling', (
      tester,
    ) async {
      // Both halves were always here, stacked — and the join card sat below
      // the fold on a phone with nothing to say it existed, so somebody
      // holding an invite code saw only a form for making a garage.
      await pumpOnboarding(tester, RecordingHouseholdRepository());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('onboarding-choice')), findsOneWidget);
      expect(find.text('Create a garage'), findsWidgets);
      expect(find.text('Join with a code'), findsWidgets);
    });

    /// Switches onboarding to the join half.
    Future<void> chooseJoin(WidgetTester tester) async {
      await tester.tap(find.text('Join with a code').last);
      await tester.pumpAndSettle();
    }

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
      await chooseJoin(tester);

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
      await chooseJoin(tester);

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
