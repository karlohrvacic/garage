import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/domain/entities/code_description.dart';
import 'package:garage/domain/entities/guest_pass.dart';
import 'package:garage/domain/entities/household.dart';
import 'package:garage/domain/entities/invite.dart';
import 'package:garage/domain/entities/service_entry.dart';
import 'package:garage/domain/entities/vehicle_briefing.dart';
import 'package:garage/features/household/data/household_repository.dart';
import 'package:garage/features/household/providers/household_providers.dart';
import 'package:garage/features/household/providers/pending_invite.dart';
import 'package:garage/features/household/screens/join_screen.dart';
import 'package:garage/features/vehicles/data/guest_pass_repository.dart';
import 'package:garage/features/vehicles/providers/guest_pass_providers.dart';

import '../../support/pump_screen.dart';

/// Records what an invite link asked the backend to do.
class RecordingHouseholdRepository implements HouseholdRepository {
  @override
  Future<void> deleteHousehold(String householdId) async {}

  RecordingHouseholdRepository({this.onJoin});

  final Future<void> Function(String code)? onJoin;
  final List<String> joined = [];

  @override
  Future<List<Household>> myHouseholds() async => const [];

  @override
  Future<String> create(String name) async => 'h-new';

  @override
  Future<String> joinWithCode(String code) async {
    joined.add(code);
    await onJoin?.call(code);
    return 'h-joined';
  }

  @override
  Future<String> createInvite(String householdId) async => 'ABC12345';

  @override
  Future<List<Invite>> invites(String householdId) async => const [];

  @override
  Future<void> revokeInvite(String inviteId) async {}

  @override
  Future<List<HouseholdMember>> members(String householdId) async => const [];

  @override
  Future<void> leave(String householdId) async {}

  @override
  Future<void> removeMember({
    required String householdId,
    required String userId,
  }) async {}

  @override
  Future<void> updateSettings(Household household) async {}

  @override
  Future<void> setRole({
    required String householdId,
    required String userId,
    required String role,
  }) async {}

  @override
  Future<MergeOutcome> merge({
    required String absorbedHouseholdId,
    required String survivingHouseholdId,
  }) async {
    return const MergeOutcome(
      vehiclesMoved: 0,
      membersMoved: 0,
      keysRevoked: 0,
    );
  }
}

/// Answers "what is this code?" the way the backend would, without a backend.
/// Only `describe` matters to the join screen; the rest is the interface.
class DescribingGuestPassRepository implements GuestPassRepository {
  DescribingGuestPassRepository({this.describes});

  final CodeDescription? describes;
  final List<String> described = [];

  @override
  Future<CodeDescription?> describe(String code) async {
    described.add(code);
    return describes;
  }

  @override
  Future<List<GuestPass>> forVehicle(String vehicleId) async => const [];

  @override
  Future<List<GuestPass>> mine() async => const [];

  @override
  Future<String> create({
    required String vehicleId,
    required DateTime endsAt,
    DateTime? startsAt,
    String? label,
    bool canLogFuel = true,
    bool canLogTrips = true,
    bool canLogCosts = false,
    bool canViewHistory = false,
    bool canViewPrices = false,
  }) async => 'WXYZ7788';

  @override
  Future<void> extend(String id, DateTime endsAt) async {}

  @override
  Future<void> revoke(String id) async {}

  @override
  Future<void> giveBack(String id) async {}

  @override
  Future<String> redeem(String code) async => 'v1';

  @override
  Future<void> updatePermissions(GuestPass pass) async {}

  @override
  Future<List<ServiceEntry>> serviceHistory(String vehicleId) async => const [];

  @override
  Future<VehicleBriefing?> briefing(String vehicleId) async => null;
}

CodeDescription inviteTo(String garage, {bool member = false}) {
  return CodeDescription(
    kind: CodeKind.invite,
    subject: garage,
    until: DateTime.now().toUtc().add(const Duration(days: 7)),
    spent: false,
    member: member,
  );
}

Future<NavigationLog> pumpJoin(
  WidgetTester tester, {
  required RecordingHouseholdRepository repository,
  bool signedIn = true,
  Household? household,
  String code = 'ABC12345',
  CodeDescription? describes,
  DescribingGuestPassRepository? codes,
}) {
  return pumpScreen(
    tester,
    JoinScreen(code: code),
    initialLocation: '/join/$code',
    extraRoutes: const {'/', '/sign-in', '/sign-up'},
    userId: signedIn ? 'u1' : null,
    household: household,
    overrides: [
      householdRepositoryProvider.overrideWithValue(repository),
      guestPassRepositoryProvider.overrideWithValue(
        codes ??
            DescribingGuestPassRepository(
              describes: describes ?? inviteTo('Efficlordic'),
            ),
      ),
    ],
  );
}

void main() {
  // Which garage this device is showing is a stored preference, so the
  // provider that reads it needs a store even in a test that never switches.
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // The person opening an invite has, by definition, no household yet, and
  // often no account. Making them read a code out of the link and retype it
  // into onboarding is exactly what the link was supposed to remove.
  testWidgets('a signed-in visitor with no household joins on arrival', (
    tester,
  ) async {
    final repository = RecordingHouseholdRepository();
    await pumpJoin(tester, repository: repository, household: null);
    await tester.pumpAndSettle();

    expect(repository.joined, ['ABC12345']);
  });

  testWidgets('the code is upper-cased, as the backend expects', (
    tester,
  ) async {
    final repository = RecordingHouseholdRepository();
    await pumpJoin(
      tester,
      repository: repository,
      household: null,
      code: 'abc12345',
    );
    await tester.pumpAndSettle();

    expect(repository.joined, ['ABC12345']);
  });

  testWidgets('a signed-out visitor is asked to sign in, not turned away', (
    tester,
  ) async {
    final repository = RecordingHouseholdRepository();
    await pumpJoin(tester, repository: repository, signedIn: false);
    await tester.pumpAndSettle();

    expect(repository.joined, isEmpty);
    expect(find.text('Create account'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });

  // A link tapped on a cold start builds this screen before supabase_flutter
  // has restored the session, so the first frame is signed out. `/join` sits
  // outside both gates, so nothing navigates away and rebuilds it when the
  // session lands — this screen is still the one on screen, and it has to
  // notice. Deciding only once, in initState, left it spinning "joining" for
  // good over an invite it had never even described.
  testWidgets('a session that arrives after the first frame is not missed', (
    tester,
  ) async {
    final repository = RecordingHouseholdRepository();
    await pumpJoin(tester, repository: repository, signedIn: false);
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(JoinScreen)),
    );
    container.read(testUserIdProvider.notifier).signIn('u1');
    await tester.pumpAndSettle();

    expect(repository.joined, ['ABC12345']);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('and the code survives the trip through sign-in', (tester) async {
    final repository = RecordingHouseholdRepository();
    await pumpJoin(tester, repository: repository, signedIn: false);
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(JoinScreen)),
    );

    expect(container.read(pendingInviteProvider), 'ABC12345');
  });

  // Opening a link out of curiosity must not move somebody into another
  // garage, so a visitor already in one is offered the join rather than
  // given it.
  testWidgets('a visitor already in a household is told, and nothing is run', (
    tester,
  ) async {
    final repository = RecordingHouseholdRepository();
    await pumpJoin(
      tester,
      repository: repository,
      household: const Household(id: 'h1', name: 'Hrvacic'),
    );
    await tester.pumpAndSettle();

    expect(repository.joined, isEmpty);
    expect(find.textContaining('Hrvacic'), findsOneWidget);
  });

  // The sentence used to name only the garage the visitor was already in, and
  // a friend opening a link for "Efficlordic" read "You are already in
  // Shrekova jazbina" as the link having put them in the wrong place. The
  // invite is for a garage, and the screen has to say which.
  testWidgets(
    'the invite names the garage it is for, not only the current one',
    (tester) async {
      final repository = RecordingHouseholdRepository();
      await pumpJoin(
        tester,
        repository: repository,
        household: const Household(id: 'h1', name: 'Hrvacic'),
        describes: inviteTo('Efficlordic'),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Efficlordic'), findsOneWidget);
      expect(find.textContaining('Hrvacic'), findsOneWidget);
      expect(find.text('Join'), findsOneWidget);
    },
  );

  // The same link opened twice: the second time the visitor is a member of
  // the garage it is for. The backend would accept the join and change
  // nothing, and the screen used to celebrate that as "You are in".
  testWidgets(
    'somebody already in the invited garage is not offered it again',
    (tester) async {
      final repository = RecordingHouseholdRepository();
      await pumpJoin(
        tester,
        repository: repository,
        household: const Household(id: 'h2', name: 'Efficlordic'),
        describes: inviteTo('Efficlordic', member: true),
      );
      await tester.pumpAndSettle();

      expect(repository.joined, isEmpty);
      expect(find.text('Join'), findsNothing);
      expect(find.textContaining('already'), findsOneWidget);
      expect(find.text('Open my garage'), findsOneWidget);
    },
  );

  testWidgets('a member with no garage selected is not joined on arrival', (
    tester,
  ) async {
    final repository = RecordingHouseholdRepository();
    await pumpJoin(
      tester,
      repository: repository,
      household: null,
      describes: inviteTo('Efficlordic', member: true),
    );
    await tester.pumpAndSettle();

    expect(repository.joined, isEmpty);
    expect(find.text('Open my garage'), findsOneWidget);
  });

  testWidgets('a code nobody issued is refused before anything is run', (
    tester,
  ) async {
    final repository = RecordingHouseholdRepository();
    await pumpJoin(
      tester,
      repository: repository,
      household: null,
      codes: DescribingGuestPassRepository(describes: null),
    );
    await tester.pumpAndSettle();

    expect(repository.joined, isEmpty);
    expect(find.text('Join'), findsNothing);
    expect(find.textContaining('No code like that'), findsOneWidget);
  });

  testWidgets('a spent invite is refused, not attempted', (tester) async {
    final repository = RecordingHouseholdRepository();
    final spent = CodeDescription(
      kind: CodeKind.invite,
      subject: 'Efficlordic',
      until: DateTime.now().toUtc().subtract(const Duration(days: 1)),
      spent: true,
    );
    await pumpJoin(
      tester,
      repository: repository,
      household: null,
      describes: spent,
    );
    await tester.pumpAndSettle();

    expect(repository.joined, isEmpty);
    expect(find.textContaining('already been used'), findsOneWidget);
  });

  testWidgets('a signed-out visitor is not asked what the code is', (
    tester,
  ) async {
    final codes = DescribingGuestPassRepository(describes: inviteTo('X'));
    await pumpJoin(
      tester,
      repository: RecordingHouseholdRepository(),
      signedIn: false,
      codes: codes,
    );
    await tester.pumpAndSettle();

    expect(codes.described, isEmpty);
  });

  // Croatian runs a third longer than English and this is the screen's
  // longest sentence, on the narrowest phone, at the largest common scale.
  testWidgets('the two-garage sentence fits in Croatian at 320px and 1.5x', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      const JoinScreen(code: 'ABC12345'),
      initialLocation: '/join/ABC12345',
      extraRoutes: const {'/', '/sign-in', '/sign-up'},
      household: const Household(id: 'h1', name: 'Shrekova jazbina'),
      locale: const Locale('hr'),
      surface: const Size(320, 640),
      textScale: 1.5,
      overrides: [
        householdRepositoryProvider.overrideWithValue(
          RecordingHouseholdRepository(),
        ),
        guestPassRepositoryProvider.overrideWithValue(
          DescribingGuestPassRepository(describes: inviteTo('Efficlordic')),
        ),
      ],
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Efficlordic'), findsOneWidget);
  });

  testWidgets('a code the backend refuses is explained, not swallowed', (
    tester,
  ) async {
    final repository = RecordingHouseholdRepository(
      onJoin: (_) async => throw Exception('PGRST-invite-expired'),
    );
    await pumpJoin(tester, repository: repository, household: null);
    await tester.pumpAndSettle();

    expect(find.textContaining('went wrong'), findsOneWidget);
  });
}
