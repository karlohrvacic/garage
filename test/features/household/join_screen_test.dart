import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/domain/entities/household.dart';
import 'package:garage/domain/entities/invite.dart';
import 'package:garage/features/household/data/household_repository.dart';
import 'package:garage/features/household/providers/household_providers.dart';
import 'package:garage/features/household/providers/pending_invite.dart';
import 'package:garage/features/household/screens/join_screen.dart';

import '../../support/pump_screen.dart';

/// Records what an invite link asked the backend to do.
class RecordingHouseholdRepository implements HouseholdRepository {
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
}

Future<NavigationLog> pumpJoin(
  WidgetTester tester, {
  required RecordingHouseholdRepository repository,
  bool signedIn = true,
  Household? household,
  String code = 'ABC12345',
}) {
  return pumpScreen(
    tester,
    JoinScreen(code: code),
    initialLocation: '/join/$code',
    extraRoutes: const {'/', '/sign-in', '/sign-up'},
    userId: signedIn ? 'u1' : null,
    household: household,
    overrides: [householdRepositoryProvider.overrideWithValue(repository)],
  );
}

void main() {
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

  testWidgets('and the code survives the trip through sign-in', (tester) async {
    final repository = RecordingHouseholdRepository();
    await pumpJoin(tester, repository: repository, signedIn: false);
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(JoinScreen)),
    );

    expect(container.read(pendingInviteProvider), 'ABC12345');
  });

  // Joining a second household would land somewhere the app cannot show: the
  // rest of it reads whichever household comes back first. Saying so beats
  // appearing to work.
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
