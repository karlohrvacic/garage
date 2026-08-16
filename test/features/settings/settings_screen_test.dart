import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/links/url_opener.dart';
import 'package:garage/domain/account/account_identity.dart';
import 'package:garage/domain/entities/household.dart';
import 'package:garage/domain/entities/vehicle.dart';
import 'package:garage/features/vehicles/data/vehicle_repository.dart';
import 'package:garage/domain/entities/invite.dart';
import 'package:garage/features/auth/data/auth_repository.dart';
import 'package:garage/features/auth/providers/auth_providers.dart';
import 'package:garage/features/household/data/household_repository.dart';
import 'package:garage/features/household/providers/household_providers.dart';
import 'package:garage/features/settings/screens/settings_screen.dart';
import 'package:garage/features/vehicles/providers/vehicle_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import '../../support/pump_screen.dart';

class RecordingHouseholdRepository implements HouseholdRepository {
  RecordingHouseholdRepository(this.household);

  Household household;
  final List<Household> saved = [];

  @override
  Future<List<Household>> myHouseholds() async => [household];

  @override
  Future<String> create(String name) async => 'h1';

  @override
  Future<String> joinWithCode(String code) async => 'h1';

  @override
  Future<String> createInvite(String householdId) async => 'ABCD2345';

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
  Future<void> updateSettings(Household household) async {
    saved.add(household);
    this.household = household;
  }

  @override
  Future<List<Invite>> invites(String householdId) async => const [];

  @override
  Future<void> revokeInvite(String inviteId) async {}
}

class RecordingAuthRepository implements AuthRepository {
  final List<String> calls = [];

  @override
  User? get currentUser => null;

  @override
  Future<void> signIn({required String email, required String password}) async {
    calls.add('signIn');
  }

  @override
  Future<void> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async => calls.add('signUp');

  @override
  Future<void> signInWithGoogle() async => calls.add('google');

  @override
  Future<void> signOut() async => calls.add('signOut');

  @override
  Future<void> sendPasswordReset(String email) async => calls.add('reset');

  @override
  Future<void> updatePassword(String newPassword) async =>
      calls.add('updatePassword');

  @override
  Future<void> deleteAccount() async => calls.add('deleteAccount');
}

class RecordingVehicleRepository implements VehicleRepository {
  final List<String> deletedHouseholds = [];

  @override
  Future<Vehicle> create(Vehicle vehicle) async => vehicle;

  @override
  Future<List<Vehicle>> forHousehold(String householdId) async => const [];

  @override
  Future<void> update(Vehicle vehicle) async {}

  @override
  Future<void> setArchived(String id, bool archived) async {}

  @override
  Future<void> deleteAllForHousehold(String householdId) async =>
      deletedHouseholds.add(householdId);
}

Future<NavigationLog> pumpSettings(
  WidgetTester tester, {
  RecordingHouseholdRepository? households,
  RecordingAuthRepository? auth,
  List<Uri>? opened,
  AccountIdentity? identity = const AccountIdentity(
    name: 'Karlo',
    email: 'karlo@example.com',
  ),
  RecordingVehicleRepository? vehicleRepository,
}) {
  return pumpScreen(
    tester,
    const SettingsScreen(),
    initialLocation: '/settings',
    surface: const Size(400, 1600),
    extraRoutes: const {'/household', '/api', '/about'},
    identity: identity,
    overrides: [
      householdRepositoryProvider.overrideWithValue(
        households ?? RecordingHouseholdRepository(testHousehold),
      ),
      authRepositoryProvider.overrideWithValue(
        auth ?? RecordingAuthRepository(),
      ),
      urlOpenerProvider.overrideWithValue((url) async => opened?.add(url)),
      vehicleRepositoryProvider.overrideWithValue(
        vehicleRepository ?? RecordingVehicleRepository(),
      ),
      vehiclesProvider.overrideWith((ref) async => const []),
      allVehiclesProvider.overrideWith((ref) async => const []),
    ],
  );
}

/// The settings list is long and lazily built, so a tile below the fold has to
/// be scrolled to before it can be tapped.
Future<void> tapSetting(WidgetTester tester, String label) async {
  final target = find.text(label);
  await tester.scrollUntilVisible(
    target,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('the household is reachable from the top', (tester) async {
    final log = await pumpSettings(tester);
    await tester.pumpAndSettle();

    await tapSetting(tester, 'Household');

    expect(log.visited, contains('/household'));
  });

  testWidgets('unit, currency, and bundling settings are offered', (
    tester,
  ) async {
    await pumpSettings(tester);
    await tester.pumpAndSettle();

    expect(find.text('Distance'), findsOneWidget);
    expect(find.text('Volume'), findsOneWidget);
    expect(find.text('Currency'), findsOneWidget);
    expect(find.textContaining('Group items within'), findsWidgets);
  });

  testWidgets('picking a theme persists it', (tester) async {
    await pumpSettings(tester);
    await tester.pumpAndSettle();

    await tapSetting(tester, 'Dark');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('theme_mode'), 'dark');
  });

  testWidgets('picking a language persists it', (tester) async {
    await pumpSettings(tester);
    await tester.pumpAndSettle();

    await tapSetting(tester, 'Hrvatski');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('locale_override'), 'hr');
  });

  testWidgets('signing out goes through the auth repository', (tester) async {
    final auth = RecordingAuthRepository();
    await pumpSettings(tester, auth: auth);
    await tester.pumpAndSettle();

    await tapSetting(tester, 'Sign out');

    expect(auth.calls, ['signOut']);
  });

  testWidgets('deleting the account asks first', (tester) async {
    final auth = RecordingAuthRepository();
    await pumpSettings(tester, auth: auth);
    await tester.pumpAndSettle();

    await tapSetting(tester, 'Delete account');

    expect(find.text('Delete your account?'), findsOneWidget);
    expect(auth.calls, isEmpty);
  });

  testWidgets('a cancelled account deletion deletes nothing', (tester) async {
    final auth = RecordingAuthRepository();
    await pumpSettings(tester, auth: auth);
    await tester.pumpAndSettle();

    await tapSetting(tester, 'Delete account');
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(auth.calls, isEmpty);
  });

  testWidgets('a confirmed account deletion goes through', (tester) async {
    final auth = RecordingAuthRepository();
    await pumpSettings(tester, auth: auth);
    await tester.pumpAndSettle();

    await tapSetting(tester, 'Delete account');
    await tester.tap(find.widgetWithText(FilledButton, 'Delete permanently'));
    await tester.pumpAndSettle();

    expect(auth.calls, ['deleteAccount']);
  });

  testWidgets('the detail level can be raised', (tester) async {
    final households = RecordingHouseholdRepository(testHousehold);
    await pumpSettings(tester, households: households);
    await tester.pumpAndSettle();

    await tapSetting(tester, 'Full');

    expect(households.saved.single.trackingLevel, 'advanced');
  });

  testWidgets('all three detail levels are offered', (tester) async {
    await pumpSettings(tester);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Full'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Basic'), findsOneWidget);
    expect(find.text('Detailed'), findsOneWidget);
    expect(find.text('Full'), findsOneWidget);
  });

  testWidgets('API access is reachable from settings', (tester) async {
    final log = await pumpSettings(tester);
    await tester.pumpAndSettle();

    await tapSetting(tester, 'API access');

    expect(log.visited, contains('/api'));
  });

  testWidgets('the privacy policy is linked, and opens the hosted page', (
    tester,
  ) async {
    final opened = <Uri>[];
    await pumpSettings(tester, opened: opened);
    await tester.pumpAndSettle();

    await tapSetting(tester, 'Privacy policy');

    expect(opened, [Uri.parse('https://garage.hrva.cc/privacy')]);
  });

  testWidgets('the About screen is reachable from settings', (tester) async {
    final log = await pumpSettings(tester);
    await tester.pumpAndSettle();

    await tapSetting(tester, 'About');

    expect(log.visited, contains('/about'));
  });

  testWidgets('settings says which account you are signed in as', (
    tester,
  ) async {
    await pumpSettings(tester);
    await tester.pumpAndSettle();

    expect(find.text('Karlo'), findsOneWidget);
    expect(
      find.text('karlo@example.com'),
      findsOneWidget,
      reason: 'the address is how you tell two accounts apart',
    );
  });

  testWidgets('a signed-out screen shows no account row', (tester) async {
    await pumpSettings(tester, identity: null);
    await tester.pumpAndSettle();

    expect(find.text('karlo@example.com'), findsNothing);
  });

  testWidgets('sign out sits on the account it signs out of', (tester) async {
    final auth = RecordingAuthRepository();
    await pumpSettings(tester, auth: auth);
    await tester.pumpAndSettle();

    // Without scrolling: the point is that it is visible with the account,
    // not buried under the units and theme sections.
    await tester.tap(find.widgetWithText(TextButton, 'Sign out'));
    await tester.pumpAndSettle();

    expect(auth.calls, contains('signOut'));
  });

  testWidgets('each section says what it changes', (tester) async {
    await pumpSettings(tester);
    await tester.pumpAndSettle();

    for (final explanation in [
      'How distances, volumes and prices are shown',
      'Items due close together are suggested as one visit',
      'Which registration and inspection items are offered',
    ]) {
      expect(
        find.text(explanation),
        findsOneWidget,
        reason: 'a setting nobody can interpret is a setting nobody changes',
      );
    }
  });

  testWidgets('each detail level says what it adds', (tester) async {
    await pumpSettings(tester);
    await tester.pumpAndSettle();

    expect(find.text('Date, odometer, what was done, what it cost'), findsOne);
    expect(find.text('Adds parts, labour, DIY and warranty'), findsOne);
    expect(
      find.text('Adds readings: pad thickness, tread depth, voltage'),
      findsOne,
    );
  });

  group('starting over', () {
    testWidgets('deleting all data asks first, then deletes', (tester) async {
      final vehicles = RecordingVehicleRepository();
      await pumpSettings(tester, vehicleRepository: vehicles);
      await tester.pumpAndSettle();

      await tapSetting(tester, 'Delete all data');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete permanently'));
      await tester.pumpAndSettle();

      expect(vehicles.deletedHouseholds, ['h1']);
    });

    testWidgets('changing your mind deletes nothing', (tester) async {
      final vehicles = RecordingVehicleRepository();
      await pumpSettings(tester, vehicleRepository: vehicles);
      await tester.pumpAndSettle();

      await tapSetting(tester, 'Delete all data');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(vehicles.deletedHouseholds, isEmpty);
    });
  });
}
