import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/errors/app_failure.dart';
import 'package:garage/core/widgets/async_value_view.dart';
import 'package:garage/core/widgets/garage_tab_bar.dart';
import 'package:garage/domain/company/payment_method.dart';
import 'package:garage/domain/entities/cost_entry.dart';
import 'package:garage/domain/entities/fuel_entry.dart';
import 'package:garage/domain/entities/vehicle_assignment.dart';
import 'package:garage/features/company/providers/company_providers.dart';
import 'package:garage/features/company/screens/company_screen.dart';
import 'package:garage/features/costs/providers/cost_providers.dart';
import 'package:garage/features/household/data/household_repository.dart';
import 'package:garage/features/household/providers/member_providers.dart';
import 'package:garage/l10n/app_localizations.dart';

import '../../support/pump_screen.dart';
import '../../support/vehicle_entries.dart';
import 'company_providers_test.dart' show RecordingCompanyRepository;
import 'company_screen_test.dart' show company, people;

CostEntry parking(
  String id,
  DateTime on, {
  PaymentMethod? paidWith = PaymentMethod.ownMoney,
  DateTime? reimbursedAt,
}) {
  return CostEntry(
    id: id,
    vehicleId: 'v1',
    date: on,
    category: CostCategories.parking,
    amount: 12,
    createdBy: 'u2',
    paidWith: paidWith,
    reimbursedAt: reimbursedAt,
  );
}

FuelEntry fillUp(String id, DateTime on) {
  return FuelEntry(
    id: id,
    vehicleId: 'v1',
    date: on,
    odometerKm: 61000,
    volumeL: 40,
    total: 60,
    fullTank: true,
    missedFill: false,
    createdBy: 'u2',
    paidWith: PaymentMethod.ownMoney,
  );
}

CostEntry onTheSoldCar(String id, DateTime on) {
  return CostEntry(
    id: id,
    vehicleId: 'v2',
    date: on,
    category: CostCategories.wash,
    amount: 8,
    createdBy: 'u2',
    paidWith: PaymentMethod.ownMoney,
  );
}

Future<RecordingCompanyRepository> pumpReimbursements(
  WidgetTester tester, {
  required List<CostEntry> costs,
  List<FuelEntry> fuel = const [],

  /// Entries on the Passat, which was sold (archived) at the end of June.
  List<CostEntry> soldCarCosts = const [],
  AppFailure? failWith,

  /// Thrown by the first read of the Golf's costs, for a test about Retry:
  /// a first load with nothing cached to fall back on.
  AppFailure? firstCostReadFailsWith,

  /// Called on every read of the Golf's costs, for a test that asserts the
  /// list was refreshed.
  void Function()? onCostRead,
  List<HouseholdMember> members = people,

  /// Thrown by the first read of the members, for a test about a names
  /// read that fails with nothing cached.
  AppFailure? firstMembersReadFailsWith,
  Size surface = const Size(1400, 900),
  Locale? locale,
  double textScale = 1,
}) async {
  final repository = RecordingCompanyRepository(
    // Ana has had the Golf all year, and had the Passat until it was sold;
    // a day before either window belongs to nobody.
    fleet: [
      VehicleAssignment(
        id: 'a1',
        vehicleId: 'v1',
        userId: 'u2',
        fromDate: DateTime.utc(2026, 1, 1),
      ),
      VehicleAssignment(
        id: 'a2',
        vehicleId: 'v2',
        userId: 'u2',
        fromDate: DateTime.utc(2026, 1, 1),
        toDate: DateTime.utc(2026, 6, 30),
      ),
    ],
    failWith: failWith,
  );
  var costsRefused = false;
  var membersRefused = false;
  await pumpScreen(
    tester,
    const CompanyScreen(),
    initialLocation: '/company',
    surface: surface,
    locale: locale,
    textScale: textScale,
    household: company,
    vehicles: [
      testVehicle('v1', nickname: 'Golf'),
      testVehicle('v2', nickname: 'Passat', archived: true),
    ],
    overrides: [
      companyRepositoryProvider.overrideWithValue(repository),
      membersProvider.overrideWith((ref) async {
        if (firstMembersReadFailsWith case final failure?
            when !membersRefused) {
          membersRefused = true;
          throw failure;
        }
        return members;
      }),
      ...vehicleEntryOverrides('v1', costs: null, fuel: fuel),
      costEntriesProvider('v1').overrideWith((ref) async {
        onCostRead?.call();
        if (firstCostReadFailsWith case final failure? when !costsRefused) {
          costsRefused = true;
          throw failure;
        }
        return costs;
      }),
      ...vehicleEntryOverrides('v2', costs: soldCarCosts),
    ],
  );
  await tester.pumpAndSettle();
  // The tab, and not a sidebar link of the same name; on a narrow phone at
  // a large font the strip scrolls, so the tab is brought on screen first.
  final tab = find.descendant(
    of: find.byType(GarageTabBar),
    matching: find.text(
      lookupAppLocalizations(
        locale ?? const Locale('en'),
      ).companyTabReimbursements,
    ),
  );
  await tester.ensureVisible(tab);
  await tester.pumpAndSettle();
  await tester.tap(tab);
  await tester.pumpAndSettle();
  return repository;
}

/// Taps the line's button and confirms the question it asks.
Future<void> markPaid(WidgetTester tester, String line) async {
  await tester.tap(find.byKey(Key('mark-paid-$line')));
  await tester.pumpAndSettle();
  expect(find.textContaining('as paid to Ana?'), findsOneWidget);
  await tester.tap(find.byKey(const Key('mark-paid-confirm')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('what a driver is owed, per month, with one button', (
    tester,
  ) async {
    final repository = await pumpReimbursements(
      tester,
      costs: [
        parking('c1', DateTime.utc(2026, 9, 2)),
        parking('c2', DateTime.utc(2026, 9, 5)),
        parking(
          'card',
          DateTime.utc(2026, 9, 6),
          paidWith: PaymentMethod.companyCard,
        ),
        parking(
          'done',
          DateTime.utc(2026, 8, 6),
          reimbursedAt: DateTime.utc(2026, 9, 1),
        ),
      ],
    );

    expect(find.byKey(const Key('reimbursement-u2-2026-9')), findsOneWidget);
    expect(find.text('Ana'), findsOneWidget);
    expect(find.textContaining('24'), findsOneWidget);
    expect(find.textContaining('2 entries'), findsOneWidget);
    expect(find.byKey(const Key('reimbursement-u2-2026-8')), findsNothing);

    await markPaid(tester, 'u2-2026-9');

    expect(repository.calls, contains('reimbursed:cost_entries:c1,c2'));
    expect(find.text('Marked as paid'), findsOneWidget);
  });

  testWidgets('a month paid from two tables is stamped once per table', (
    tester,
  ) async {
    final repository = await pumpReimbursements(
      tester,
      costs: [parking('c1', DateTime.utc(2026, 9, 2))],
      fuel: [fillUp('f1', DateTime.utc(2026, 9, 3))],
    );

    expect(find.textContaining('72'), findsOneWidget);

    await markPaid(tester, 'u2-2026-9');

    expect(repository.calls, contains('reimbursed:cost_entries:c1'));
    expect(repository.calls, contains('reimbursed:fuel_entries:f1'));
  });

  testWidgets('a refused stamp leaves the line and says why', (tester) async {
    var costReads = 0;
    final repository = await pumpReimbursements(
      tester,
      costs: [parking('c1', DateTime.utc(2026, 9, 2))],
      failWith: const AppFailure(kind: AppFailureKind.permission),
      onCostRead: () => costReads++,
    );
    expect(costReads, 1);

    await markPaid(tester, 'u2-2026-9');

    expect(repository.calls, contains('reimbursed:cost_entries:c1'));
    expect(find.byKey(const Key('reimbursement-u2-2026-9')), findsOneWidget);
    expect(find.text('Marked as paid'), findsNothing);
    expect(find.textContaining('You do not have access'), findsOneWidget);
    // Refreshed all the same: a refusal part-way through a month paid from
    // two tables leaves the first table stamped, and the line has to show
    // what is still owed.
    expect(costReads, 2);
  });

  testWidgets('a car since sold still owes its driver', (tester) async {
    await pumpReimbursements(
      tester,
      costs: const [],
      soldCarCosts: [onTheSoldCar('w1', DateTime.utc(2026, 6, 10))],
    );

    expect(find.byKey(const Key('reimbursement-u2-2026-6')), findsOneWidget);
    expect(find.text('Ana'), findsOneWidget);
  });

  testWidgets('a driver who has since left is still owed, and named as one', (
    tester,
  ) async {
    await pumpReimbursements(
      tester,
      costs: [parking('c1', DateTime.utc(2026, 9, 2))],
      members: const [
        HouseholdMember(userId: 'u1', displayName: 'Karlo', role: 'admin'),
      ],
    );

    expect(find.byKey(const Key('reimbursement-u2-2026-9')), findsOneWidget);
    expect(find.text('Former member'), findsOneWidget);

    await tester.tap(find.byKey(const Key('mark-paid-u2-2026-9')));
    await tester.pumpAndSettle();

    expect(find.textContaining('as paid to Former member?'), findsOneWidget);
  });

  testWidgets('a first load that fails is retried from the leaves', (
    tester,
  ) async {
    await pumpReimbursements(
      tester,
      costs: [parking('c1', DateTime.utc(2026, 9, 2))],
      firstCostReadFailsWith: const AppFailure(kind: AppFailureKind.network),
    );

    expect(find.byKey(const Key('reimbursement-u2-2026-9')), findsNothing);
    expect(find.textContaining('No connection'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('reimbursement-u2-2026-9')), findsOneWidget);
  });

  testWidgets('a day nobody had the car is shown, and has nobody to pay', (
    tester,
  ) async {
    await pumpReimbursements(
      tester,
      costs: [parking('c1', DateTime.utc(2025, 12, 20))],
    );

    expect(
      find.byKey(const Key('reimbursement-nobody-2025-12')),
      findsOneWidget,
    );
    expect(find.text('No driver on those days'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.byKey(const Key('mark-paid-nobody-2025-12')),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('nothing owed says so, centred like every other empty tab', (
    tester,
  ) async {
    await pumpReimbursements(tester, costs: const []);

    expect(find.text('Nobody is owed anything.'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Center && widget.child is EmptyState,
      ),
      findsOneWidget,
    );
  });

  testWidgets('a names read that fails is said, not "Former member" on '
      'every line', (tester) async {
    // With the list unread, nobody is a departed member yet; the sentence
    // and the tab's Retry are what the failure gets.
    await pumpReimbursements(
      tester,
      costs: [parking('c1', DateTime.utc(2026, 9, 2))],
      firstMembersReadFailsWith: const AppFailure(
        kind: AppFailureKind.permission,
      ),
    );

    expect(find.textContaining('You do not have access'), findsOneWidget);
    expect(find.text('Former member'), findsNothing);
    expect(find.byKey(const Key('reimbursement-u2-2026-9')), findsNothing);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('reimbursement-u2-2026-9')), findsOneWidget);
    expect(find.text('Ana'), findsOneWidget);
  });

  testWidgets('in Croatian on a narrow phone at a large font', (tester) async {
    await pumpReimbursements(
      tester,
      costs: [
        parking('c1', DateTime.utc(2026, 9, 2)),
        parking('c0', DateTime.utc(2025, 12, 20)),
      ],
      surface: const Size(320, 2000),
      locale: const Locale('hr'),
      textScale: 1.5,
    );

    expect(tester.takeException(), isNull);
  });
}
