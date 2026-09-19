import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/misc.dart' show Override;
import 'package:garage/core/clock.dart';
import 'package:garage/core/errors/app_failure.dart';
import 'package:garage/core/widgets/garage_tab_bar.dart';
import 'package:garage/core/widgets/async_value_view.dart';
import 'package:garage/domain/entities/household.dart';
import 'package:garage/domain/entities/vehicle.dart';
import 'package:garage/domain/entities/vehicle_assignment.dart';
import 'package:garage/features/company/providers/company_providers.dart';
import 'package:garage/features/company/screens/company_screen.dart';
import 'package:garage/features/household/data/household_repository.dart';
import 'package:garage/features/household/providers/household_providers.dart';
import 'package:garage/features/household/providers/member_providers.dart';
import 'package:garage/features/vehicles/providers/vehicle_providers.dart';

import '../../support/fake_repositories.dart';
import '../../support/pump_screen.dart';
import '../../support/vehicle_entries.dart';
import '../household/household_screens_test.dart'
    show RecordingHouseholdRepository;
import 'company_providers_test.dart' show RecordingCompanyRepository, window;

const company = Household(id: 'h1', name: 'Prijevoz', plan: 'company');

const people = [
  HouseholdMember(userId: 'u1', displayName: 'Karlo', role: 'admin'),
  HouseholdMember(userId: 'u2', displayName: 'Ana', role: 'driver'),
  HouseholdMember(userId: 'u3', displayName: 'Ivo', role: 'driver'),
];

/// What the console wrote, leaving out the reads of the log it makes on the
/// way: the repository records both, and a test about a handover is about
/// the handover.
List<String> writesOf(RecordingCompanyRepository repository) => [
  for (final call in repository.calls)
    if (!call.startsWith('fleet:')) call,
];

/// The garage on screen, as something a test can switch while the console
/// is up.
class _Selected extends Notifier<Household> {
  _Selected(this.initial);

  final Household initial;

  @override
  Household build() => initial;

  void switchTo(Household household) => state = household;
}

/// The Settings tab, and not the sidebar's Settings link, which a desktop
/// window shows beside every console test.
final settingsTab = find.descendant(
  of: find.byType(GarageTabBar),
  matching: find.text('Settings'),
);

Future<RecordingCompanyRepository> pumpConsole(
  WidgetTester tester, {
  Household household = company,
  String role = 'admin',
  List<VehicleAssignment> fleet = const [],
  AppFailure? failWith,
  AppFailure? readFailsWith,
  AppFailure? membersFailWith,
  List<Override> overrides = const [],
  Size surface = const Size(1400, 900),
  Locale? locale,
  double textScale = 1,

  /// The garage's cars; the Golf and the Caddy unless a test says.
  List<Vehicle>? vehicles,
}) async {
  final repository = RecordingCompanyRepository(
    fleet: fleet,
    failWith: failWith,
    readFailsWith: readFailsWith,
  );
  await pumpScreen(
    tester,
    const CompanyScreen(),
    initialLocation: '/company',
    surface: surface,
    locale: locale,
    textScale: textScale,
    household: household,
    role: role,
    vehicles:
        vehicles ??
        [
          testVehicle('v1', nickname: 'Golf'),
          testVehicle('v2', nickname: 'Caddy'),
        ],
    overrides: [
      companyRepositoryProvider.overrideWithValue(repository),
      membersProvider.overrideWith((ref) async {
        if (membersFailWith case final failure?) {
          throw failure;
        }
        return people;
      }),
      ...overrides,
      ...vehicleEntryOverrides('v1'),
      ...vehicleEntryOverrides('v2'),
      currentOdometerProvider('v1').overrideWith((ref) async => 61000),
      currentOdometerProvider('v2').overrideWith((ref) async => 12000),
      // Pinned: the windows below are dated against this day, and a plan
      // that ends on 1 September has to have ended.
      todayProvider.overrideWithValue(DateTime(2026, 9, 19)),
      clockProvider.overrideWithValue(() => DateTime.utc(2026, 9, 19, 12)),
    ],
  );
  await tester.pumpAndSettle();
  return repository;
}

void main() {
  testWidgets('a car names its driver today, and one with none says so', (
    tester,
  ) async {
    await pumpConsole(
      tester,
      fleet: [window('a1', from: DateTime.utc(2026, 9, 1))],
    );

    expect(find.byKey(const Key('company-car-v1')), findsOneWidget);
    expect(find.textContaining('Driver: Ana'), findsOneWidget);
    expect(find.textContaining('Driver: Nobody'), findsOneWidget);
    expect(find.textContaining('not yet confirmed'), findsOneWidget);
  });

  testWidgets('a signed-off handover says when it was confirmed', (
    tester,
  ) async {
    await pumpConsole(
      tester,
      fleet: [
        window(
          'a1',
          from: DateTime.utc(2026, 9, 1),
          confirmedAt: DateTime.utc(2026, 9, 2, 8),
        ),
      ],
    );

    expect(find.textContaining('confirmed'), findsOneWidget);
    expect(find.textContaining('not yet confirmed'), findsNothing);
  });

  testWidgets('the drivers before this one are listed under the car', (
    tester,
  ) async {
    await pumpConsole(
      tester,
      fleet: [
        window('a2', from: DateTime.utc(2026, 9, 10)),
        window(
          'a1',
          userId: 'u3',
          from: DateTime.utc(2026, 8, 1),
          to: DateTime.utc(2026, 9, 9),
        ),
      ],
    );

    expect(find.text('EARLIER'), findsOneWidget);
    expect(find.textContaining('Ivo:'), findsOneWidget);
  });

  testWidgets('handing over asks who, when and at what reading', (
    tester,
  ) async {
    final repository = await pumpConsole(tester);

    await tester.tap(find.byKey(const Key('company-handover-v2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('handover-to')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ivo').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('handover-odometer')), '12345');
    await tester.enterText(
      find.byKey(const Key('handover-note')),
      'Keys in the office',
    );
    await tester.tap(find.byKey(const Key('handover-save')));
    await tester.pumpAndSettle();

    expect(writesOf(repository), ['handOver:v2:u3:12345']);
    expect(find.text('Handed over'), findsOneWidget);
  });

  testWidgets('the reading is prefilled with where the car stands', (
    tester,
  ) async {
    await pumpConsole(tester);

    await tester.tap(find.byKey(const Key('company-handover-v1')));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TextField>(find.byKey(const Key('handover-odometer')))
          .controller!
          .text,
      '61000',
    );
  });

  testWidgets('taking the car back hands it to nobody', (tester) async {
    final repository = await pumpConsole(
      tester,
      fleet: [window('a1', from: DateTime.utc(2026, 9, 1))],
    );

    await tester.tap(find.byKey(const Key('company-handover-v1')));
    await tester.pumpAndSettle();
    // Nobody is the default.
    await tester.tap(find.byKey(const Key('handover-save')));
    await tester.pumpAndSettle();

    expect(writesOf(repository), ['handOver:v1:-:61000']);
  });

  testWidgets('whoever has the car now is not offered it again', (
    tester,
  ) async {
    await pumpConsole(
      tester,
      fleet: [window('a1', from: DateTime.utc(2026, 9, 1))],
    );

    await tester.tap(find.byKey(const Key('company-handover-v1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('handover-to')));
    await tester.pumpAndSettle();

    expect(find.text('Ivo'), findsWidgets);
    expect(find.text('Ana'), findsNothing);
  });

  testWidgets('a refused handover keeps the sheet open and says why', (
    tester,
  ) async {
    final repository = await pumpConsole(
      tester,
      failWith: const AppFailure(kind: AppFailureKind.handoverClash),
    );

    await tester.tap(find.byKey(const Key('company-handover-v2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('handover-save')));
    await tester.pumpAndSettle();

    expect(writesOf(repository), ['handOver:v2:-:12000']);
    expect(find.byKey(const Key('handover-save')), findsOneWidget);
    expect(find.textContaining('already handed over'), findsOneWidget);
  });

  testWidgets('a lapsed plan can only take cars back', (tester) async {
    await pumpConsole(
      tester,
      household: Household(
        id: 'h1',
        name: 'Prijevoz',
        plan: 'company',
        planUntil: DateTime.utc(2026, 9, 1),
      ),
    );

    expect(find.byKey(const Key('company-plan-lapsed')), findsOneWidget);
    await tester.tap(find.byKey(const Key('company-handover-v1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('handover-to')));
    await tester.pumpAndSettle();

    expect(find.text('Ivo'), findsNothing);
  });

  testWidgets('a plan with no end shows no banner', (tester) async {
    await pumpConsole(tester);

    expect(find.byKey(const Key('company-plan-lapsed')), findsNothing);
  });

  testWidgets('an earlier driver can be struck from the log', (tester) async {
    final repository = await pumpConsole(
      tester,
      fleet: [window('a1', from: DateTime.utc(2026, 9, 1))],
    );

    await tester.tap(find.byKey(const Key('company-car-menu-v1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove from the log').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(writesOf(repository), ['delete:a1']);
    expect(find.text('Removed from the log'), findsOneWidget);
  });

  testWidgets('a handover arranged for next week is listed and can be undone', (
    tester,
  ) async {
    // Friday's arrangement for Monday, which closed Ana's window the day
    // before: she is still today's driver, Ivo's window is in the log, and
    // the menu removes the newest open one, which is the one made last and
    // the likelier mistake.
    final repository = await pumpConsole(
      tester,
      fleet: [
        window('a2', userId: 'u3', from: DateTime.utc(2026, 9, 22)),
        window(
          'a1',
          from: DateTime.utc(2026, 9, 1),
          to: DateTime.utc(2026, 9, 21),
        ),
      ],
    );

    expect(find.textContaining('Driver: Ana'), findsOneWidget);
    expect(find.textContaining('Ivo: from'), findsOneWidget);

    await tester.tap(find.byKey(const Key('company-car-menu-v1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove from the log').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('Ivo had the car'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(writesOf(repository), ['delete:a2']);
  });

  testWidgets('a car nobody has ever had offers no removal', (tester) async {
    await pumpConsole(tester);

    expect(find.byKey(const Key('company-car-menu-v1')), findsNothing);
  });

  testWidgets('a driver who has since left is named as one, not blank', (
    tester,
  ) async {
    // The window outlives the membership, and the member list no longer
    // has the name: "Driver: " with nothing after it read as a bug.
    await pumpConsole(
      tester,
      fleet: [
        window('a2', userId: 'gone', from: DateTime.utc(2026, 9, 10)),
        window(
          'a1',
          userId: 'left',
          from: DateTime.utc(2026, 8, 1),
          to: DateTime.utc(2026, 9, 9),
        ),
      ],
    );

    expect(find.textContaining('Driver: Former member'), findsOneWidget);
    expect(find.textContaining('Former member:'), findsOneWidget);
    expect(find.textContaining('Driver: \n'), findsNothing);
  });

  testWidgets('a garage with no cars says so like every other empty tab', (
    tester,
  ) async {
    await pumpConsole(tester, vehicles: const []);

    expect(find.textContaining('No cars yet'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Center && widget.child is EmptyState,
      ),
      findsOneWidget,
    );
  });

  group('a read that fails outright', () {
    // The cache serves last-good rows on a network failure only; a 42501 or
    // a server error on the first load has nothing to fall back on, and
    // "Nobody" on every car would be a wrong answer with the cause unlogged.
    const refused = AppFailure(
      kind: AppFailureKind.permission,
      debugMessage: '42501: permission denied for table vehicle_assignments',
    );

    testWidgets('the log: the console says so and names no driver', (
      tester,
    ) async {
      await pumpConsole(tester, readFailsWith: refused);

      expect(find.textContaining('You do not have access'), findsOneWidget);
      expect(find.textContaining('Nobody'), findsNothing);
      expect(find.byKey(const Key('company-car-v1')), findsOneWidget);
      expect(find.byKey(const Key('company-car-menu-v1')), findsNothing);
    });

    testWidgets('the log: a Retry under the sentence reads it again', (
      tester,
    ) async {
      // The log and the members are kept alive and never retried on their
      // own: switching tabs changed nothing, only a resume or a realtime
      // event did. Every other tab offers the fleet's Retry.
      final repository = await pumpConsole(
        tester,
        fleet: [window('a1', from: DateTime.utc(2026, 9, 1))],
        readFailsWith: refused,
      );
      expect(find.textContaining('Driver: Ana'), findsNothing);

      repository.readFailsWith = null;
      await tester.tap(find.widgetWithText(OutlinedButton, 'Retry'));
      await tester.pumpAndSettle();

      expect(find.textContaining('You do not have access'), findsNothing);
      expect(find.textContaining('Driver: Ana'), findsOneWidget);
    });

    testWidgets('the members: the rows name nobody a former member', (
      tester,
    ) async {
      // With the list unread, a name that is not in it is not a departed
      // member's; the sentence above the rows says what happened.
      await pumpConsole(
        tester,
        fleet: [window('a1', from: DateTime.utc(2026, 9, 1))],
        membersFailWith: refused,
      );

      expect(find.textContaining('You do not have access'), findsOneWidget);
      expect(find.textContaining('Former member'), findsNothing);
      expect(find.byKey(const Key('company-car-v1')), findsOneWidget);
    });

    testWidgets('the members: the sheet says so instead of "invite someone"', (
      tester,
    ) async {
      await pumpConsole(tester, membersFailWith: refused);

      await tester.tap(find.byKey(const Key('company-handover-v2')));
      await tester.pumpAndSettle();

      expect(find.textContaining('You do not have access'), findsWidgets);
      expect(find.textContaining('Nobody to hand it to'), findsNothing);
      // Taking the car back needs no member, so the sheet still saves.
      expect(find.byKey(const Key('handover-save')), findsOneWidget);
    });

    testWidgets('the log still loading shows progress, not an empty log', (
      tester,
    ) async {
      // Pumped by hand: a spinner never settles.
      final log = Completer<List<VehicleAssignment>>();
      await pumpScreen(
        tester,
        const CompanyScreen(),
        initialLocation: '/company',
        surface: const Size(1400, 900),
        household: company,
        vehicles: [testVehicle('v1', nickname: 'Golf')],
        overrides: [
          companyRepositoryProvider.overrideWithValue(
            RecordingCompanyRepository(),
          ),
          membersProvider.overrideWith((ref) async => people),
          fleetAssignmentsProvider.overrideWith((ref) => log.future),
          todayProvider.overrideWithValue(DateTime(2026, 9, 19)),
        ],
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.textContaining('Nobody'), findsNothing);

      log.complete([window('a1', from: DateTime.utc(2026, 9, 1))]);
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.textContaining('Driver: Ana'), findsOneWidget);
    });
  });

  group('removing a signed window', () {
    testWidgets('says the sign-off goes with it', (tester) async {
      await pumpConsole(
        tester,
        fleet: [
          window(
            'a1',
            from: DateTime.utc(2026, 9, 1),
            confirmedAt: DateTime.utc(2026, 9, 2, 8),
          ),
        ],
      );

      await tester.tap(find.byKey(const Key('company-car-menu-v1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove from the log').last);
      await tester.pumpAndSettle();

      expect(find.textContaining('sign-off'), findsOneWidget);
    });

    testWidgets('and says nothing of the kind for an unsigned one', (
      tester,
    ) async {
      await pumpConsole(
        tester,
        fleet: [window('a1', from: DateTime.utc(2026, 9, 1))],
      );

      await tester.tap(find.byKey(const Key('company-car-menu-v1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove from the log').last);
      await tester.pumpAndSettle();

      expect(find.textContaining('Ana had the car'), findsOneWidget);
      expect(find.textContaining('sign-off'), findsNothing);
    });
  });

  testWidgets('a cold start shows progress, not a refusal, until the garage '
      'is known', (tester) async {
    // Typed in by URL on the web, the console used to say "free plan" and
    // then "only an admin" for the frames before the bootstrap answered.
    final household = Completer<Household?>();
    await pumpScreen(
      tester,
      const CompanyScreen(),
      initialLocation: '/company',
      surface: const Size(1400, 900),
      household: company,
      householdFuture: household.future,
      vehicles: [testVehicle('v1', nickname: 'Golf')],
      overrides: [
        companyRepositoryProvider.overrideWithValue(
          RecordingCompanyRepository(),
        ),
        membersProvider.overrideWith((ref) async => people),
        ...vehicleEntryOverrides('v1'),
      ],
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.textContaining('free plan'), findsNothing);
    expect(find.textContaining('Only an admin'), findsNothing);

    household.complete(company);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('company-car-v1')), findsOneWidget);
  });

  testWidgets('a free garage is told what the console needs', (tester) async {
    await pumpConsole(tester, household: testHousehold);

    expect(find.textContaining('free plan'), findsOneWidget);
    expect(find.byKey(const Key('company-car-v1')), findsNothing);
  });

  testWidgets('a driver is told it is an admin\'s', (tester) async {
    await pumpConsole(tester, role: 'driver');

    expect(find.textContaining('Only an admin'), findsOneWidget);
    expect(find.byKey(const Key('company-car-v1')), findsNothing);
  });

  testWidgets('the settings save the letterhead and refuse a bad OIB', (
    tester,
  ) async {
    final households = RecordingHouseholdRepository(
      households: const [company],
    );
    await pumpScreen(
      tester,
      const CompanyScreen(),
      initialLocation: '/company',
      surface: const Size(1400, 900),
      household: company,
      overrides: [
        householdRepositoryProvider.overrideWithValue(households),
        companyRepositoryProvider.overrideWithValue(
          RecordingCompanyRepository(),
        ),
        membersProvider.overrideWith((ref) async => people),
      ],
    );
    await tester.pumpAndSettle();
    await tester.tap(settingsTab);
    await tester.pumpAndSettle();

    expect(find.text('On the company plan.'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('company-oib')), '123');
    await tester.tap(find.byKey(const Key('company-settings-save')));
    await tester.pumpAndSettle();
    expect(find.text('An OIB is eleven digits.'), findsOneWidget);
    expect(households.updated, isEmpty);

    await tester.enterText(
      find.byKey(const Key('company-name')),
      'Prijevoz d.o.o.',
    );
    await tester.enterText(find.byKey(const Key('company-oib')), '12345678901');
    await tester.tap(find.byKey(const Key('company-settings-save')));
    await tester.pumpAndSettle();
    expect(households.updated.single.companyName, 'Prijevoz d.o.o.');
    expect(households.updated.single.companyOib, '12345678901');
    expect(households.updated.single.plan, 'company');
    expect(find.text('Company details saved'), findsOneWidget);
    expect(find.text('An OIB is eleven digits.'), findsNothing);
  });

  testWidgets('the OIB field takes digits and nothing else', (tester) async {
    await pumpConsole(tester);
    await tester.tap(settingsTab);
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('company-oib')), '12a34-5');

    expect(
      tester
          .widget<TextField>(find.byKey(const Key('company-oib')))
          .controller!
          .text,
      '12345',
    );
  });

  testWidgets('switching garage while the console is open reseeds the '
      'letterhead', (tester) async {
    const prijevoz = Household(
      id: 'h1',
      name: 'Prijevoz',
      plan: 'company',
      companyName: 'Prijevoz d.o.o.',
    );
    const dostava = Household(
      id: 'h2',
      name: 'Dostava',
      plan: 'company',
      companyName: 'Dostava d.o.o.',
    );
    final selected = NotifierProvider<_Selected, Household>(
      () => _Selected(prijevoz),
    );
    await pumpScreen(
      tester,
      const CompanyScreen(),
      initialLocation: '/company',
      surface: const Size(1400, 900),
      household: prijevoz,
      householdFrom: (ref) async => ref.watch(selected),
      bootstrap: FakeGarageBootstrapRepository(
        households: const [prijevoz, dostava],
        roles: const {'h1': 'admin', 'h2': 'admin'},
      ),
      overrides: [
        companyRepositoryProvider.overrideWithValue(
          RecordingCompanyRepository(),
        ),
        membersProvider.overrideWith((ref) async => people),
      ],
    );
    await tester.pumpAndSettle();
    await tester.tap(settingsTab);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('company-name')))
          .controller!
          .text,
      'Prijevoz d.o.o.',
    );

    final container = ProviderScope.containerOf(
      tester.element(find.byType(CompanyScreen)),
    );
    container.read(selected.notifier).switchTo(dostava);
    await tester.pumpAndSettle();
    await tester.tap(settingsTab);
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TextField>(find.byKey(const Key('company-name')))
          .controller!
          .text,
      'Dostava d.o.o.',
    );
  });

  testWidgets('the settings say until when the plan runs', (tester) async {
    await pumpConsole(
      tester,
      household: Household(
        id: 'h1',
        name: 'Prijevoz',
        plan: 'company',
        planUntil: DateTime.utc(2027, 1, 1, 12),
      ),
    );
    await tester.tap(settingsTab);
    await tester.pumpAndSettle();

    expect(find.textContaining('On the company plan until'), findsOneWidget);
  });

  testWidgets('in Croatian on a narrow phone the console and the sheet lay '
      'out', (tester) async {
    await pumpConsole(
      tester,
      fleet: [
        window('a2', from: DateTime.utc(2026, 9, 10)),
        window(
          'a1',
          userId: 'u3',
          from: DateTime.utc(2026, 8, 1),
          to: DateTime.utc(2026, 9, 9),
        ),
      ],
      surface: const Size(320, 2400),
      locale: const Locale('hr'),
      textScale: 1.5,
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('company-handover-v2')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('handover-to')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('in Croatian on a narrow phone the settings lay out', (
    tester,
  ) async {
    await pumpConsole(
      tester,
      surface: const Size(320, 2400),
      locale: const Locale('hr'),
      textScale: 1.5,
    );
    // Two tabs at 1.5x on 320 pixels is more than the strip's share, so it
    // scrolls, which is the point of GarageTabBar: the second tab is off
    // the right edge until the strip is scrolled, not cut in half.
    final tab = find.descendant(
      of: find.byType(GarageTabBar),
      matching: find.text('Postavke'),
    );
    await tester.ensureVisible(tab);
    await tester.pumpAndSettle();
    await tester.tap(tab);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('company-settings-save')), findsOneWidget);
  });
}
