import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/links/url_opener.dart';
import 'package:garage/domain/entities/household.dart';
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

Future<NavigationLog> pumpSettings(
  WidgetTester tester, {
  RecordingHouseholdRepository? households,
  RecordingAuthRepository? auth,
  List<Uri>? opened,
}) {
  return pumpScreen(
    tester,
    const SettingsScreen(),
    initialLocation: '/settings',
    surface: const Size(400, 1600),
    extraRoutes: const {'/household', '/api', '/about'},
    overrides: [
      householdRepositoryProvider.overrideWithValue(
        households ?? RecordingHouseholdRepository(testHousehold),
      ),
      authRepositoryProvider.overrideWithValue(
        auth ?? RecordingAuthRepository(),
      ),
      urlOpenerProvider.overrideWithValue((url) async => opened?.add(url)),
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
}
