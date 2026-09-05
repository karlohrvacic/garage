import 'package:flutter/services.dart' show rootBundle;
import 'package:garage/l10n/app_localizations.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/format/unit_format.dart';
import '../../domain/entities/cost_entry.dart';
import '../../domain/entities/reminder_rule.dart';
import '../../domain/entities/service_entry.dart';
import '../../domain/entities/trip_entry.dart';
import '../../domain/maintenance/reminder_projection.dart';
import '../../domain/trips/trip_log.dart';
import '../../domain/entities/vehicle.dart';
import '../../domain/fuel/fuel_economy.dart';
import '../../domain/entities/fuel_entry.dart';
import '../maintenance/service_type_labels.dart';

enum ReportKind {
  sellers,
  maintenanceHistory,
  annualSummary,
  tripLog,
  serviceSchedule,
}

/// The span a report covers, when it covers one.
///
/// Only the mileage logbook takes a period: the other three are "everything"
/// or "this year", which is a property of the report rather than a choice.
class ReportPeriod {
  const ReportPeriod({
    required this.from,
    required this.to,
    required this.label,
  });

  /// Both UTC date-only, both inclusive. A logbook that quietly excluded the
  /// last day of the month would be wrong on the one day of the month it is
  /// printed.
  final DateTime from;
  final DateTime to;

  /// What to print at the top: "August 2026", not two dates the reader has to
  /// reconstruct a month from.
  final String label;

  bool contains(DateTime date) {
    final day = DateTime.utc(date.year, date.month, date.day);
    return !day.isBefore(from) && !day.isAfter(to);
  }
}

/// Everything a report needs, already fetched.
class ReportData {
  const ReportData({
    required this.vehicle,
    required this.currentOdometerKm,
    required this.fuel,
    required this.services,
    required this.costs,
    required this.economy,
    this.trips = const [],
    this.period,
    this.rules = const [],
    this.projections = const [],
  });

  final Vehicle vehicle;
  final int? currentOdometerKm;
  final List<FuelEntry> fuel;
  final List<ServiceEntry> services;
  final List<CostEntry> costs;
  final List<EconomyPoint> economy;

  /// Only the mileage logbook reads these, and only the ones inside [period].
  final List<TripEntry> trips;
  final ReportPeriod? period;

  /// Only the service schedule reads these: the intervals the garage set, and
  /// the dates they currently project to.
  final List<ReminderRule> rules;
  final List<ReminderProjection> projections;
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
    ReportKind.tripLog => l10n.reportTripLog,
    ReportKind.serviceSchedule => l10n.reportSchedule,
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
    case ReportKind.tripLog:
      // A mileage logbook that satisfies whoever asks for it: every journey in
      // the period, where it went, what it was for, who drove it, and the
      // business/private split — which is the whole reason to keep one.
      //
      // The trips are filtered here rather than by the caller so the totals
      // printed and the rows printed cannot disagree, which is the failure a
      // reader of this document has no way to detect.
      final period = data.period;
      final trips =
          [
            for (final trip in data.trips)
              if (period == null || period.contains(trip.date)) trip,
          ]..sort((a, b) {
            final byDate = a.date.compareTo(b.date);
            return byDate != 0 ? byDate : a.id.compareTo(b.id);
          });
      final summary = TripLog.summarise(trips);

      document.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (context) => [
            header(),
            if (period != null) row(l10n.reportTripLogPeriod, period.label),
            ...vehicleFacts,
            pw.SizedBox(height: 8),
            row(l10n.reportTripLogTrips, '${summary.trips}'),
            row(
              l10n.reportTripLogBusinessTotal,
              format.formatDistance(summary.businessKm, decimals: 0),
            ),
            row(
              l10n.reportTripLogPrivateTotal,
              format.formatDistance(summary.privateKm, decimals: 0),
            ),
            row(
              l10n.reportTripLogTotal,
              format.formatDistance(summary.distanceKm, decimals: 0),
            ),
            pw.SizedBox(height: 12),
            if (trips.isEmpty)
              pw.Text(
                l10n.reportTripLogNoTrips,
                style: const pw.TextStyle(fontSize: 10),
              )
            else
              pw.TableHelper.fromTextArray(
                headerStyle: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                ),
                cellStyle: const pw.TextStyle(fontSize: 9),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.grey200,
                ),
                headers: [
                  l10n.costDate,
                  l10n.reportTripLogRoute,
                  l10n.reportTripLogPurpose,
                  l10n.reportTripLogDriver,
                  l10n.tripDistance,
                  l10n.tripPurpose,
                ],
                data: [
                  for (final trip in trips)
                    [
                      format.formatShortDate(trip.date),
                      [?trip.fromPlace, ?trip.toPlace].join(' \u2192 '),
                      [?trip.title, ?trip.notes].join(' \u00b7 '),
                      trip.driver ?? '',
                      format.formatDistance(trip.distanceKm, decimals: 0),
                      trip.purpose == TripPurpose.business
                          ? l10n.tripPurposeBusiness
                          : l10n.tripPurposePrivate,
                    ],
                ],
              ),
            pw.SizedBox(height: 28),
            // A logbook nobody signed is a spreadsheet. The line is what turns
            // this into the document an accountant files.
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                for (final label in [
                  l10n.reportTripLogDate,
                  l10n.reportTripLogSignature,
                ])
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Container(
                        width: 200,
                        height: 1,
                        color: PdfColors.grey600,
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
                    ],
                  ),
              ],
            ),
          ],
        ),
      );
    case ReportKind.serviceSchedule:
      // The car's own service sheet: what gets done, how often, and when it
      // last was — the shape a manufacturer's schedule takes, filled in with
      // this garage's own intervals.
      //
      // Every other report in this app looks backwards. This one is the sheet
      // you hand a mechanic, pin in the garage, or give to whoever buys the
      // car next to say what it has been kept to.
      final scheduled =
          [
            for (final rule in data.rules)
              if (rule.active && !rule.oneTime) rule,
          ]..sort(
            (a, b) => serviceTypeLabel(
              l10n,
              a.serviceTypeKey,
            ).compareTo(serviceTypeLabel(l10n, b.serviceTypeKey)),
          );

      /// "20,000 km · 24 months", or the one of the two that is set.
      ///
      /// Both, when both are set, because whichever comes first is what the
      /// projection uses and a sheet showing only one would be quoting half a
      /// rule.
      String interval(ReminderRule rule) {
        final parts = [
          if (rule.intervalKm case final km?)
            l10n.reportScheduleKm(
              format.formatDistance(km.toDouble(), decimals: 0),
            ),
          if (rule.intervalMonths case final months?)
            l10n.reportScheduleMonths(months),
        ];
        return parts.isEmpty ? l10n.reportScheduleOnce : parts.join(' · ');
      }

      /// The newest service that covered this item, or nothing.
      ServiceEntry? lastDone(String key) {
        final done = [
          for (final entry in data.services)
            if (entry.serviceTypeKeys.contains(key)) entry,
        ]..sort((a, b) => b.date.compareTo(a.date));
        return done.isEmpty ? null : done.first;
      }

      DateTime? nextDue(String key) {
        for (final projection in data.projections) {
          if (projection.serviceTypeKey == key) {
            return projection.projectedDueDate;
          }
        }
        return null;
      }

      document.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (context) => [
            header(),
            ...vehicleFacts,
            pw.SizedBox(height: 12),
            if (scheduled.isEmpty)
              pw.Text(
                l10n.reportScheduleNone,
                style: const pw.TextStyle(fontSize: 10),
              )
            else ...[
              pw.TableHelper.fromTextArray(
                headerStyle: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                ),
                cellStyle: const pw.TextStyle(fontSize: 9),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.grey200,
                ),
                headers: [
                  l10n.reportScheduleItem,
                  l10n.reportScheduleEvery,
                  l10n.reportScheduleLastDone,
                  l10n.reportScheduleNextDue,
                ],
                data: [
                  for (final rule in scheduled)
                    [
                      serviceTypeLabel(l10n, rule.serviceTypeKey),
                      interval(rule),
                      switch (lastDone(rule.serviceTypeKey)) {
                        null => '',
                        final entry =>
                          '${format.formatShortDate(entry.date)} · '
                              '${format.formatDistance(entry.odometerKm.toDouble(), decimals: 0)}',
                      },
                      switch (nextDue(rule.serviceTypeKey)) {
                        null => '',
                        final due => format.formatShortDate(due),
                      },
                    ],
                ],
              ),
              pw.SizedBox(height: 10),
              // The one thing this sheet must not be mistaken for.
              pw.Text(
                l10n.reportScheduleNote,
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey700,
                ),
              ),
            ],
          ],
        ),
      );
  }

  return document.save();
}
