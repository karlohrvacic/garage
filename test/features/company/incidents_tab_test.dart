import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/errors/app_failure.dart';
import 'package:garage/core/widgets/garage_tab_bar.dart';
import 'package:garage/domain/entities/incident.dart';
import 'package:garage/domain/entities/vehicle_assignment.dart';
import 'package:garage/features/company/providers/company_providers.dart';
import 'package:garage/features/company/screens/company_screen.dart';
import 'package:garage/features/household/providers/member_providers.dart';
import 'package:garage/features/incidents/providers/incident_providers.dart';
import 'package:garage/l10n/app_localizations.dart';

import '../../support/pump_screen.dart';
import '../incidents/incidents_card_test.dart'
    show RecordingIncidents, reported;
import 'company_providers_test.dart' show RecordingCompanyRepository;
import 'company_screen_test.dart' show company, people;

/// Refuses the first read, as a policy would, and answers the next.
class _RefusedOnce extends RecordingIncidents {
  _RefusedOnce({super.stored});

  bool refused = false;

  @override
  Future<List<Incident>> forVehicle(String vehicleId) async {
    if (!refused) {
      refused = true;
      throw const AppFailure(kind: AppFailureKind.permission);
    }
    return stored;
  }
}

/// Answers each car with its own reports, the way the table does.
class _PerCar extends RecordingIncidents {
  _PerCar({super.stored});

  @override
  Future<List<Incident>> forVehicle(String vehicleId) async => [
    for (final incident in stored)
      if (incident.vehicleId == vehicleId) incident,
  ];
}

Future<void> pumpIncidents(
  WidgetTester tester, {
  required List<Incident> incidents,
  RecordingIncidents? repository,

  /// Thrown by the read of the log, for a test about a driver line that
  /// must not claim anything while the log is unknown.
  AppFailure? logFailsWith,

  /// A second car, sold: its reports are still the fleet's.
  bool withArchivedCar = false,
  Size surface = const Size(1400, 900),
  Locale? locale,
  double textScale = 1,
}) async {
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
      if (withArchivedCar)
        testVehicle('v2', nickname: 'Passat', archived: true),
    ],
    overrides: [
      companyRepositoryProvider.overrideWithValue(
        RecordingCompanyRepository(
          // Ana has had the Golf all year; a day before that belongs to
          // nobody.
          fleet: [
            VehicleAssignment(
              id: 'a1',
              vehicleId: 'v1',
              userId: 'u2',
              fromDate: DateTime.utc(2026, 1, 1),
            ),
          ],
          readFailsWith: logFailsWith,
        ),
      ),
      membersProvider.overrideWith((ref) async => people),
      incidentRepositoryProvider.overrideWithValue(
        repository ?? RecordingIncidents(stored: incidents),
      ),
    ],
  );
  await tester.pumpAndSettle();
  // The tab, and not a sidebar link of the same name; on a narrow phone at
  // a large font the strip scrolls, so the tab is brought on screen first.
  final tab = find.descendant(
    of: find.byType(GarageTabBar),
    matching: find.text(
      lookupAppLocalizations(locale ?? const Locale('en')).companyTabIncidents,
    ),
  );
  await tester.ensureVisible(tab);
  await tester.pumpAndSettle();
  await tester.tap(tab);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('every car\'s incidents, open first, with the driver named', (
    tester,
  ) async {
    await pumpIncidents(
      tester,
      incidents: [
        reported(id: 'open', kind: IncidentKind.fine, amount: 40),
        reported(
          id: 'done',
          description: 'Old dent',
          resolvedOn: DateTime.utc(2026, 8, 1),
          status: IncidentStatus.repaired,
        ),
      ],
    );

    expect(find.byKey(const Key('incident-row-open')), findsOneWidget);
    expect(find.byKey(const Key('incident-row-done')), findsNothing);
    expect(find.textContaining('Ana'), findsOneWidget);
    expect(find.textContaining('Golf · Fine'), findsOneWidget);

    await tester.tap(find.byKey(const Key('incidents-all')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('incident-row-done')), findsOneWidget);
    expect(find.textContaining('Repaired'), findsOneWidget);
  });

  testWidgets('a day before the log began names nobody', (tester) async {
    await pumpIncidents(
      tester,
      incidents: [reported(happenedOn: DateTime.utc(2025, 12, 24))],
    );

    expect(find.textContaining('No driver assigned'), findsOneWidget);
    expect(find.textContaining('Ana'), findsNothing);
  });

  testWidgets('a log that could not be read names nobody, and says so of '
      'nobody', (tester) async {
    // "No driver assigned" is a claim about the log; with the log unknown
    // the line is left out, as the sheet leaves it out.
    await pumpIncidents(
      tester,
      incidents: [reported()],
      logFailsWith: const AppFailure(kind: AppFailureKind.network),
    );

    expect(find.byKey(const Key('incident-row-i1')), findsOneWidget);
    expect(find.textContaining('No driver assigned'), findsNothing);
    expect(find.textContaining('Driver on this date'), findsNothing);
  });

  testWidgets('a quiet fleet says so', (tester) async {
    await pumpIncidents(tester, incidents: const []);

    expect(find.text('Nothing reported.'), findsOneWidget);
  });

  testWidgets('a report on a car since sold is still the fleet\'s', (
    tester,
  ) async {
    // A fine on the Passat arrived after the sale: the reimbursements and
    // the pack include the archived car, and the list has to agree.
    await pumpIncidents(
      tester,
      incidents: const [],
      repository: _PerCar(
        stored: [
          Incident(
            id: 'sold',
            vehicleId: 'v2',
            kind: IncidentKind.fine,
            happenedOn: DateTime.utc(2026, 9, 10),
            description: 'Speeding on the A1',
            createdBy: 'u1',
            createdAt: DateTime.utc(2026, 9, 10),
            amount: 130,
          ),
        ],
      ),
      withArchivedCar: true,
    );

    expect(find.byKey(const Key('incident-row-sold')), findsOneWidget);
    expect(find.textContaining('Passat · Fine'), findsOneWidget);
  });

  testWidgets('a fleet with only settled incidents says nothing is open', (
    tester,
  ) async {
    // Something was reported; "Nothing reported." would be untrue.
    await pumpIncidents(
      tester,
      incidents: [
        reported(
          resolvedOn: DateTime.utc(2026, 8, 1),
          status: IncidentStatus.repaired,
        ),
      ],
    );

    expect(find.text('Nothing open.'), findsOneWidget);
    expect(find.text('Nothing reported.'), findsNothing);

    await tester.tap(find.byKey(const Key('incidents-all')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('incident-row-i1')), findsOneWidget);
  });

  testWidgets('a read that fails is said, and a retry reads again', (
    tester,
  ) async {
    await pumpIncidents(
      tester,
      incidents: const [],
      repository: _RefusedOnce(stored: [reported()]),
    );

    expect(find.textContaining('You do not have access'), findsOneWidget);
    expect(find.text('Nothing reported.'), findsNothing);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('incident-row-i1')), findsOneWidget);
  });

  testWidgets('a row opens the report for editing', (tester) async {
    await pumpIncidents(tester, incidents: [reported()]);

    await tester.tap(find.byKey(const Key('incident-row-i1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('incident-save')), findsOneWidget);
  });

  testWidgets('in Croatian on a narrow phone at a large font', (tester) async {
    await pumpIncidents(
      tester,
      incidents: [reported(kind: IncidentKind.accident, amount: 1250)],
      surface: const Size(320, 2000),
      locale: const Locale('hr'),
      textScale: 1.5,
    );

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('incident-row-i1')), findsOneWidget);
  });
}
