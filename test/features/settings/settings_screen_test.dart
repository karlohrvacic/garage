import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/features/stations/providers/station_providers.dart';
import 'package:garage/domain/auth/email_link.dart';
import 'package:garage/core/links/url_opener.dart';
import 'package:garage/domain/account/account_identity.dart';
import 'package:garage/domain/entities/household.dart';
import 'package:garage/domain/entities/vehicle.dart';
import 'package:garage/domain/entities/vehicle_transfer.dart';
import 'package:garage/features/vehicles/data/vehicle_repository.dart';
import 'package:garage/domain/entities/invite.dart';
import 'package:garage/features/auth/data/auth_repository.dart';
import 'package:garage/features/auth/providers/auth_providers.dart';
import 'package:garage/features/household/data/household_repository.dart';
import 'package:garage/features/household/providers/household_providers.dart';
import 'package:garage/features/settings/screens/settings_screen.dart';
import 'package:garage/core/notifications/notification_providers.dart';
import 'package:garage/features/vehicles/providers/vehicle_providers.dart';
import 'package:garage/core/format/unit_format.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import '../../support/pump_screen.dart';

class RecordingHouseholdRepository implements HouseholdRepository {
  @override
  Future<void> deleteHousehold(String householdId) async {}

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

class RecordingAuthRepository implements AuthRepository {
  final List<String> calls = [];

  @override
  User? get currentUser => null;

  @override
  Future<void> signIn({required String email, required String password}) async {
    calls.add('signIn');
  }

  @override
  Future<bool> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    calls.add('signUp');
    return false;
  }

  @override
  Future<void> signInWithGoogle() async => calls.add('google');

  @override
  Future<void> signOut() async => calls.add('signOut');

  @override
  Future<void> confirmEmailLink(EmailLink link) async =>
      calls.add('confirmEmailLink:${link.purpose.name}');

  @override
  Future<void> sendPasswordReset(String email) async => calls.add('reset');

  @override
  Future<void> updateDisplayName(String name) async =>
      calls.add('updateDisplayName:$name');

  @override
  Future<void> updatePassword(String newPassword) async =>
      calls.add('updatePassword');

  @override
  Future<void> deleteAccount() async => calls.add('deleteAccount');
}

class RecordingVehicleRepository implements VehicleRepository {
  @override
  Future<List<VehicleTransfer>> transfersOffered(String householdId) async =>
      const [];

  @override
  Future<void> delete(String id) async {}

  @override
  Future<void> cancelTransfer(String vehicleId) async {}

  @override
  Future<String?> outstandingTransferCode(String vehicleId) async => null;

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

  @override
  Future<String> offerTransfer(String vehicleId) async => 'TRANSFER';

  @override
  Future<String> redeemTransfer({
    required String code,
    required String householdId,
  }) async => 'v1';
}

Future<NavigationLog> pumpSettings(
  WidgetTester tester, {
  bool locationGranted = false,
  RecordingHouseholdRepository? households,
  RecordingAuthRepository? auth,
  List<Uri>? opened,
  AccountIdentity? identity = const AccountIdentity(
    name: 'Karlo',
    email: 'karlo@example.com',
  ),
  RecordingVehicleRepository? vehicleRepository,
  bool pushActive = false,
  UnitPreferences preferences = metricPreferences,
}) {
  return pumpScreen(
    tester,
    const SettingsScreen(),
    initialLocation: '/settings',
    surface: const Size(400, 1600),
    preferences: preferences,
    extraRoutes: const {
      '/household',
      '/api',
      '/about',
      // The rest of the "More" section.
      '/stats',
      '/trips',
      '/stations',
      '/calculator',
    },
    identity: identity,
    overrides: [
      locationGrantedStateProvider.overrideWith((ref) async => locationGranted),
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
      pushRemindersActiveProvider.overrideWithValue(pushActive),
    ],
  );
}

/// The settings list is long and lazily built, so a tile below the fold has to
/// be scrolled to before it can be tapped.
Future<void> tapSetting(WidgetTester tester, String label) async {
  await scrollTo(tester, label);
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

Future<void> scrollTo(WidgetTester tester, String label) async {
  await tester.scrollUntilVisible(
    find.text(label),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('settings say who a reminder actually reaches', (tester) async {
    // Local notifications live on the phone that scheduled them, so a member
    // who did not set one up never hears about it. That was true and unsaid.
    await pumpSettings(tester);
    await tester.pumpAndSettle();

    await scrollTo(tester, 'Only this device is notified');

    expect(find.textContaining('Each phone schedules its own'), findsOneWidget);
  });

  testWidgets('with push on, it says the whole garage is notified', (
    tester,
  ) async {
    await pumpSettings(tester, pushActive: true);
    await tester.pumpAndSettle();

    await scrollTo(tester, 'Everyone in this garage is notified');

    expect(find.textContaining('sent from the server'), findsOneWidget);
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
    await tester.pumpAndSettle();
    // The garage's name, typed: the one action with no recovery asked for a
    // single tap on the button every save uses.
    await tester.enterText(find.byType(TextField).last, 'Test');
    await tester.tap(find.widgetWithText(FilledButton, 'Delete permanently'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete permanently'));
    await tester.pumpAndSettle();

    expect(auth.calls, ['deleteAccount']);
  });

  testWidgets('the wrong name does not delete the account', (tester) async {
    final auth = RecordingAuthRepository();
    await pumpSettings(tester, auth: auth);
    await tester.pumpAndSettle();

    await tapSetting(tester, 'Delete account');
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Not it');
    await tester.tap(find.widgetWithText(FilledButton, 'Delete permanently'));
    await tester.pumpAndSettle();

    // In the dialog, which stays open: answered after it was dismissed, a
    // typo meant reopening it and typing the name again.
    expect(find.text('That is not the garage name.'), findsOneWidget);
    expect(find.byType(TextField), findsWidgets);
    expect(auth.calls, isEmpty);
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

  testWidgets('your own name can be changed', (tester) async {
    // It was set once at sign-up and then fixed forever — and it is not a
    // private label: it is what the rest of the garage sees against every
    // entry you log.
    final auth = RecordingAuthRepository();
    await pumpSettings(tester, auth: auth);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Karlo'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('your-name')), 'Karlo H.');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(auth.calls, contains('updateDisplayName:Karlo H.'));
  });

  testWidgets('and changing it to the same thing asks nothing of the server', (
    tester,
  ) async {
    final auth = RecordingAuthRepository();
    await pumpSettings(tester, auth: auth);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Karlo'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(auth.calls.where((c) => c.startsWith('updateDisplayName')), isEmpty);
  });

  testWidgets('the settlement is offered, and off until asked for', (
    tester,
  ) async {
    final households = RecordingHouseholdRepository(testHousehold);
    await pumpSettings(tester, households: households);
    await tester.pumpAndSettle();

    final toggle = find.byKey(const Key('settlement-enabled'));
    await tester.scrollUntilVisible(
      toggle,
      200,
      scrollable: find.byType(Scrollable).first,
    );

    expect(tester.widget<SwitchListTile>(toggle).value, isFalse);

    await tester.tap(toggle);
    await tester.pumpAndSettle();

    expect(households.saved.last.settlementEnabled, isTrue);
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
      await tester.scrollUntilVisible(
        find.text(explanation),
        200,
        scrollable: find.byType(Scrollable).first,
      );
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

    // Settings is a long lazy list; the tracking levels sit well down it.
    await tester.scrollUntilVisible(
      find.text('Date, odometer, what was done, what it cost'),
      200,
    );

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

  // "Group items within (distance)" names no unit on purpose, and the stepper
  // beside it rendered a bare `$value` — so a household reading miles was
  // shown 500 and setting five hundred *kilometres*, with nothing on screen
  // that could have told them.
  group('the bundling distance', () {
    const inMiles = UnitPreferences(
      distance: DistanceUnit.mi,
      volume: VolumeUnit.usGallon,
      currencyCode: 'USD',
    );

    testWidgets('says which unit it is in', (tester) async {
      await pumpSettings(tester);
      await scrollTo(tester, 'Group items within (distance)');

      expect(find.text('500 km'), findsOneWidget);
    });

    testWidgets('and converts for a household that reads miles', (
      tester,
    ) async {
      await pumpSettings(tester, preferences: inMiles);
      await scrollTo(tester, 'Group items within (distance)');

      // 500 km is 311 miles. A bare "500" here would be five hundred of
      // whichever unit the reader assumed.
      expect(find.text('311 mi'), findsOneWidget);
      expect(find.text('500'), findsNothing);
    });

    // Stepping in kilometres under a miles reader would walk 311, 373, 435 —
    // arithmetic nobody asked for. The step belongs in the unit on screen.
    testWidgets('steps in the unit on screen', (tester) async {
      final households = RecordingHouseholdRepository(testHousehold);
      await pumpSettings(tester, households: households, preferences: inMiles);
      await scrollTo(tester, 'Group items within (distance)');

      final row = find.ancestor(
        of: find.text('311 mi'),
        matching: find.byType(Row),
      );
      await tester.tap(
        find.descendant(of: row.first, matching: find.byIcon(Icons.add)),
      );
      await tester.pumpAndSettle();

      // Asserted on what was stored rather than on what is drawn: the fake
      // repository records the write without re-emitting the household, so
      // the tile keeps showing the old figure in this harness.
      //
      // 411 miles is 661 km. A step in storage units would have written 600.
      expect(households.saved.last.bundlingWindowKm, 661);
    });
  });

  testWidgets('offers to fill in the station and price, under fill-ups', (
    tester,
  ) async {
    // The location permission sat under "Your data", among import and backup,
    // which is not where anyone looks for how a fill-up behaves.
    await pumpSettings(tester);
    await tester.pumpAndSettle();

    final heading = find.text('FILL-UPS');
    await tester.scrollUntilVisible(
      heading,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(heading, findsOneWidget);
    expect(find.text('Fill in the station and price for me'), findsOneWidget);
  });

  group('the pump-autofill row', () {
    // Moved here from Your data. Once permission is granted there is nothing
    // left to do, and the row must say so without greying itself out: a
    // disabled tile reads "On" in the colour used for "unavailable".
    testWidgets('does not grey itself out once it is on', (tester) async {
      await pumpSettings(tester, locationGranted: true);
      await tester.pumpAndSettle();

      final row = find.widgetWithText(
        ListTile,
        'Fill in the station and price for me',
      );
      await tester.scrollUntilVisible(
        row,
        200,
        scrollable: find.byType(Scrollable).first,
      );

      expect(tester.widget<ListTile>(row).enabled, isTrue);
      expect(tester.widget<ListTile>(row).onTap, isNull);
    });

    testWidgets('is tappable while it is off', (tester) async {
      await pumpSettings(tester);
      await tester.pumpAndSettle();

      final row = find.widgetWithText(
        ListTile,
        'Fill in the station and price for me',
      );
      await tester.scrollUntilVisible(
        row,
        200,
        scrollable: find.byType(Scrollable).first,
      );

      expect(tester.widget<ListTile>(row).onTap, isNotNull);
    });
  });
}
