import 'package:flutter/services.dart' show rootBundle;
import 'package:garage/l10n/app_localizations.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/format/unit_format.dart';
import '../../domain/entities/cost_entry.dart';
import '../../domain/entities/service_entry.dart';
import '../../domain/entities/vehicle.dart';
import '../../domain/fuel/fuel_economy.dart';
import '../../domain/entities/fuel_entry.dart';
import '../maintenance/service_type_labels.dart';

enum ReportKind { sellers, maintenanceHistory, annualSummary }

/// Everything a report needs, already fetched.
class ReportData {
  const ReportData({
    required this.vehicle,
    required this.currentOdometerKm,
    required this.fuel,
    required this.services,
    required this.costs,
    required this.economy,
  });

  final Vehicle vehicle;
  final int? currentOdometerKm;
  final List<FuelEntry> fuel;
  final List<ServiceEntry> services;
  final List<CostEntry> costs;
  final List<EconomyPoint> economy;
}

/// Renders one of the report kinds as a PDF. Bundled Inter carries the
/// Croatian diacritics the built-in PDF fonts lack.
Future<List<int>> buildReport({
  required ReportKind kind,
  required ReportData data,
  required AppLocalizations l10n,
  required UnitFormat format,
}) async {
  final regular = pw.Font.ttf(
    await rootBundle.load('fonts/InterDisplay-Regular.ttf'),
  );
  final bold = pw.Font.ttf(
    await rootBundle.load('fonts/InterDisplay-SemiBold.ttf'),
  );
  final theme = pw.ThemeData.withFont(base: regular, bold: bold);

  final document = pw.Document(theme: theme);
  final vehicle = data.vehicle;

  final title = switch (kind) {
    ReportKind.sellers => l10n.reportSellers,
    ReportKind.maintenanceHistory => l10n.reportMaintenance,
    ReportKind.annualSummary => l10n.reportAnnual,
  };

  pw.Widget row(String label, String value) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 2),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
        pw.Text(
          value,
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
        ),
      ],
    ),
  );

  pw.Widget header() => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        'GARAGE_',
        style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 4),
      pw.Text(title, style: const pw.TextStyle(fontSize: 14)),
      pw.SizedBox(height: 2),
      pw.Text(
        [
          vehicle.nickname,
          if (vehicle.make != null) vehicle.make!,
          if (vehicle.model != null) vehicle.model!,
          if (vehicle.year != null) '${vehicle.year}',
        ].join(' · '),
        style: const pw.TextStyle(fontSize: 11),
      ),
      pw.Divider(color: PdfColors.grey400),
    ],
  );

  final vehicleFacts = <pw.Widget>[
    if (vehicle.plate != null) row(l10n.vehiclePlate, vehicle.plate!),
    if (vehicle.vin != null) row(l10n.vehicleVin, vehicle.vin!),
    if (data.currentOdometerKm != null)
      row(
        l10n.vehicleCurrentOdometer,
        format.formatDistance(data.currentOdometerKm!.toDouble(), decimals: 0),
      ),
  ];

  final totalEconomyKm = data.economy.fold<double>(
    0,
    (sum, p) => sum + p.distanceKm,
  );
  final totalEconomyL = data.economy.fold<double>(
    0,
    (sum, p) => sum + p.volumeL,
  );
  final avgEconomy = totalEconomyKm > 0
      ? totalEconomyL / totalEconomyKm * 100
      : null;

  pw.Widget serviceTable(List<ServiceEntry> services) =>
      pw.TableHelper.fromTextArray(
        headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
        cellStyle: const pw.TextStyle(fontSize: 9),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
        headers: [
          l10n.costDate,
          l10n.vehicleOdometer,
          l10n.maintenanceTitle,
          l10n.maintenanceServiceCost,
          l10n.fuelNotes,
        ],
        data: [
          for (final entry in services)
            [
              format.formatShortDate(entry.date),
              format.formatDistance(entry.odometerKm.toDouble(), decimals: 0),
              entry.serviceTypeKeys
                  .map((key) => serviceTypeLabel(l10n, key))
                  .join(', '),
              entry.cost == null ? '' : format.formatMoney(entry.cost),
              [
                if (entry.shop != null) entry.shop!,
                if (entry.notes != null) entry.notes!,
              ].join(' · '),
            ],
        ],
      );

  switch (kind) {
    case ReportKind.sellers:
      final fuelTotal = data.fuel.fold<double>(
        0,
        (sum, e) => sum + (e.total ?? 0),
      );
      document.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (context) => [
            header(),
            ...vehicleFacts,
            if (avgEconomy != null)
              row(l10n.statsAvgEconomy, format.formatEconomy(avgEconomy)),
            row(l10n.statsFillUps, '${data.fuel.length}'),
            row(l10n.statsFuelOnly, format.formatMoney(fuelTotal)),
            row(l10n.maintenanceTitle, '${data.services.length}'),
            pw.SizedBox(height: 12),
            pw.Text(
              l10n.reportMaintenance,
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            serviceTable(data.services),
          ],
        ),
      );
    case ReportKind.maintenanceHistory:
      document.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (context) => [
            header(),
            ...vehicleFacts,
            pw.SizedBox(height: 12),
            serviceTable(data.services),
          ],
        ),
      );
    case ReportKind.annualSummary:
      final year = DateTime.now().year;
      bool inYear(DateTime d) => d.year == year;
      final fuelYear = data.fuel.where((e) => inYear(e.date));
      final servicesYear = data.services
          .where((e) => inYear(e.date))
          .toList(growable: false);
      final costsYear = data.costs.where((e) => inYear(e.date));
      final litres = fuelYear.fold<double>(0, (sum, e) => sum + e.volumeL);
      final fuelSpend = fuelYear.fold<double>(
        0,
        (sum, e) => sum + (e.total ?? 0),
      );
      final serviceSpend = servicesYear.fold<double>(
        0,
        (sum, e) => sum + (e.cost ?? 0),
      );
      final otherSpend = costsYear.fold<double>(0, (sum, e) => sum + e.amount);
      document.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (context) => [
            header(),
            row(l10n.statsThisYear, '$year'),
            row(l10n.statsFillUps, '${fuelYear.length}'),
            row(l10n.statsFuelVolume, format.formatVolume(litres)),
            row(l10n.statsFuelOnly, format.formatMoney(fuelSpend)),
            row(l10n.maintenanceTitle, format.formatMoney(serviceSpend)),
            row(l10n.costsTitle, format.formatMoney(otherSpend)),
            row(
              l10n.statsTotalWithFuel,
              format.formatMoney(fuelSpend + serviceSpend + otherSpend),
            ),
            pw.SizedBox(height: 12),
            pw.Text(
              l10n.reportMaintenance,
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            serviceTable(servicesYear),
          ],
        ),
      );
  }

  return document.save();
}
