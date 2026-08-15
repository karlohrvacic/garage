import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/format/unit_format.dart';
import 'package:garage/domain/entities/cost_entry.dart';
import 'package:garage/domain/entities/fuel_entry.dart';
import 'package:garage/domain/entities/service_entry.dart';
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

  test('the three kinds are not the same document', () async {
    final sellers = await build(ReportKind.sellers);
    final maintenance = await build(ReportKind.maintenanceHistory);
    final annual = await build(ReportKind.annualSummary);

    expect(sellers.length, isNot(maintenance.length));
    expect(maintenance.length, isNot(annual.length));
  });
}
