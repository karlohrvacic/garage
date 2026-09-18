import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:garage/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../trips/providers/trip_providers.dart';

import '../../../core/format/unit_format.dart';
import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/adaptive.dart';
import '../../../core/widgets/cluster_readout.dart';
import '../../../core/widgets/garage_tab_bar.dart';
import '../../../core/widgets/pick_one.dart';
import '../../../domain/fuel/energy_type.dart';
import '../../../domain/fuel/fuel_economy.dart';
import '../../costs/providers/running_cost_providers.dart';
import '../../../core/widgets/confirm_delete.dart';
import '../../../core/widgets/lazy_month_list.dart';
import '../../../core/widgets/month_header.dart';
import '../../../domain/format/month_grouping.dart';
import '../../../core/widgets/failure_message.dart';
import '../../../core/errors/app_failure.dart';
import '../../../domain/entities/guest_pass.dart';
import '../../../domain/entities/service_entry.dart';
import '../../../domain/entities/vehicle.dart';
import '../../../domain/maintenance/reminder_projection.dart';
import '../../../core/files/file_saver.dart';
import '../../../domain/export/export_file_name.dart';
import '../../fuel/providers/fuel_providers.dart';
import '../../costs/cost_category_labels.dart';
import '../../costs/providers/cost_providers.dart';
import '../../costs/widgets/cost_entry_sheet.dart';
import '../../documents/providers/document_providers.dart';
import '../../../domain/costs/running_cost.dart';
import '../../../domain/documents/document_expiry.dart';
import '../../../domain/entities/vehicle_document.dart';
import '../../maintenance/providers/maintenance_providers.dart';
import '../../reports/report_builder.dart';
import '../../maintenance/service_type_labels.dart';
import '../../income/income_category_labels.dart';
import '../../income/providers/income_providers.dart';
import '../../income/widgets/income_entry_sheet.dart';
import '../../../domain/entities/cost_entry.dart';
import '../../../domain/entities/income_entry.dart';
import '../../maintenance/screens/maintenance_screen.dart';
import '../../maintenance/widgets/reminder_rule_sheet.dart';
import '../../maintenance/widgets/service_entry_sheet.dart';
import '../../odometer/providers/odometer_providers.dart';
import '../../odometer/widgets/odometer_entry_sheet.dart';
import '../../../domain/entities/odometer_entry.dart';
import '../../settings/providers/unit_providers.dart';
import '../data/recall_lookup.dart';
import '../fuel_type_labels.dart';
import '../../parts/providers/vehicle_part_providers.dart';
import '../widgets/borrowed_car_briefing.dart';
import '../../fuel/widgets/fuel_entry_row.dart';
import '../../fuel/widgets/fuel_entry_sheet.dart';
import '../../trips/widgets/drive_card.dart';
import '../providers/guest_pass_providers.dart';
import '../providers/vehicle_providers.dart';
import '../widgets/economy_chart.dart';
import '../widgets/economy_gauge.dart';
import '../../../domain/entities/fuel_entry.dart';
import '../../household/providers/household_providers.dart';
import '../../observations/widgets/observations_card.dart';
import '../../observations/providers/observation_providers.dart';
import '../../attachments/providers/attachment_providers.dart';
import '../../../domain/entities/attachment.dart';

class VehicleDetailScreen extends ConsumerWidget {
  const VehicleDetailScreen({required this.vehicleId, super.key});

  final String vehicleId;

  /// This month, last month, or this year — and nothing more elaborate.
  ///
  /// A logbook is filed monthly and reconciled yearly; a free date range would
  /// be a second dialog for a span almost nobody needs, on the way to a report
  /// somebody wants now.
  static Future<ReportPeriod?> _pickReportPeriod(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final today = ref.read(todayProvider);
    final locale = Localizations.localeOf(context).languageCode;

    /// A whole calendar month, both ends inclusive. Day 0 of the next month
    /// *is* the last day of this one, which is what stops a 30-day month
    /// silently losing its 31st.
    ReportPeriod month(int year, int monthOfYear) => ReportPeriod(
      from: DateTime.utc(year, monthOfYear, 1),
      to: DateTime.utc(year, monthOfYear + 1, 0),
      label: DateFormat.yMMMM(
        locale,
      ).format(DateTime.utc(year, monthOfYear, 1)),
    );

    final options = <(String, ReportPeriod)>[
      (l10n.reportTripLogThisMonth, month(today.year, today.month)),
      (l10n.reportTripLogLastMonth, month(today.year, today.month - 1)),
      (
        l10n.reportTripLogThisYear,
        ReportPeriod(
          from: DateTime.utc(today.year, 1, 1),
          to: DateTime.utc(today.year, 12, 31),
          label: '${today.year}',
        ),
      ),
    ];

    return showPickOne<ReportPeriod>(
      context,
      title: l10n.reportTripLogPickPeriod,
      options: [
        for (final (label, period) in options)
          PickOption(period, label, subtitle: period.label),
      ],
    );
  }

  static Future<void> _createReport(
    BuildContext context,
    WidgetRef ref,
    String vehicleId,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    // A sheet like every other list of choices, rather than the dialog it
    // was: six rows with a line of explanation each are the longest list of
    // them all.
    final kind = await showPickOne<ReportKind>(
      context,
      title: l10n.reportsTitle,
      options: [
        for (final (option, label, hint) in [
          (ReportKind.sellers, l10n.reportSellers, l10n.reportSellersHint),
          (ReportKind.handover, l10n.reportHandover, l10n.reportHandoverHint),
          (
            ReportKind.maintenanceHistory,
            l10n.reportMaintenance,
            l10n.reportMaintenanceHint,
          ),
          (ReportKind.annualSummary, l10n.reportAnnual, l10n.reportAnnualHint),
          (ReportKind.tripLog, l10n.reportTripLog, l10n.reportTripLogHint),
          (
            ReportKind.serviceSchedule,
            l10n.reportSchedule,
            l10n.reportScheduleHint,
          ),
        ])
          PickOption(option, label, subtitle: hint),
      ],
    );
    if (kind == null || !context.mounted) {
      return;
    }

    // The logbook is the one report that covers a span rather than everything,
    // and the span is the first thing an accountant asks for. Asked here
    // rather than defaulted to the current month: a logbook is most often
    // printed on the first days of the next one.
    ReportPeriod? period;
    if (kind == ReportKind.tripLog) {
      period = await _pickReportPeriod(context, ref);
      if (period == null || !context.mounted) {
        return;
      }
    }

    final vehicle = await ref.read(vehicleProvider(vehicleId).future);
    if (vehicle == null || !context.mounted) {
      return;
    }
    final format = UnitFormat(
      locale: Localizations.localeOf(context).languageCode,
      preferences: ref.read(unitPreferencesProvider),
    );
    final data = ReportData(
      vehicle: vehicle,
      currentOdometerKm: await ref.read(
        currentOdometerProvider(vehicleId).future,
      ),
      fuel: await ref.read(rawFuelEntriesProvider(vehicleId).future),
      services: await ref.read(serviceEntriesProvider(vehicleId).future),
      costs: await ref.read(costEntriesProvider(vehicleId).future),
      economy: await ref.read(economyPointsProvider(vehicleId).future),
      trips: kind == ReportKind.tripLog
          ? await ref.read(tripEntriesProvider(vehicleId).future)
          : const [],
      period: period,
      rules: kind == ReportKind.serviceSchedule
          ? await ref.read(reminderRulesProvider(vehicleId).future)
          : const [],
      projections:
          kind == ReportKind.serviceSchedule || kind == ReportKind.handover
          ? await ref.read(vehicleProjectionsProvider(vehicleId).future)
          : const [],
      // Only the handover reads them, and fetching them for a seller's report
      // would put a list of complaints one branch away from a document whose
      // whole point is that the owner chose what went in.
      observations: kind == ReportKind.handover
          ? await ref.read(observationsProvider(vehicleId).future)
          : const [],
      // The mileage trail, for the one report a stranger reads. The cleaned
      // series rather than the raw one: it is the mileage history every screen
      // in the app shows, and a report that disagreed with the app would be
      // the more confusing of the two.
      odometer: kind == ReportKind.sellers
          ? await ref.read(odometerSamplesProvider(vehicleId).future)
          : const [],
    );
    if (!context.mounted) {
      return;
    }
    final bytes = await buildReport(
      kind: kind,
      data: data,
      l10n: l10n,
      format: format,
    );
    // Named after the car and the day. `fileNameOverrides` as well as `name`,
    // because `XFile.fromData` drops its name everywhere but web and share_plus
    // then falls back to a UUID — which is why every report so far arrived
    // called something nobody could file.
    final fileName = exportFileName(
      ExportKind.report,
      on: DateTime.now(),
      vehicleName: vehicle.nickname,
    );
    // Saved rather than shared, for the same reason the exports are: a report
    // is a file somebody wants to keep, and the share sheet made keeping it a
    // detour through whichever app would take it.
    final saved = await ref.read(fileSaverProvider)(
      fileName: fileName,
      bytes: Uint8List.fromList(bytes),
      mimeType: 'application/pdf',
    );
    if (saved || !context.mounted) {
      return;
    }
    // Backing out of the save dialog means backing out: following it with a
    // share sheet nobody asked for would be the app arguing with a decision
    // just made. But cancelling a *save* is also exactly when somebody wanted
    // to send the thing to a buyer rather than keep it, so the offer is made
    // and not taken — the report is already built, and rebuilding it means
    // going back through the picker.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.reportsNotSaved),
        action: SnackBarAction(
          label: l10n.commonShare,
          onPressed: () => SharePlus.instance.share(
            ShareParams(
              files: [
                XFile.fromData(
                  Uint8List.fromList(bytes),
                  name: fileName,
                  mimeType: 'application/pdf',
                ),
              ],
              fileNameOverrides: [fileName],
              subject: l10n.reportsTitle,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final vehicle = ref.watch(vehicleProvider(vehicleId));

    return DefaultTabController(
      length: 4,
      child: GaragePageScaffold(
        // The car's own name, falling back while it loads. A page titled after
        // the thing it shows is the point of putting the title in the content.
        title: vehicle.value?.nickname ?? l10n.vehiclesTitle,
        // Charts, an economy series and four views to compare: this is the
        // case the wider column exists for. It was the only tabbed screen
        // still taking the reading width, which capped the tab strip and the
        // charts under it at a text column on a monitor.
        contentWidth: ContentWidth.wide,
        actions: [
          // One icon, and it is the everyday one: a reading is logged far more
          // often than a car is edited, transferred or reported on. The rest
          // moved into the menu — four icons and a menu button made a phone's
          // app bar a row of small grey glyphs nobody could tell apart.
          //
          // A dated reading rather than a rewrite of the vehicle's baseline:
          // the baseline says where the car stood when it was added, and
          // overwriting it loses that. Correcting a mistyped baseline is
          // still on the edit screen, where it belongs.
          // Nothing grants a guest an odometer reading — there is no policy
          // for it — so the everyday button is an owner's too.
          if (ref.watch(vehicleIsMineProvider(vehicleId)))
            IconButton(
              icon: const Icon(Icons.speed_outlined),
              tooltip: l10n.odometerAdd,
              onPressed: () => showOdometerEntrySheet(context, vehicleId),
            ),
          // The other act done standing at the car. It was five taps away,
          // under More, and absent from the owner's page while a borrower's
          // had it (decision 156). Hidden while a drive is out: the banner
          // below carries that one, with the button that finishes it.
          if (ref.watch(vehicleIsMineProvider(vehicleId)))
            if (ref.watch(openTripDraftProvider(vehicleId)) case AsyncData(
              value: null,
            ))
              IconButton(
                key: const Key('vehicle-start-drive'),
                icon: const Icon(Icons.play_arrow_outlined),
                tooltip: l10n.tripDriveStart,
                onPressed: () => showStartDriveSheet(context, ref, vehicleId),
              ),
          // Owner actions only for a car in a garage of yours. A borrower was
          // offered Edit, Archive, Delete, Transfer and Lending — every one of
          // them refused by the policies, and every one of them a tap that
          // appeared to do nothing.
          if (ref.watch(vehicleIsMineProvider(vehicleId)))
            PopupMenuButton<_VehicleAction>(
              key: const Key('vehicle-menu'),
              onSelected: (action) =>
                  _runVehicleAction(context, ref, vehicleId, action),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: _VehicleAction.edit,
                  child: _MenuRow(
                    icon: Icons.edit_outlined,
                    label: l10n.vehicleEdit,
                  ),
                ),
                // Both left the Service tab, where they were two outlined
                // buttons in a fixed footer competing with the list for height.
                // Neither is an everyday act; the menu is where the rest of the
                // once-in-a-while ones already live.
                PopupMenuItem(
                  value: _VehicleAction.calendar,
                  child: _MenuRow(
                    icon: Icons.calendar_month,
                    label: l10n.maintenanceCalendar,
                  ),
                ),
                PopupMenuItem(
                  value: _VehicleAction.tyres,
                  child: _MenuRow(
                    icon: Icons.tire_repair_outlined,
                    label: l10n.tyresTitle,
                  ),
                ),
                PopupMenuItem(
                  value: _VehicleAction.documents,
                  child: _MenuRow(
                    icon: Icons.badge_outlined,
                    label: l10n.documentsTitle,
                  ),
                ),
                // Only for somebody holding the car on a pass that opens the
                // history: an owner reaches the same records through the
                // vehicle's own screens, with nothing masked.
                if (ref.watch(guestPassForVehicleProvider(vehicleId))
                    case final pass? when pass.canViewHistory)
                  PopupMenuItem(
                    value: _VehicleAction.lentHistory,
                    child: _MenuRow(
                      icon: Icons.history,
                      label: l10n.lentHistoryTitle,
                    ),
                  ),
                // Lending sits beside transferring because they are the same
                // question asked for different lengths of time — who else may
                // use this car. It shipped with a screen and no way to open it.
                PopupMenuItem(
                  value: _VehicleAction.lending,
                  child: _MenuRow(
                    icon: Icons.key_outlined,
                    label: l10n.guestPassesTitle,
                  ),
                ),
                PopupMenuItem(
                  value: _VehicleAction.transfer,
                  child: _MenuRow(
                    icon: Icons.swap_horiz,
                    label: l10n.transferTitle,
                  ),
                ),
                PopupMenuItem(
                  value: _VehicleAction.report,
                  child: _MenuRow(
                    icon: Icons.description_outlined,
                    label: l10n.reportsTitle,
                  ),
                ),
                // The two that take a vehicle off the lists, kept apart from the
                // three above: those are things you do to a car you are keeping.
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: (vehicle.value?.archived ?? false)
                      ? _VehicleAction.restore
                      : _VehicleAction.archive,
                  child: _MenuRow(
                    icon: (vehicle.value?.archived ?? false)
                        ? Icons.unarchive_outlined
                        : Icons.archive_outlined,
                    label: (vehicle.value?.archived ?? false)
                        ? l10n.vehicleRestore
                        : l10n.vehicleArchive,
                  ),
                ),
                PopupMenuItem(
                  value: _VehicleAction.delete,
                  child: _MenuRow(
                    icon: Icons.delete_outline,
                    label: l10n.vehicleDelete,
                    colour: context.tokens.danger,
                  ),
                ),
              ],
            ),
        ],
        // Labels alone, like Statistics and every other tabbed screen here:
        // icons above them doubled the strip's height and took the room the
        // words needed. Four short words share a phone's width; a longer one,
        // or a larger font, scrolls the strip rather than cutting it off.
        //
        // What the car uses, what it is due for and has had done, the car
        // itself, and what it costs (decision 173).
        //
        // A borrower has no use for four tabs built on a history they cannot
        // read: an economy chart with one fill-up in it, reminders that are
        // the owner's business, an empty history. They get the briefing
        // instead, and the actions their pass actually allows.
        bottom: ref.watch(vehicleIsMineProvider(vehicleId))
            ? GarageTabBar(
                labels: [
                  l10n.vehicleTabFuel,
                  l10n.vehicleTabUpkeep,
                  l10n.vehicleTabCar,
                  l10n.costsTitle,
                ],
              )
            : null,
        body: AsyncValueView<Vehicle?>(
          value: vehicle,
          onRetry: () => ref.invalidate(garageBootstrapProvider),
          data: (value) {
            if (value == null) {
              return Center(child: Text(l10n.errorNotFound));
            }
            return Column(
              children: [
                // A borrowed car's lists show only what the borrower logged,
                // which is the right default and reads as a broken app: an
                // empty fuel log on a car with 180,000 km on it. Say why.
                if (ref.watch(guestPassForVehicleProvider(vehicleId))
                    case final pass? when !pass.canViewHistory)
                  MaterialBanner(
                    key: const Key('guest-history-banner'),
                    content: Text(l10n.guestHistoryHidden),
                    leading: const Icon(Icons.visibility_off_outlined),
                    actions: const [SizedBox.shrink()],
                  ),
                // An archived car's page looked like any other; only the
                // menu, if opened, said Restore.
                if (ref.watch(vehicleIsMineProvider(vehicleId))) ...[
                  _LoanBanner(vehicleId: vehicleId),
                  if (ref.watch(openTripDraftProvider(vehicleId))
                      case AsyncData(value: _?))
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        GarageTokens.space4,
                        GarageTokens.space2,
                        GarageTokens.space4,
                        0,
                      ),
                      child: DriveCard(vehicleId: vehicleId),
                    ),
                ],
                if (value.archived)
                  MaterialBanner(
                    key: const Key('archived-banner'),
                    content: Text(l10n.vehicleArchivedBanner),
                    leading: const Icon(Icons.inventory_2_outlined),
                    actions: [
                      TextButton(
                        onPressed: () => _runVehicleAction(
                          context,
                          ref,
                          vehicleId,
                          _VehicleAction.restore,
                        ),
                        child: Text(l10n.vehicleRestore),
                      ),
                    ],
                  ),
                Expanded(
                  child: ref.watch(vehicleIsMineProvider(vehicleId))
                      ? TabBarView(
                          children: [
                            _FuelTab(vehicleId: vehicleId),
                            _UpkeepTab(vehicleId: vehicleId),
                            _CarTab(vehicleId: vehicleId),
                            _CostsTab(vehicleId: vehicleId),
                          ],
                        )
                      : _BorrowedCarBody(vehicleId: vehicleId),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// A borrowed car's page: what you are holding, and what your pass lets you
/// do with it. Everything else on this screen belongs to the owner.
class _BorrowedCarBody extends ConsumerWidget {
  const _BorrowedCarBody({required this.vehicleId});

  final String vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final pass = ref.watch(guestPassForVehicleProvider(vehicleId));

    return Column(
      children: [
        Expanded(child: BorrowedCarBriefing(vehicleId: vehicleId)),
        // Only what the pass grants. A row that opens a sheet the policies
        // will refuse is the same silent failure as the owner menu was.
        if (pass != null)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: GarageTokens.space4,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (pass.canLogFuel)
                    ListTile(
                      key: const Key('borrowed-log-fuel'),
                      leading: const Icon(Icons.local_gas_station_outlined),
                      title: Text(l10n.fuelAdd),
                      onTap: () => showFuelEntrySheet(context, vehicleId),
                    ),
                  if (pass.canLogTrips)
                    ListTile(
                      key: const Key('borrowed-log-trip'),
                      leading: const Icon(Icons.route_outlined),
                      title: Text(l10n.tripDriveStart),
                      onTap: () => context.push('/vehicles/$vehicleId/trip'),
                    ),
                  if (pass.canViewHistory)
                    ListTile(
                      key: const Key('borrowed-history'),
                      leading: const Icon(Icons.history),
                      title: Text(l10n.lentHistoryTitle),
                      onTap: () =>
                          context.push('/vehicles/$vehicleId/lent-history'),
                    ),
                  // The borrower's own way out. Until this, a car handed back
                  // on Sunday sat in their garage until the pass ran out on
                  // Wednesday, and only the owner could end it early.
                  ListTile(
                    key: const Key('borrowed-give-back'),
                    leading: const Icon(Icons.assignment_return_outlined),
                    title: Text(l10n.guestReturn),
                    onTap: () => _giveBack(context, ref, pass),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

Future<void> _giveBack(
  BuildContext context,
  WidgetRef ref,
  GuestPass pass,
) async {
  final l10n = AppLocalizations.of(context)!;
  final messenger = ScaffoldMessenger.of(context);
  final router = GoRouter.of(context);
  // Red: once given back, only the owner can lend it again.
  final confirmed = await confirmDestructive(
    context,
    body: l10n.guestReturnConfirm,
    confirmLabel: l10n.guestReturn,
    confirmKey: const Key('give-back-confirm'),
  );
  if (!confirmed) {
    return;
  }
  final done = await ref
      .read(guestPassControllerProvider.notifier)
      .giveBack(pass);
  if (!done) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.errorGeneric)));
    return;
  }
  messenger.showSnackBar(SnackBar(content: Text(l10n.guestReturned)));
  // The car is gone from under them, so the page they are on is too.
  router.go('/vehicles');
}

/// What the car burns and what it was filled with: the economy, and the
/// fill-ups it is worked out from.
class _FuelTab extends ConsumerWidget {
  const _FuelTab({required this.vehicleId});

  final String vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final prefs = ref.watch(unitPreferencesProvider);
    final format = UnitFormat(
      locale: Localizations.localeOf(context).languageCode,
      preferences: prefs,
    );
    final energy = ref.watch(vehicleEnergyProvider(vehicleId));
    final points = ref.watch(economyPointsProvider(vehicleId));

    final entries =
        ref.watch(fuelEntriesProvider(vehicleId)).value ?? const <FuelEntry>[];
    final withAttachments =
        ref.watch(entriesWithAttachmentsProvider).value ?? const <String>{};

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('log-fuel'),
        onPressed: () => showFuelEntrySheet(context, vehicleId),
        icon: const Icon(Icons.local_gas_station_outlined),
        label: Text(l10n.fuelAdd),
      ),
      body: AsyncValueView(
        value: points,
        onRetry: () => ref.invalidate(rawFuelEntriesProvider(vehicleId)),
        data: (list) {
          final pointsByEntry = {for (final p in list) p.entryId: p};
          // The gauge, its caption and the chart read in the car's own
          // energy, so they take its own tanks: a plug-in hybrid's charges on
          // the same axis were scaled and drawn as litres. The rows below
          // measure each fill-up against its own kind.
          final own = [
            for (final point in list)
              if (EnergyType.forEntry(point.fuelTypeKey, vehicle: energy) ==
                  energy)
                point,
          ];
          final range = EconomyRange.of(own);
          // Newest first, as the log lists them; five is a screenful under
          // the gauge, and the button beneath says how many there are.
          final latest = entries.take(5).toList(growable: false);
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              GarageTokens.space4,
              GarageTokens.space4,
              GarageTokens.space4,
              GarageTokens.fabClearance,
            ),
            children: [
              // The odometer alone. A tank range sat beside it and counted down
              // towards empty against a reading that only moves when something is
              // logged, so it showed a full tank for the whole tank. How far a
              // tankful goes is a statistic now, on the statistics screen, where
              // it is measured rather than guessed (decision 152).
              Center(
                child: ClusterReadout(
                  label: l10n.vehicleCurrentOdometer,
                  value: switch (ref
                      .watch(currentOdometerProvider(vehicleId))
                      .value) {
                    null => UnitFormat.emptyValue,
                    final km => format.formatDistance(
                      km.toDouble(),
                      decimals: 0,
                    ),
                  },
                ),
              ),
              const SizedBox(height: GarageTokens.space4),
              // Scaled against this car's own best and worst rather than a fixed
              // 4 to 12 l/100km, which flattered a small diesel, pinned a thirsty
              // car at empty, and meant nothing for an electric one. The caption
              // says what the ring is measuring, because a proportion with no
              // stated basis is not information.
              Builder(
                builder: (context) {
                  final average = ref
                      .watch(averageEconomyProvider(vehicleId))
                      .value;
                  final mainFuel = ref
                      .watch(vehicleProvider(vehicleId))
                      .value
                      ?.fuelTypeKey;
                  final range = EconomyRange.of(own);
                  return Column(
                    children: [
                      EconomyGauge(
                        litersPer100Km: average,
                        label: format.formatEconomy(average, energy),
                        best: range?.best ?? EconomyGauge.defaultBest,
                        worst: range?.worst ?? EconomyGauge.defaultWorst,
                      ),
                      const SizedBox(height: GarageTokens.space2),
                      // What the arc is measured against. A proportion with no
                      // stated basis is not information, and until this car has
                      // two tanks the ends are the app's own, not its.
                      if (average != null && range == null)
                        Text(
                          l10n.economyScaleDefault(
                            format.formatEconomy(
                              EconomyGauge.defaultBest,
                              energy,
                            ),
                            format.formatEconomy(
                              EconomyGauge.defaultWorst,
                              energy,
                            ),
                          ),
                          style: TextStyle(color: context.tokens.muted),
                        ),
                      // An empty ring with "—" said nothing about how far off
                      // the figure is; the count does.
                      if (average == null)
                        Text(
                          // Per fuel, like the economy itself: a petrol full
                          // tank and an LPG one are one each, not two.
                          l10n.economyTanksProgress(
                            (ref
                                        .watch(
                                          rawFuelEntriesProvider(vehicleId),
                                        )
                                        .value ??
                                    const <FuelEntry>[])
                                .where(
                                  (e) =>
                                      e.fullTank &&
                                      (e.fuelTypeKey ?? mainFuel) == mainFuel,
                                )
                                .length
                                .clamp(0, 2),
                          ),
                          style: TextStyle(color: context.tokens.muted),
                        ),
                      // With no figure at all the chart below already says what
                      // is missing; a second "log more tanks" line here made two.
                      if (average != null || range != null)
                        Text(
                          range == null
                              ? l10n.economyScaleNone
                              : l10n.economyScale(
                                  format.formatEconomy(range.best, energy),
                                  format.formatEconomy(range.worst, energy),
                                ),
                          style: TextStyle(color: context.tokens.muted),
                          textAlign: TextAlign.center,
                        ),
                    ],
                  );
                },
              ),
              // A bi-fuel car's headline average mixes two fuels and is therefore
              // neither; the split beneath it is the figure that means something.
              _EconomyByFuelCard(vehicleId: vehicleId, format: format),
              const SizedBox(height: GarageTokens.space4),
              // The fill-ups themselves, with the economy each one worked out
              // to. They used to live one screen away, behind a button labelled
              // "Fuel" under the chart, on the tab named for them (decision 156).
              if (latest.isNotEmpty) ...[
                _SectionHeading(l10n.fuelLatest),
                for (final entry in latest)
                  Padding(
                    padding: const EdgeInsets.only(bottom: GarageTokens.space2),
                    child: FuelEntryRow(
                      entry: entry,
                      point: pointsByEntry[entry.id],
                      allPoints: list,
                      range: range,
                      format: format,
                      energy: energy,
                      hasAttachment: withAttachments.contains(entry.id),
                      onTap: () => showFuelEntrySheet(
                        context,
                        vehicleId,
                        existing: entry,
                      ),
                    ),
                  ),
                OutlinedButton.icon(
                  key: const Key('all-fill-ups'),
                  onPressed: () => context.push('/vehicles/$vehicleId/fuel'),
                  icon: const Icon(Icons.receipt_long_outlined),
                  label: Text(l10n.fuelAllFillUps(entries.length)),
                ),
                const SizedBox(height: GarageTokens.space6),
              ],
              EconomyChart(
                points: own,
                formatEconomy: (value) => format.formatEconomy(value, energy),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// An eyebrow over a group of rows, so a tab that holds more than one kind
/// of thing says where one kind ends and the next begins.
class _SectionHeading extends StatelessWidget {
  const _SectionHeading(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: GarageTokens.space3,
        bottom: GarageTokens.space2,
      ),
      child: Text(title.toUpperCase(), style: GarageTheme.eyebrow(context)),
    );
  }
}

/// Says on the car's own page that it is out on loan. The only other place
/// that knew was three taps deep under the menu's "Lending": a borrower's
/// list said "Yours until", and the owner's page said nothing (decision 156).
class _LoanBanner extends ConsumerWidget {
  const _LoanBanner({required this.vehicleId});

  final String vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final passes =
        ref.watch(vehicleGuestPassesProvider(vehicleId)).value ??
        const <GuestPass>[];
    final now = DateTime.now().toUtc();
    final live = passes
        .where((pass) => pass.stateAt(now) == GuestPassState.live)
        .firstOrNull;
    if (live == null) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context)!;
    final format = UnitFormat(
      locale: Localizations.localeOf(context).languageCode,
      preferences: ref.watch(unitPreferencesProvider),
    );
    final until = format.formatShortDate(live.expiresAt.toLocal());
    final label = (live.label ?? '').trim();
    return Material(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: ListTile(
        key: const Key('loan-banner'),
        leading: const Icon(Icons.key_outlined),
        title: Text(
          label.isEmpty
              ? l10n.vehicleOnLoanUntil(until)
              : l10n.vehicleOnLoanTo(until, label),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/vehicles/$vehicleId/lending'),
      ),
    );
  }
}

/// Consumption per fuel, for a car that takes two. Draws nothing at all for
/// the ordinary car, where the split would be the whole log restated.
class _EconomyByFuelCard extends ConsumerWidget {
  const _EconomyByFuelCard({required this.vehicleId, required this.format});

  final String vehicleId;
  final UnitFormat format;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final byFuel =
        ref.watch(economyByFuelProvider(vehicleId)).value ?? const {};
    if (byFuel.length < 2) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: GarageTokens.space6),
      child: Card(
        key: const Key('economy-by-fuel'),
        child: Padding(
          padding: const EdgeInsets.all(GarageTokens.space4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.statsEconomyByFuel.toUpperCase(),
                style: GarageTheme.eyebrow(context),
              ),
              const SizedBox(height: GarageTokens.space3),
              for (final entry in byFuel.entries)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: GarageTokens.space1,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          fuelTypeLabel(l10n, entry.key) ?? entry.key,
                        ),
                      ),
                      Text(
                        format.formatEconomy(
                          FuelEconomy.average(entry.value),
                          EnergyType.forFuelKey(entry.key),
                        ),
                        style: GarageTheme.numeric(
                          Theme.of(context).textTheme.bodyMedium!,
                        ),
                      ),
                    ],
                  ),
                ),
              // Each fuel now gets its own chain of full tanks, so a petrol
              // figure is computed from petrol volumes alone. What no app can
              // fix from this data is that the chains overlap: an LPG span from
              // 1000 to 1500 km includes whatever was driven on petrol in
              // between. Each figure approximates that fuel's consumption over
              // a period rather than measuring it, and two confident-looking
              // numbers said none of that.
              const SizedBox(height: GarageTokens.space3),
              Text(
                l10n.economyByFuelOverlap,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: context.tokens.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// What the car is due for, then what it has had done, in one scroll.
///
/// A reminder is worked out from the services logged, and a service logged is
/// the answer to one. They were two tabs, and the reminders shared theirs with
/// five rows about the car itself, so a car with eight things due put the
/// tyres several screens down (decision 173).
class _UpkeepTab extends ConsumerWidget {
  const _UpkeepTab({required this.vehicleId});

  final String vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    final format = UnitFormat(
      locale: locale,
      preferences: ref.watch(unitPreferencesProvider),
    );
    final projections = ref.watch(vehicleProjectionsProvider(vehicleId));
    // Watched on their own, not read through the schedule: a car with no
    // reminders projects nothing without waiting for its services, so the
    // tab draws before they arrive, and a fetch that failed read as a car
    // with none logged.
    final services = ref.watch(serviceEntriesProvider(vehicleId));
    final readings = ref.watch(odometerEntriesProvider(vehicleId));
    final historyFailure = services.hasError
        ? services.error
        : readings.hasError
        ? readings.error
        : null;
    void retryHistory() => ref
      ..invalidate(serviceEntriesProvider(vehicleId))
      ..invalidate(odometerEntriesProvider(vehicleId));
    final quiet = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: context.tokens.muted);

    // A Scaffold of its own so the button belongs to this tab rather than to
    // the whole vehicle screen: the parent holds four tabs and one app bar,
    // and hanging a tab-specific action off it would mean tracking the tab
    // index through a screen that has no other reason to know it.
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('log-service'),
        onPressed: () => showServiceEntrySheet(context, vehicleId),
        icon: const Icon(Icons.add),
        label: Text(l10n.maintenanceLogService),
      ),
      body: AsyncValueView<List<ReminderProjection>>(
        value: projections,
        onRetry: () {
          ref
            ..invalidate(reminderRulesProvider(vehicleId))
            ..invalidate(serviceEntriesProvider(vehicleId))
            ..invalidate(odometerEntriesProvider(vehicleId))
            ..invalidate(rawFuelEntriesProvider(vehicleId))
            ..invalidate(garageBootstrapProvider);
        },
        data: (due) {
          // The visits and the readings taken between them, in one list
          // because they are one story: both are dated points on the same
          // odometer.
          final history = historyFailure != null
              ? const <Object>[]
              : (<Object>[
                  ...services.value ?? const <ServiceEntry>[],
                  ...readings.value ?? const <OdometerEntry>[],
                ]..sort((a, b) => _historyDate(b).compareTo(_historyDate(a))));

          // Months are built as they scroll into view, so a history imported
          // from years of Fuelio costs nothing until it is read. What is due
          // is a handful of rows and goes ahead of them.
          return LazyMonthList<Object>(
            padding: const EdgeInsets.only(
              top: GarageTokens.space1,
              bottom: GarageTokens.fabClearance,
            ),
            leading: [
              for (final child in [
                _SectionHeading(l10n.vehicleSectionDue),
                // Whatever the list holds: it used to live only in the empty
                // state, so once one reminder existed the tab offered "Log
                // service" and nothing else.
                _AddReminderRow(vehicleId: vehicleId),
                if (due.isEmpty)
                  Text(l10n.maintenanceEmpty, style: quiet)
                else
                  // The same list the Maintenance screen renders, with its
                  // row menu, rather than a read-only copy that showed what
                  // was due and offered nothing to do about it.
                  MaintenanceProjectionList(
                    vehicleId: vehicleId,
                    projections: due,
                    scrolls: false,
                  ),
                _SectionHeading(l10n.vehicleSectionHistory),
                if (historyFailure != null)
                  AsyncValueView<void>(
                    value: AsyncValue.error(historyFailure, StackTrace.current),
                    onRetry: retryHistory,
                    data: (_) => const SizedBox.shrink(),
                  )
                else if (!services.hasValue)
                  const Padding(
                    padding: EdgeInsets.all(GarageTokens.space4),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (history.isEmpty)
                  Text(l10n.vehicleNoHistoryYet, style: quiet),
              ])
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: GarageTokens.space4,
                  ),
                  child: child,
                ),
            ],
            groups: MonthGrouping.of(history, _historyDate),
            header: (context, group) =>
                MonthHeader(month: group.month, locale: locale),
            row: (context, entry) => Padding(
              padding: const EdgeInsets.fromLTRB(
                GarageTokens.space4,
                0,
                GarageTokens.space4,
                GarageTokens.space2,
              ),
              child: switch (entry) {
                final ServiceEntry entry => _ServiceHistoryRow(
                  vehicleId: vehicleId,
                  entry: entry,
                  format: format,
                ),
                final OdometerEntry entry => _ReadingHistoryRow(
                  vehicleId: vehicleId,
                  entry: entry,
                  format: format,
                ),
                _ => const SizedBox.shrink(),
              },
            ),
          );
        },
      ),
    );
  }
}

/// The car itself rather than what it is due for: its tyres, its papers, the
/// parts it takes, a check before a long drive, what is wrong with it, and
/// any recall. They sat on the reminders tab under a "This car" heading,
/// where they and a long schedule pushed each other off the screen
/// (decision 173).
class _CarTab extends StatelessWidget {
  const _CarTab({required this.vehicleId});

  final String vehicleId;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(GarageTokens.space4),
      children: [
        _TyresRow(vehicleId: vehicleId),
        _DocumentsRow(vehicleId: vehicleId),
        _PartsRow(vehicleId: vehicleId),
        _TripPrepRow(vehicleId: vehicleId),
        // What is wrong and not yet sorted: a rattle nobody has been to a
        // garage about is the thing a driver is trying to remember.
        Padding(
          padding: const EdgeInsets.only(top: GarageTokens.space3),
          child: ObservationsCard(vehicleId: vehicleId),
        ),
        _RecallsCard(vehicleId: vehicleId),
      ],
    );
  }
}

/// Tyre sets lived only behind the overflow menu, four taps from the
/// dashboard, and nobody who did not already know found them.
class _TyresRow extends StatelessWidget {
  const _TyresRow({required this.vehicleId});

  final String vehicleId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      child: ListTile(
        key: const Key('vehicle-tyres-row'),
        leading: const Icon(Icons.tire_repair_outlined),
        title: Text(l10n.tyresTitle),
        subtitle: Text(l10n.vehicleTyresHint),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/vehicles/$vehicleId/tyres'),
      ),
    );
  }
}

/// Preparing this car for a long drive. On the vehicle rather than the
/// planner: it is one car and one journey, and the planner is the whole
/// garage over time.
class _TripPrepRow extends StatelessWidget {
  const _TripPrepRow({required this.vehicleId});

  final String vehicleId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      child: ListTile(
        key: const Key('trip-prep-row'),
        leading: const Icon(Icons.luggage_outlined),
        title: Text(l10n.tripPrepTitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/vehicles/$vehicleId/trip'),
      ),
    );
  }
}

/// The paperwork, and whether any of it has run out or is about to: missing
/// a registration is a fine rather than a worn part, so the row says so
/// before it is opened.
class _DocumentsRow extends ConsumerWidget {
  const _DocumentsRow({required this.vehicleId});

  final String vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final documents =
        ref.watch(vehicleDocumentsProvider(vehicleId)).value ??
        const <VehicleDocument>[];
    final today = ref.watch(todayProvider);
    final worst = documents
        .map(
          (document) =>
              documentExpiryState(expiresOn: document.expiresOn, today: today),
        )
        .fold<DocumentExpiryState?>(
          null,
          (worst, state) =>
              worst == null || state.index > worst.index ? state : worst,
        );

    return Card(
      child: ListTile(
        key: const Key('vehicle-documents-row'),
        leading: const Icon(Icons.badge_outlined),
        title: Text(l10n.documentsTitle),
        subtitle: Text(
          switch (worst) {
            DocumentExpiryState.expired => l10n.documentsSomethingExpired,
            DocumentExpiryState.expiring => l10n.documentsSomethingExpiring,
            _ => l10n.documentsSubtitle,
          },
          style: switch (worst) {
            DocumentExpiryState.expired => TextStyle(
              color: context.tokens.danger,
            ),
            DocumentExpiryState.expiring => TextStyle(
              color: context.tokens.warn,
            ),
            _ => null,
          },
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/vehicles/$vehicleId/documents'),
      ),
    );
  }
}

/// What this car takes: oil spec, filter numbers, bulbs. Beside Documents
/// because both are things the household looked up once and does not want to
/// look up again.
class _PartsRow extends ConsumerWidget {
  const _PartsRow({required this.vehicleId});

  final String vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final count =
        (ref.watch(vehiclePartsProvider(vehicleId)).value ?? const []).length;

    return Card(
      child: ListTile(
        key: const Key('vehicle-parts-row'),
        leading: const Icon(Icons.build_circle_outlined),
        title: Text(l10n.partsTitle),
        subtitle: Text(count == 0 ? l10n.partsEmpty : l10n.partsCount(count)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/vehicles/$vehicleId/parts'),
      ),
    );
  }
}

DateTime _historyDate(Object entry) => switch (entry) {
  final ServiceEntry entry => entry.date,
  final OdometerEntry entry => entry.date,
  _ => DateTime.utc(0),
};

class _ServiceHistoryRow extends ConsumerWidget {
  const _ServiceHistoryRow({
    required this.vehicleId,
    required this.entry,
    required this.format,
  });

  final String vehicleId;
  final ServiceEntry entry;
  final UnitFormat format;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final labels = entry.serviceTypeKeys
        .map((key) => serviceTypeLabel(l10n, key))
        .join(', ');

    return Dismissible(
      key: ValueKey(entry.id),
      direction: DismissDirection.endToStart,
      background: const DeleteSwipeBackground(),
      confirmDismiss: (_) => confirmDelete(context),
      onDismissed: (_) => deleteSwipedEntry(
        context,
        delete: () async {
          await ref
              .read(maintenanceRepositoryProvider)
              .deleteServiceEntry(entry.id);
          await sweepAttachments(
            ref.read(attachmentRepositoryProvider),
            kind: AttachmentEntryKind.service,
            entryId: entry.id,
          );
        },
        refresh: () => ref
          ..invalidate(serviceEntriesProvider(vehicleId))
          ..invalidate(vehicleProjectionsProvider(vehicleId)),
      ),
      child: Card(
        child: ListTile(
          leading: Icon(Icons.build_outlined, color: context.tokens.muted),
          onTap: () =>
              showServiceEntrySheet(context, vehicleId, existing: entry),
          title: Text(labels),
          subtitle: Text(
            '${format.formatShortDate(entry.date)} · '
            '${format.formatDistance(entry.odometerKm.toDouble(), decimals: 0)}'
            '${entry.shop == null ? '' : ' · ${entry.shop}'}',
          ),
          trailing: entry.cost == null
              ? null
              : Text(
                  format.formatMoney(entry.cost),
                  style: GarageTheme.numeric(
                    Theme.of(context).textTheme.labelMedium!,
                  ),
                ),
        ),
      ),
    );
  }
}

class _ReadingHistoryRow extends ConsumerWidget {
  const _ReadingHistoryRow({
    required this.vehicleId,
    required this.entry,
    required this.format,
  });

  final String vehicleId;
  final OdometerEntry entry;
  final UnitFormat format;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    return Dismissible(
      key: ValueKey(entry.id),
      direction: DismissDirection.endToStart,
      background: const DeleteSwipeBackground(),
      confirmDismiss: (_) => confirmDelete(context),
      onDismissed: (_) => deleteSwipedEntry(
        context,
        delete: () => ref.read(odometerRepositoryProvider).delete(entry.id),
        refresh: () => ref
          ..invalidate(odometerEntriesProvider(vehicleId))
          ..invalidate(vehicleProjectionsProvider(vehicleId)),
      ),
      child: Card(
        child: ListTile(
          leading: Icon(Icons.speed_outlined, color: context.tokens.muted),
          onTap: () =>
              showOdometerEntrySheet(context, vehicleId, existing: entry),
          title: Text(l10n.odometerTitle),
          subtitle: Text(
            '${format.formatShortDate(entry.date)}'
            '${entry.notes == null ? '' : ' · ${entry.notes}'}',
          ),
          trailing: Text(
            format.formatDistance(entry.odometerKm.toDouble(), decimals: 0),
            style: GarageTheme.numeric(
              Theme.of(context).textTheme.labelMedium!,
            ),
          ),
        ),
      ),
    );
  }
}

/// Money in and money out for one car, in one list.
///
/// Separating them would make the reader add up two screens to answer "what
/// has this car cost me", which is the only question this tab exists for.
class _CostsTab extends ConsumerWidget {
  const _CostsTab({required this.vehicleId});

  final String vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    final format = UnitFormat(
      locale: locale,
      preferences: ref.watch(unitPreferencesProvider),
    );
    final costs = ref.watch(costEntriesProvider(vehicleId));
    final income = ref.watch(incomeEntriesProvider(vehicleId));
    // Fuel is spent money too, and it is the first money most people log;
    // a Costs tab saying "nothing yet" next to a cost card counting €61 of
    // it was a contradiction. Read-only here: fill-ups are edited in the
    // fuel log.
    final fuelSpend =
        (ref.watch(rawFuelEntriesProvider(vehicleId)).value ??
                const <FuelEntry>[])
            .fold<double>(0, (sum, e) => sum + (e.total ?? 0));

    return Column(
      children: [
        Expanded(
          child: AsyncValueView<List<CostEntry>>(
            value: costs,
            onRetry: () => ref
              ..invalidate(costEntriesProvider(vehicleId))
              ..invalidate(incomeEntriesProvider(vehicleId)),
            data: (costList) {
              final entries = <Object>[
                ...costList,
                ...income.value ?? const <IncomeEntry>[],
              ]..sort((a, b) => _moneyDate(b).compareTo(_moneyDate(a)));

              final fuelLine = fuelSpend > 0
                  ? ListTile(
                      key: const Key('costs-fuel-line'),
                      leading: const Icon(Icons.local_gas_station_outlined),
                      title: Text(
                        l10n.costsFuelLine(format.formatMoney(fuelSpend)),
                      ),
                      onTap: () => context.push('/vehicles/$vehicleId/fuel'),
                    )
                  : null;

              if (entries.isEmpty) {
                return ListView(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        GarageTokens.space4,
                        GarageTokens.space2,
                        GarageTokens.space4,
                        0,
                      ),
                      child: _RunningCostCard(
                        vehicleId: vehicleId,
                        format: format,
                      ),
                    ),
                    ?fuelLine,
                    EmptyState(
                      message: fuelLine == null
                          ? l10n.costsEmpty
                          : l10n.costsEmptyBeyondFuel,
                    ),
                  ],
                );
              }

              return LazyMonthList<Object>(
                // What the car costs to run belongs with what it cost: it
                // sat on the Economy tab, and "Costs" had no headline.
                leading: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      GarageTokens.space4,
                      GarageTokens.space2,
                      GarageTokens.space4,
                      0,
                    ),
                    child: _RunningCostCard(
                      vehicleId: vehicleId,
                      format: format,
                    ),
                  ),
                  ?fuelLine,
                ],
                padding: const EdgeInsets.symmetric(
                  vertical: GarageTokens.space2,
                ),
                groups: MonthGrouping.of(entries, _moneyDate),
                header: (context, group) =>
                    MonthHeader(month: group.month, locale: locale),
                row: (context, entry) => Padding(
                  padding: const EdgeInsets.fromLTRB(
                    GarageTokens.space4,
                    0,
                    GarageTokens.space4,
                    GarageTokens.space2,
                  ),
                  child: switch (entry) {
                    final CostEntry entry => _CostMoneyRow(
                      vehicleId: vehicleId,
                      entry: entry,
                      format: format,
                    ),
                    final IncomeEntry entry => _IncomeMoneyRow(
                      vehicleId: vehicleId,
                      entry: entry,
                      format: format,
                    ),
                    _ => const SizedBox.shrink(),
                  },
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(GarageTokens.space4),
          child: Row(
            spacing: GarageTokens.space3,
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => showCostEntrySheet(context, vehicleId),
                  icon: const Icon(Icons.add),
                  label: Text(l10n.costAdd),
                ),
              ),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => showIncomeEntrySheet(context, vehicleId),
                  icon: const Icon(Icons.savings_outlined),
                  label: Text(l10n.incomeAdd),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

DateTime _moneyDate(Object entry) => switch (entry) {
  final CostEntry entry => entry.date,
  final IncomeEntry entry => entry.date,
  _ => DateTime.utc(0),
};

class _CostMoneyRow extends ConsumerWidget {
  const _CostMoneyRow({
    required this.vehicleId,
    required this.entry,
    required this.format,
  });

  final String vehicleId;
  final CostEntry entry;
  final UnitFormat format;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    return Dismissible(
      key: ValueKey(entry.id),
      direction: DismissDirection.endToStart,
      background: const DeleteSwipeBackground(),
      confirmDismiss: (_) => confirmDelete(context),
      onDismissed: (_) => deleteSwipedEntry(
        context,
        delete: () async {
          await ref.read(costRepositoryProvider).delete(entry.id);
          await sweepAttachments(
            ref.read(attachmentRepositoryProvider),
            kind: AttachmentEntryKind.cost,
            entryId: entry.id,
          );
        },
        refresh: () => ref.invalidate(costEntriesProvider(vehicleId)),
      ),
      child: Card(
        child: ListTile(
          onTap: () => showCostEntrySheet(context, vehicleId, existing: entry),
          title: Text(costCategoryLabel(l10n, entry.category)),
          subtitle: Text(
            '${format.formatShortDate(entry.date)}'
            '${entry.notes == null ? '' : ' \u00b7 ${entry.notes}'}',
          ),
          trailing: Text(
            format.formatMoney(entry.amount),
            style: GarageTheme.numeric(
              Theme.of(context).textTheme.labelMedium!,
            ),
          ),
        ),
      ),
    );
  }
}

class _IncomeMoneyRow extends ConsumerWidget {
  const _IncomeMoneyRow({
    required this.vehicleId,
    required this.entry,
    required this.format,
  });

  final String vehicleId;
  final IncomeEntry entry;
  final UnitFormat format;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    return Dismissible(
      key: ValueKey(entry.id),
      direction: DismissDirection.endToStart,
      background: const DeleteSwipeBackground(),
      confirmDismiss: (_) => confirmDelete(context),
      onDismissed: (_) => deleteSwipedEntry(
        context,
        delete: () => ref.read(incomeRepositoryProvider).delete(entry.id),
        refresh: () => ref.invalidate(incomeEntriesProvider(vehicleId)),
      ),
      child: Card(
        child: ListTile(
          leading: Icon(Icons.savings_outlined, color: context.tokens.success),
          onTap: () =>
              showIncomeEntrySheet(context, vehicleId, existing: entry),
          title: Text(incomeCategoryLabel(l10n, entry.category)),
          subtitle: Text(
            '${format.formatShortDate(entry.date)}'
            '${entry.notes == null ? '' : ' \u00b7 ${entry.notes}'}',
          ),
          // Signed, because one column of unsigned amounts would show a refund
          // and a bill as the same thing.
          trailing: Text(
            '+${format.formatMoney(entry.amount)}',
            style: GarageTheme.numeric(
              Theme.of(context).textTheme.labelMedium!,
            ).copyWith(color: context.tokens.success),
          ),
        ),
      ),
    );
  }
}

class _RecallsCard extends ConsumerWidget {
  const _RecallsCard({required this.vehicleId});

  final String vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final vehicle = ref.watch(vehicleProvider(vehicleId)).value;
    final identified =
        vehicle?.make != null &&
        vehicle?.model != null &&
        vehicle?.year != null;

    final asked = ref.watch(recallCheckRequestedProvider(vehicleId));
    final recalls = identified && asked
        ? ref.watch(vehicleRecallsProvider(vehicleId))
        : const AsyncValue<List<Recall>>.data([]);
    if (recalls.hasError) {
      return const SizedBox.shrink();
    }

    final found = (recalls.value ?? const <Recall>[]).isNotEmpty;

    // Folded away by default. This is a US register, so for a European car it
    // is an optional check that usually finds nothing — and it was spending a
    // heading, a paragraph of caveat and a button on saying so, permanently,
    // on a screen whose actual subject is what the car needs next. Open, it
    // still says everything it did; a recall that is actually found opens it
    // by itself, because that is the one case worth the room.
    // No padding of its own. This is only ever used as the footer of a
    // ListView that already insets its children by `space4`, so adding another
    // here inset it twice and it came out visibly narrower than the service
    // cards above it.
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: const Key('recalls-card'),
        initiallyExpanded: found,
        leading: Icon(
          found ? Icons.warning_amber : Icons.verified_user_outlined,
          color: found ? context.tokens.danger : context.tokens.muted,
        ),
        title: Text(
          l10n.recallsTitle,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        childrenPadding: const EdgeInsets.fromLTRB(
          GarageTokens.space4,
          0,
          GarageTokens.space4,
          GarageTokens.space4,
        ),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!identified)
            Text(
              l10n.recallsNeedsDetails,
              style: TextStyle(color: context.tokens.muted),
            )
          // Asked for, not assumed. The lookup leaves the EU for a US
          // government API, and doing that on every visit to a vehicle
          // screen was a transfer the privacy policy did not describe —
          // it says NHTSA is contacted only when a button is pressed.
          // This is that button; the string for it had been sitting
          // unused in both languages.
          else if (!asked) ...[
            Text(
              l10n.recallsCaveat,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: context.tokens.muted),
            ),
            const SizedBox(height: GarageTokens.space2),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: OutlinedButton.icon(
                key: const Key('check-recalls'),
                icon: const Icon(Icons.travel_explore_outlined),
                label: Text(l10n.recallsCheck),
                onPressed: () =>
                    ref
                            .read(
                              recallCheckRequestedProvider(vehicleId).notifier,
                            )
                            .state =
                        true,
              ),
            ),
          ] else ...[
            for (final recall in recalls.value ?? const <Recall>[])
              Padding(
                padding: const EdgeInsets.only(bottom: GarageTokens.space2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${recall.component} · ${recall.campaign}',
                      style: TextStyle(color: context.tokens.danger),
                    ),
                    if (recall.summary != null) Text(recall.summary!),
                    if (recall.remedy != null)
                      Text(
                        recall.remedy!,
                        style: TextStyle(color: context.tokens.muted),
                      ),
                  ],
                ),
              ),
            if ((recalls.value ?? const []).isEmpty)
              Text(
                l10n.recallsNone,
                style: TextStyle(color: context.tokens.muted),
              ),
            const SizedBox(height: GarageTokens.space1),
            Text(
              l10n.recallsCaveat,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: context.tokens.muted),
            ),
          ],
        ],
      ),
    );
  }
}

/// What the car costs to run, with fuel and upkeep separated.
///
/// The three kinds of spending live in three tables because they answer
/// different questions; this is the one question that needs all of them at
/// once, and it is the figure a driver actually quotes about a car.
class _RunningCostCard extends ConsumerWidget {
  const _RunningCostCard({required this.vehicleId, required this.format});

  final String vehicleId;
  final UnitFormat format;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final cost = ref.watch(runningCostProvider(vehicleId)).value;
    final perKm = cost?.perKm;
    // The same rule as economy: one tank over 450 km printed "€0.136/km"
    // to three decimals while the dashboard had just said one more full
    // tank was needed. The totals below are true from the first entry; the
    // per-distance figure is not.
    final economyReady =
        ref.watch(averageEconomyProvider(vehicleId)).value != null;
    final vehicle = ref.watch(vehicleProvider(vehicleId)).value;
    final purchasePrice = vehicle?.purchasePrice;
    final ownership = cost?.costOfOwnership(purchasePrice);

    // What the car costs to *own* rather than to run: the running figure plus
    // the value it has lost. The honest number, and the one a keep-it-or-sell-
    // it decision actually rests on — this card printed only the other half
    // for as long as it existed.
    final ownPerKm = cost?.ownPerKm(
      purchasePrice: purchasePrice,
      currentValue: vehicle?.currentValue,
    );
    final valuationStale = valuationIsStale(
      valuedOn: vehicle?.valuedOn,
      today: ref.watch(todayProvider),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(GarageTokens.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.runningCostTitle.toUpperCase(),
              style: GarageTheme.eyebrow(context),
            ),
            const SizedBox(height: GarageTokens.space3),
            if (cost == null || perKm == null || !cost.hasSpending)
              Text(
                l10n.runningCostNotEnough,
                style: TextStyle(color: context.tokens.muted),
              )
            else ...[
              // Through `formatCostPerDistance`, which converts and carries
              // its own unit. This card printed a per-kilometre figure under a
              // fixed "Per kilometre" caption, so a household reading miles was
              // shown neither its own unit nor a number in it — the exact bug
              // that helper's docstring records being fixed for the fuel log,
              // and never applied here. The caption goes with it: the figure
              // now says "/km" or "/mi" itself, which the label could not.
              Text(
                key: const Key('running-cost-per-distance'),
                economyReady
                    ? format.formatCostPerDistance(perKm, decimals: 3)
                    : UnitFormat.emptyValue,
                style: GarageTheme.numeric(
                  Theme.of(context).textTheme.headlineSmall!,
                ),
              ),
              const SizedBox(height: GarageTokens.space2),
              // Under the running rate, in the same units, so the two read as
              // one sentence: this much to drive it, this much to keep it.
              if (economyReady && ownPerKm != null) ...[
                Text(
                  key: const Key('own-cost-per-distance'),
                  l10n.runningCostToOwn(
                    format.formatCostPerDistance(ownPerKm, decimals: 3),
                  ),
                  style: TextStyle(color: context.tokens.muted),
                ),
                // The span the figure is measured over, stated rather than
                // assumed. A car bought years before it was logged has lost
                // its value over a distance this app never saw, and the rate
                // reads high with nothing on screen to say why (roadmap 11).
                if (vehicle?.baselineDate case final since?)
                  Text(
                    key: const Key('own-cost-span'),
                    l10n.runningCostOwnSpan(
                      format.formatDistance(
                        cost.distanceKm.toDouble(),
                        decimals: 0,
                      ),
                      format.formatDate(since.toLocal()),
                    ),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.tokens.muted,
                    ),
                  ),
                if (valuationStale)
                  Text(
                    l10n.runningCostValuationStale,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: context.tokens.warn),
                  ),
                const SizedBox(height: GarageTokens.space2),
              ],
              if (!economyReady)
                Text(
                  l10n.runningCostNeedsTank,
                  style: TextStyle(color: context.tokens.muted),
                )
              else
                // Fuel and upkeep apart, because a driver asks about them apart:
                // one is how the car is driven, the other how it is looked after.
                // Wrap, not a Row: two money figures with labels do not fit on
                // one line on a phone.
                Wrap(
                  spacing: GarageTokens.space3,
                  children: [
                    Text(
                      l10n.runningCostFuelShare(
                        format.formatCostPerDistance(
                          cost.fuelPerKm,
                          decimals: 3,
                        ),
                      ),
                      style: TextStyle(color: context.tokens.muted),
                    ),
                    Text(
                      l10n.runningCostUpkeepShare(
                        format.formatCostPerDistance(
                          cost.upkeepPerKm,
                          decimals: 3,
                        ),
                      ),
                      style: TextStyle(color: context.tokens.muted),
                    ),
                  ],
                ),
              const Divider(height: GarageTokens.space6),
              _CostRow(
                label: l10n.runningCostPerMonth,
                value: format.formatMoney(cost.perMonth),
              ),
              _CostRow(
                label: l10n.runningCostPerYear,
                value: format.formatMoney(cost.perYear),
              ),
              _CostRow(
                label: l10n.runningCostTotal,
                // As paid: the spread figure belongs to the rates above it.
                value: format.formatMoney(cost.paid),
              ),
              if (cost.spreads)
                Padding(
                  padding: const EdgeInsets.only(top: GarageTokens.space1),
                  child: Text(
                    l10n.runningCostSpread,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.tokens.muted,
                    ),
                  ),
                ),
              if (ownership != null)
                _CostRow(
                  label: l10n.runningCostOwnership,
                  value: format.formatMoney(ownership),
                ),
              const Divider(height: GarageTokens.space6),
              // Where the money went, because a single total invites the
              // question and does not answer it.
              Text(
                l10n.runningCostBreakdown.toUpperCase(),
                style: GarageTheme.eyebrow(context),
              ),
              const SizedBox(height: GarageTokens.space2),
              _CostRow(
                label: l10n.runningCostFuelTotal,
                value: format.formatMoney(cost.fuel),
              ),
              _CostRow(
                label: l10n.runningCostServiceTotal,
                value: format.formatMoney(cost.service),
              ),
              _CostRow(
                label: l10n.runningCostOtherTotal,
                // As paid, like the two rows above it, so the three add up to
                // the total this list sits under.
                value: format.formatMoney(cost.otherPaid),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CostRow extends StatelessWidget {
  const _CostRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: GarageTokens.space1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Expanded: "Since you added it", and its longer Croatian
          // counterpart, leaves no room for a currency figure beside it on a
          // phone.
          Expanded(child: Text(label)),
          const SizedBox(width: GarageTokens.space3),
          Text(
            value,
            style: GarageTheme.numeric(Theme.of(context).textTheme.bodyMedium!),
          ),
        ],
      ),
    );
  }
}

enum _VehicleAction {
  edit,
  calendar,
  tyres,
  documents,
  lentHistory,
  lending,
  transfer,
  report,
  archive,
  restore,
  delete,
}

/// Everything the vehicle menu can do.
///
/// The first three navigate or open a dialog and are done. The last three
/// change what the garage holds, which is why they share the confirm-report-
/// refresh path below, and why archiving is offered above delete: the history
/// is usually the reason the vehicle was here at all, and a sale — the common
/// case — is one where keeping the record is what a seller wants.
Future<void> _runVehicleAction(
  BuildContext context,
  WidgetRef ref,
  String vehicleId,
  _VehicleAction action,
) async {
  final l10n = AppLocalizations.of(context)!;
  final messenger = ScaffoldMessenger.of(context);
  final container = ProviderScope.containerOf(context);
  final router = GoRouter.of(context);

  switch (action) {
    case _VehicleAction.edit:
      router.push('/vehicles/$vehicleId/edit');
      return;
    case _VehicleAction.calendar:
      // The item says Calendar; the screen opened on its List tab, which is
      // the Reminders tab a second time in different chrome.
      router.push('/vehicles/$vehicleId/maintenance?tab=calendar');
      return;
    case _VehicleAction.tyres:
      router.push('/vehicles/$vehicleId/tyres');
      return;
    case _VehicleAction.documents:
      router.push('/vehicles/$vehicleId/documents');
      return;
    case _VehicleAction.lentHistory:
      router.push('/vehicles/$vehicleId/lent-history');
      return;
    case _VehicleAction.lending:
      router.push('/vehicles/$vehicleId/lending');
      return;
    case _VehicleAction.transfer:
      router.push('/transfer?v=$vehicleId');
      return;
    case _VehicleAction.report:
      // Returned rather than awaited: awaiting here puts an async gap ahead of
      // the `context` the confirm dialog below uses, on a path that never
      // reaches it.
      return VehicleDetailScreen._createReport(context, ref, vehicleId);
    case _VehicleAction.archive:
    case _VehicleAction.restore:
    case _VehicleAction.delete:
      break;
  }

  // Archive asks like Delete does: it sat two rows above Delete in the same
  // menu and ran on one tap, taking the household's main car off every
  // screen and total. Not in red, though: it offers Undo the moment it is
  // done, and red is for what cannot be undone (decision 85).
  if (action == _VehicleAction.delete) {
    final confirmed = await confirmDestructive(
      context,
      title: l10n.vehicleDeleteTitle,
      body: l10n.vehicleDeleteBody,
      confirmLabel: l10n.commonDelete,
    );
    if (!confirmed) {
      return;
    }
  } else if (action == _VehicleAction.archive) {
    final confirmed = await confirmAction(
      context,
      title: l10n.vehicleArchiveTitle,
      body: l10n.vehicleArchiveBody,
      confirmLabel: l10n.vehicleArchive,
    );
    if (!confirmed) {
      return;
    }
  }

  try {
    final repository = ref.read(vehicleRepositoryProvider);
    switch (action) {
      case _VehicleAction.archive:
        await repository.setArchived(vehicleId, true);
        messenger.showSnackBar(
          SnackBar(
            content: Text(l10n.vehicleArchived),
            // Explicit: with an action attached it sat over the next
            // screen's buttons long after the car was restored.
            duration: const Duration(seconds: 8),
            action: SnackBarAction(
              label: l10n.commonUndo,
              // Through the container, not `ref`: by the time Undo is
              // tapped this page has navigated away and its ref is gone.
              onPressed: () async {
                try {
                  await repository.setArchived(vehicleId, false);
                } catch (error) {
                  // The snackbar that carried this button is gone; say what
                  // happened rather than leaving the car archived in silence.
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        failureMessage(l10n, AppFailure.from(error)),
                      ),
                    ),
                  );
                  return;
                }
                container.invalidate(garageBootstrapProvider);
              },
            ),
          ),
        );
      case _VehicleAction.restore:
        await repository.setArchived(vehicleId, false);
        messenger.showSnackBar(SnackBar(content: Text(l10n.vehicleRestored)));
      case _VehicleAction.delete:
        await repository.delete(vehicleId);
      case _VehicleAction.edit:
      case _VehicleAction.calendar:
      case _VehicleAction.tyres:
      case _VehicleAction.documents:
      case _VehicleAction.lentHistory:
      case _VehicleAction.lending:
      case _VehicleAction.transfer:
      case _VehicleAction.report:
        // Returned above; listed so another action cannot be added without
        // deciding which half of this it belongs to.
        return;
    }
  } catch (error) {
    messenger.showSnackBar(
      SnackBar(content: Text(failureMessage(l10n, AppFailure.from(error)))),
    );
    return;
  }

  ref.invalidate(garageBootstrapProvider);
  // Refetched before the list is shown, or it opened on the previous value
  // and a restored car sat under "Archived" until the page was reopened.
  await ref.read(allVehiclesProvider.future);
  // Back to the list either way: the screen we are on is about a vehicle that
  // is now archived or gone, and leaving it up shows a stale one.
  router.go('/vehicles');
}

/// An icon beside its label, so the menu reads at a glance rather than as five
/// lines of similar-length text.
class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label, this.colour});

  final IconData icon;
  final String label;
  final Color? colour;

  @override
  Widget build(BuildContext context) {
    final tint = colour ?? IconTheme.of(context).color;
    return Row(
      children: [
        Icon(icon, size: 20, color: tint),
        const SizedBox(width: GarageTokens.space3),
        // Expanded, and allowed to wrap: a popup menu is 256 logical pixels
        // wide and Croatian runs longer than English everywhere in this app.
        Expanded(
          child: Text(label, style: TextStyle(color: colour)),
        ),
      ],
    );
  }
}

/// The way into the reminder sheet, at the top of what is due whatever the
/// list holds.
class _AddReminderRow extends StatelessWidget {
  const _AddReminderRow({required this.vehicleId});

  final String vehicleId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(bottom: GarageTokens.space2),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: FilledButton.tonalIcon(
          key: const Key('service-tab-add-rule'),
          onPressed: () => showReminderRuleSheet(context, vehicleId),
          icon: const Icon(Icons.add_alarm_outlined),
          label: Text(l10n.maintenanceAddRule),
        ),
      ),
    );
  }
}
