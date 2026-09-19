import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/errors/app_failure.dart';
import 'package:garage/core/widgets/async_value_view.dart';
import 'package:garage/core/widgets/garage_tab_bar.dart';
import 'package:garage/domain/entities/reminder_rule.dart';
import 'package:garage/domain/entities/vehicle_document.dart';
import 'package:garage/domain/maintenance/reminder_projection.dart';
import 'package:garage/features/company/providers/company_providers.dart';
import 'package:garage/features/company/screens/company_screen.dart';
import 'package:garage/features/documents/providers/document_providers.dart';
import 'package:garage/features/fuel/providers/fuel_providers.dart';
import 'package:garage/features/household/providers/member_providers.dart';
import 'package:garage/features/maintenance/providers/maintenance_providers.dart';
import 'package:garage/l10n/app_localizations.dart';

import '../../support/pump_screen.dart';
import '../../support/vehicle_entries.dart';
import 'company_providers_test.dart' show RecordingCompanyRepository;
import 'company_screen_test.dart' show company, people;

final today = DateTime(2026, 9, 19);

ReminderProjection due(String vehicleId, String key, DateTime on) {
  return ReminderProjection(
    ruleId: '$vehicleId-$key',
    vehicleId: vehicleId,
    serviceTypeKey: key,
    projectedDueDate: on,
    state: on.isBefore(today) ? ReminderState.overdue : ReminderState.upcoming,
  );
}

Future<NavigationLog> pumpDeadlines(
  WidgetTester tester, {
  required List<ReminderProjection> projections,
  Map<String, List<VehicleDocument>> documents = const {},

  /// Thrown by the projection read, for a test about a first load that
  /// fails outright.
  AppFailure? projectionsFailWith,

  /// Thrown by the first read of the Golf's fill-ups, under the real
  /// projection chain rather than a stood-in projection: the chain reads
  /// every entry kind for the odometer series, and a Retry has to reach
  /// the leaf that failed.
  AppFailure? firstFuelReadFailsWith,

  /// A third car, archived. Its papers have no override, so a read of them
  /// would reach for a real client and fail the whole list.
  bool withArchivedCar = false,
  Size surface = const Size(1400, 900),
  Locale? locale,
  double textScale = 1,
}) async {
  var fuelRefused = false;
  final log = await pumpScreen(
    tester,
    const CompanyScreen(),
    initialLocation: '/company',
    surface: surface,
    locale: locale,
    textScale: textScale,
    household: company,
    extraRoutes: const ['/vehicles/:id'],
    vehicles: [
      testVehicle('v1', nickname: 'Golf'),
      testVehicle('v2', nickname: 'Caddy'),
      if (withArchivedCar)
        testVehicle('v3', nickname: 'Passat', archived: true),
    ],
    overrides: [
      companyRepositoryProvider.overrideWithValue(RecordingCompanyRepository()),
      membersProvider.overrideWith((ref) async => people),
      todayProvider.overrideWithValue(today),
      if (firstFuelReadFailsWith case final failure?) ...[
        // A registration rule on the Golf, so the projection is built
        // from the car's history rather than answered empty.
        reminderRulesProvider('v1').overrideWith(
          (ref) async => const [
            ReminderRule(
              id: 'r1',
              vehicleId: 'v1',
              serviceTypeKey: 'service_registration',
              intervalMonths: 12,
            ),
          ],
        ),
        reminderRulesProvider('v2').overrideWith((ref) async => const []),
        ...vehicleEntryOverrides('v1', fuel: null),
        ...vehicleEntryOverrides('v2'),
        rawFuelEntriesProvider('v1').overrideWith((ref) async {
          if (!fuelRefused) {
            fuelRefused = true;
            throw failure;
          }
          return const [];
        }),
      ] else
        householdProjectionsProvider.overrideWith((ref) async {
          if (projectionsFailWith case final failure?) {
            throw failure;
          }
          return projections;
        }),
      for (final id in ['v1', 'v2'])
        vehicleDocumentsProvider(
          id,
        ).overrideWith((ref) async => documents[id] ?? const []),
    ],
  );
  await tester.pumpAndSettle();
  // The tab, and not a sidebar link of the same name; on a narrow phone at
  // a large font the strip scrolls, so the tab is brought on screen first.
  final tab = find.descendant(
    of: find.byType(GarageTabBar),
    matching: find.text(
      lookupAppLocalizations(locale ?? const Locale('en')).companyTabDeadlines,
    ),
  );
  await tester.ensureVisible(tab);
  await tester.pumpAndSettle();
  await tester.tap(tab);
  await tester.pumpAndSettle();
  return log;
}

void main() {
  testWidgets('this month leads, grouped by month, the late ones marked', (
    tester,
  ) async {
    await pumpDeadlines(
      tester,
      projections: [
        due('v1', 'service_registration', DateTime.utc(2026, 9, 25)),
        due('v2', 'service_technical_inspection', DateTime.utc(2026, 8, 30)),
        due('v2', 'service_oil_change', DateTime.utc(2026, 12, 3)),
      ],
    );

    expect(
      find.byKey(const Key('deadline-v1-service_registration-2026-09-25')),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const Key('deadline-v2-service_technical_inspection-2026-08-30'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('deadline-v2-service_oil_change-2026-12-03')),
      findsNothing,
    );
    expect(find.text('Overdue'), findsOneWidget);
    expect(find.text('AUGUST 2026'), findsOneWidget);
    expect(find.text('SEPTEMBER 2026'), findsOneWidget);
    expect(find.text('Caddy'), findsOneWidget);
    expect(find.text('Golf'), findsOneWidget);
  });

  testWidgets('everything ahead shows the rest, by month', (tester) async {
    await pumpDeadlines(
      tester,
      projections: [
        due('v1', 'service_registration', DateTime.utc(2026, 9, 25)),
        due('v2', 'service_oil_change', DateTime.utc(2026, 12, 3)),
      ],
    );
    expect(
      find.byKey(const Key('deadline-v2-service_oil_change-2026-12-03')),
      findsNothing,
    );

    await tester.tap(find.byKey(const Key('deadlines-all')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('deadline-v2-service_oil_change-2026-12-03')),
      findsOneWidget,
    );
    expect(find.text('SEPTEMBER 2026'), findsOneWidget);
    expect(find.text('DECEMBER 2026'), findsOneWidget);
  });

  testWidgets('a paper\'s expiry is a deadline too', (tester) async {
    await pumpDeadlines(
      tester,
      projections: const [],
      documents: {
        'v1': [
          VehicleDocument(
            id: 'd1',
            vehicleId: 'v1',
            type: DocumentType.roadworthiness,
            expiresOn: DateTime.utc(2026, 9, 28),
            createdBy: 'u1',
          ),
        ],
      },
    );

    expect(
      find.byKey(
        const Key('deadline-v1-service_technical_inspection-2026-09-28'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a one-off and a recurring rule of one type are two rows', (
    tester,
  ) async {
    await pumpDeadlines(
      tester,
      projections: [
        due('v1', 'service_oil_change', DateTime.utc(2026, 9, 22)),
        due('v1', 'service_oil_change', DateTime.utc(2026, 9, 29)),
      ],
    );

    expect(
      find.byKey(const Key('deadline-v1-service_oil_change-2026-09-22')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('deadline-v1-service_oil_change-2026-09-29')),
      findsOneWidget,
    );
  });

  testWidgets('an archived car is not asked for its papers', (tester) async {
    await pumpDeadlines(
      tester,
      projections: [
        due('v1', 'service_registration', DateTime.utc(2026, 9, 25)),
      ],
      withArchivedCar: true,
    );

    expect(
      find.byKey(const Key('deadline-v1-service_registration-2026-09-25')),
      findsOneWidget,
    );
    expect(find.text('Passat'), findsNothing);
  });

  testWidgets('a row opens the car\'s page', (tester) async {
    final log = await pumpDeadlines(
      tester,
      projections: [
        due('v2', 'service_registration', DateTime.utc(2026, 9, 25)),
      ],
    );

    await tester.tap(
      find.byKey(const Key('deadline-v2-service_registration-2026-09-25')),
    );
    await tester.pumpAndSettle();

    expect(log.visited, contains('/vehicles/v2'));
  });

  testWidgets('a quiet month says so, centred like every other empty screen', (
    tester,
  ) async {
    await pumpDeadlines(tester, projections: const []);

    expect(find.text('Nothing falls due in this period.'), findsOneWidget);
    // EmptyState does not centre itself; the page's own Center around the
    // whole column is not the one that counts.
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Center && widget.child is EmptyState,
      ),
      findsOneWidget,
    );
  });

  testWidgets('a projection read that fails is said, not shown as a quiet '
      'month', (tester) async {
    await pumpDeadlines(
      tester,
      projections: const [],
      projectionsFailWith: const AppFailure(
        kind: AppFailureKind.permission,
        debugMessage: '42501: permission denied for table reminder_rules',
      ),
    );

    expect(find.textContaining('You do not have access'), findsOneWidget);
    expect(find.text('Nothing falls due in this period.'), findsNothing);
  });

  testWidgets('a first load whose fill-up read failed is retried from the '
      'leaves', (tester) async {
    // The projection reads fuel, costs, readings, trips and income for the
    // odometer series, none of which the bootstrap refreshes; with retry
    // off a first-load timeout on one of them left the tab erroring on
    // every Retry.
    await pumpDeadlines(
      tester,
      projections: const [],
      firstFuelReadFailsWith: const AppFailure(kind: AppFailureKind.network),
    );

    expect(find.textContaining('No connection'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.textContaining('No connection'), findsNothing);
    expect(find.byKey(const Key('deadlines-this-month')), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('in Croatian on a narrow phone at a large font', (tester) async {
    await pumpDeadlines(
      tester,
      projections: [
        due('v1', 'service_registration', DateTime.utc(2026, 9, 25)),
        due('v2', 'service_technical_inspection', DateTime.utc(2026, 8, 30)),
      ],
      surface: const Size(320, 2000),
      locale: const Locale('hr'),
      textScale: 1.5,
    );

    expect(tester.takeException(), isNull);
    expect(
      find.byKey(const Key('deadline-v1-service_registration-2026-09-25')),
      findsOneWidget,
    );
  });
}
