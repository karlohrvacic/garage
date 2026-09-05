import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/format/unit_format.dart';
import 'package:garage/domain/entities/cost_entry.dart';
import 'package:garage/domain/entities/fuel_entry.dart';
import 'package:garage/domain/entities/reminder_rule.dart';
import 'package:garage/domain/entities/service_entry.dart';
import 'package:garage/domain/maintenance/reminder_projection.dart';
import 'package:garage/domain/entities/trip_entry.dart';
import 'package:garage/domain/entities/vehicle.dart';
import 'package:garage/domain/fuel/fuel_economy.dart';
import 'package:garage/features/reports/report_builder.dart';
import 'package:garage/l10n/app_localizations_en.dart';
import 'package:intl/date_symbol_data_local.dart';

FuelEntry fill(String id, int odometerKm) {
  return FuelEntry(
    id: id,
    vehicleId: 'v1',
    date: DateTime.utc(2026, 5, 1).add(Duration(days: odometerKm ~/ 100)),
    odometerKm: odometerKm,
    volumeL: 40,
    pricePerL: 1.55,
    total: 62,
    fullTank: true,
    missedFill: false,
    station: 'INA',
    createdBy: 'u1',
  );
}

TripEntry trip({
  required String id,
  required DateTime date,
  required double distanceKm,
  TripPurpose purpose = TripPurpose.business,
  String? driver,
}) {
  return TripEntry(
    id: id,
    vehicleId: 'v1',
    date: date,
    distanceKm: distanceKm,
    purpose: purpose,
    createdBy: 'u1',
    title: 'Site visit',
    fromPlace: 'Zagreb',
    toPlace: 'Split',
    driver: driver,
  );
}

ReportData data({bool empty = false}) {
  final fuel = empty ? <FuelEntry>[] : [fill('f1', 50000), fill('f2', 50500)];
  return ReportData(
    vehicle: Vehicle(
      id: 'v1',
      householdId: 'h1',
      nickname: 'Golf',
      fuelTypeKey: 'fuel_diesel',
      baselineOdometerKm: 50000,
      baselineDate: DateTime.utc(2026, 1, 1),
      make: 'VW',
      model: 'Golf VII',
      year: 2015,
      plate: 'ZG1234AB',
      vin: 'WVWZZZ1KZAW000001',
    ),
    currentOdometerKm: empty ? null : 50500,
    fuel: fuel,
    services: empty
        ? const []
        : [
            ServiceEntry(
              id: 's1',
              vehicleId: 'v1',
              date: DateTime.utc(2026, 4, 2),
              odometerKm: 49000,
              serviceTypeKeys: const ['service_oil_change'],
              createdBy: 'u1',
              cost: 210.5,
              shop: 'Auto Hrvoje',
            ),
          ],
    costs: empty
        ? const []
        : [
            CostEntry(
              id: 'c1',
              vehicleId: 'v1',
              date: DateTime.utc(2026, 3, 1),
              category: CostCategories.insurance,
              amount: 320,
              createdBy: 'u1',
            ),
          ],
    economy: FuelEconomy.compute(fuel),
    trips: empty
        ? const []
        : [
            trip(
              id: 't1',
              date: DateTime.utc(2026, 5, 4),
              distanceKm: 380,
              driver: 'Ana Horvat',
            ),
            trip(
              id: 't2',
              date: DateTime.utc(2026, 5, 20),
              distanceKm: 20,
              purpose: TripPurpose.private,
            ),
            // Outside the period below, so a test can prove it is excluded.
            trip(id: 't3', date: DateTime.utc(2026, 6, 2), distanceKm: 999),
          ],
    period: ReportPeriod(
      from: DateTime.utc(2026, 5, 1),
      to: DateTime.utc(2026, 5, 31),
      label: 'May 2026',
    ),
    rules: empty
        ? const []
        : const [
            ReminderRule(
              id: 'r1',
              vehicleId: 'v1',
              serviceTypeKey: 'service_oil_change',
              intervalKm: 15000,
              intervalMonths: 12,
            ),
            ReminderRule(
              id: 'r2',
              vehicleId: 'v1',
              serviceTypeKey: 'service_coolant',
              intervalKm: 20000,
              intervalMonths: 24,
            ),
            // One-off and inactive rules are not a schedule.
            ReminderRule(
              id: 'r3',
              vehicleId: 'v1',
              serviceTypeKey: 'service_registration',
              oneTime: true,
              dueDate: null,
            ),
            ReminderRule(
              id: 'r4',
              vehicleId: 'v1',
              serviceTypeKey: 'service_brake_fluid',
              intervalMonths: 24,
              active: false,
            ),
          ],
    projections: empty
        ? const []
        : [
            ReminderProjection(
              ruleId: 'r1',
              vehicleId: 'v1',
              serviceTypeKey: 'service_oil_change',
              projectedDueDate: DateTime.utc(2026, 11, 4),
              state: ReminderState.upcoming,
            ),
          ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeDateFormatting);

  final l10n = AppLocalizationsEn();
  final format = UnitFormat(
    locale: 'en',
    preferences: const UnitPreferences(
      distance: DistanceUnit.km,
      volume: VolumeUnit.liter,
      currencyCode: 'EUR',
    ),
  );

  Future<List<int>> build(ReportKind kind, {bool empty = false}) {
    return buildReport(
      kind: kind,
      data: data(empty: empty),
      l10n: l10n,
      format: format,
    );
  }

  for (final kind in ReportKind.values) {
    test('${kind.name} renders a PDF document', () async {
      final bytes = await build(kind);

      expect(utf8.decode(bytes.take(4).toList()), '%PDF');
      expect(bytes.length, greaterThan(1000));
    });

    test('${kind.name} renders even with nothing logged yet', () async {
      final bytes = await build(kind, empty: true);

      expect(utf8.decode(bytes.take(4).toList()), '%PDF');
    });
  }

  test('the kinds are not the same document', () async {
    final sellers = await build(ReportKind.sellers);
    final maintenance = await build(ReportKind.maintenanceHistory);
    final annual = await build(ReportKind.annualSummary);
    final logbook = await build(ReportKind.tripLog);

    expect(sellers.length, isNot(maintenance.length));
    expect(maintenance.length, isNot(annual.length));
    expect(annual.length, isNot(logbook.length));
  });

  group('the period a logbook covers', () {
    final may = ReportPeriod(
      from: DateTime.utc(2026, 5, 1),
      to: DateTime.utc(2026, 5, 31),
      label: 'May 2026',
    );

    test('includes both of its own ends', () {
      // A logbook that quietly dropped the last day of the month would be
      // wrong on the very day it is usually printed.
      expect(may.contains(DateTime.utc(2026, 5, 1)), isTrue);
      expect(may.contains(DateTime.utc(2026, 5, 31)), isTrue);
    });

    test('and nothing outside them', () {
      expect(may.contains(DateTime.utc(2026, 4, 30)), isFalse);
      expect(may.contains(DateTime.utc(2026, 6, 1)), isFalse);
    });

    test('ignores the time of day, since entries are dated not timed', () {
      expect(may.contains(DateTime.utc(2026, 5, 31, 23, 59)), isTrue);
    });
  });

  test('the logbook prints only the journeys inside its period', () async {
    // Two of the three fixture trips fall in May; the third is June and its
    // 999 km must appear in neither the rows nor the totals — a total that
    // disagreed with the rows above it is the one error a reader of this
    // document cannot detect.
    final withJune = await buildReport(
      kind: ReportKind.tripLog,
      data: data(),
      l10n: l10n,
      format: format,
    );
    final mayOnly = await buildReport(
      kind: ReportKind.tripLog,
      data: ReportData(
        vehicle: data().vehicle,
        currentOdometerKm: data().currentOdometerKm,
        fuel: data().fuel,
        services: data().services,
        costs: data().costs,
        economy: data().economy,
        trips: [
          for (final t in data().trips)
            if (t.date.month == 5) t,
        ],
        period: data().period,
      ),
      l10n: l10n,
      format: format,
    );

    expect(
      withJune.length,
      mayOnly.length,
      reason: 'a trip outside the period changed the document',
    );
  });

  group('the service schedule', () {
    test('is a different document from the histories', () async {
      final schedule = await build(ReportKind.serviceSchedule);
      final maintenance = await build(ReportKind.maintenanceHistory);

      expect(schedule.length, isNot(maintenance.length));
    });

    test('renders for a car with no intervals set', () async {
      final bytes = await build(ReportKind.serviceSchedule, empty: true);

      expect(utf8.decode(bytes.take(4).toList()), '%PDF');
    });

    test('leaves out the rules that are not a schedule', () async {
      // A one-off (a registration that comes due once) and a switched-off
      // rule are not intervals, and a sheet that listed them would be
      // describing a schedule the car is not kept to.
      final full = await build(ReportKind.serviceSchedule);
      final onlyRecurring = await buildReport(
        kind: ReportKind.serviceSchedule,
        data: ReportData(
          vehicle: data().vehicle,
          currentOdometerKm: data().currentOdometerKm,
          fuel: data().fuel,
          services: data().services,
          costs: data().costs,
          economy: data().economy,
          rules: [
            for (final rule in data().rules)
              if (rule.active && !rule.oneTime) rule,
          ],
          projections: data().projections,
        ),
        l10n: l10n,
        format: format,
      );

      expect(
        full.length,
        onlyRecurring.length,
        reason: 'a one-off or inactive rule changed the sheet',
      );
    });
  });
}
