import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

import '../../../core/clock.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/files/file_saver.dart';
import '../../../core/format/unit_format.dart';
import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/failure_message.dart';
import '../../../core/widgets/pick_one.dart';
import '../../../domain/company/money_entry.dart';
import '../../../domain/export/export_file_name.dart';
import '../../attachments/providers/attachment_providers.dart';
import '../../costs/providers/cost_providers.dart';
import '../../fuel/providers/fuel_providers.dart';
import '../../household/providers/member_providers.dart';
import '../../maintenance/providers/service_entry_providers.dart';
import '../../settings/providers/unit_providers.dart';
import '../../vehicles/providers/vehicle_providers.dart';
import '../providers/company_providers.dart';
import '../providers/pack_assembly.dart';
import '../providers/receipt_providers.dart';
import '../providers/reimbursement_providers.dart';
import 'driver_on_date.dart';
import 'fleet_retry.dart';
import 'missing_receipt_row.dart';
import 'paid_with_field.dart';

/// What leaves for the accountant: first what is still missing, then one
/// button for the month.
class AccountantPackTab extends ConsumerStatefulWidget {
  const AccountantPackTab({super.key});

  @override
  ConsumerState<AccountantPackTab> createState() => _AccountantPackTabState();
}

class _AccountantPackTabState extends ConsumerState<AccountantPackTab> {
  DateTime? _month;
  bool _building = false;

  /// Receipts fetched so far, of how many: set once the assembly knows how
  /// many there are, null before that and between builds.
  (int, int)? _progress;

  DateTime _thisMonth() {
    final today = ref.read(todayProvider);
    return DateTime.utc(today.year, today.month);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    final format = UnitFormat(
      locale: locale,
      preferences: ref.watch(unitPreferencesProvider),
    );
    final month = _month ?? _thisMonth();
    final names =
        ref.watch(memberNamesProvider).value ?? const <String, String>{};
    // The same cars the list is drawn from, sold ones included: a row for
    // a car the active list no longer has would otherwise open with a dot.
    final cars = {
      for (final vehicle in ref.watch(allVehiclesProvider).value ?? const [])
        vehicle.id: vehicle.nickname,
    };

    return ListView(
      padding: const EdgeInsets.all(GarageTokens.space4),
      children: [
        Text(
          l10n.companyPackHint,
          style: TextStyle(color: context.tokens.muted),
        ),
        const SizedBox(height: GarageTokens.space4),
        ListTile(
          key: const Key('pack-month'),
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.companyPackMonth),
          subtitle: Text(DateFormat.yMMMM(locale).format(month)),
          trailing: const Icon(Icons.chevron_right),
          onTap: _pickMonth,
        ),
        const SizedBox(height: GarageTokens.space4),
        Text(
          l10n.companyMissingReceipts.toUpperCase(),
          style: GarageTheme.eyebrow(context),
        ),
        AsyncValueView<List<MoneyEntry>>(
          value: ref.watch(missingReceiptsProvider(month)),
          onRetry: fleetRetry(ref, [
            rawFuelEntriesProvider,
            serviceEntriesProvider,
            costEntriesProvider,
            entriesWithAttachmentsProvider,
            fleetMoneyEntriesProvider,
            missingReceiptsProvider,
          ]),
          data: (missing) {
            if (missing.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: GarageTokens.space2,
                ),
                child: Text(
                  l10n.companyMissingReceiptsNone,
                  style: TextStyle(color: context.tokens.muted),
                ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final entry in missing)
                  MissingReceiptRow(
                    title: [
                      ?cars[entry.vehicleId],
                      moneyEntryKindLabel(l10n, entry.kind),
                      format.formatDate(entry.date),
                    ].join(' · '),
                    amount: format.formatMoney(entry.amount),
                    detail: DriverOnDate(
                      vehicleId: entry.vehicleId,
                      date: entry.date,
                    ),
                    actionLabel: l10n.companyRemindDriver,
                    actionKey: Key('remind-${entry.id}'),
                    onAction: switch (ref.watch(
                      driverOnProvider((
                        vehicleId: entry.vehicleId,
                        date: entry.date,
                      )),
                    )) {
                      // Nobody had the car that day: nobody to remind. A
                      // driver who has since left cannot be reminded either
                      // (the function refuses a non-member), and the row's
                      // driver line already says who they were.
                      null => null,
                      final driverId when !names.containsKey(driverId) => null,
                      final driverId => () => _remind(
                        entry,
                        driverId,
                        names[driverId]!,
                      ),
                    },
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: GarageTokens.space6),
        FilledButton.icon(
          key: const Key('build-pack'),
          onPressed: _building ? null : () => _build(month),
          icon: const Icon(Icons.archive_outlined),
          label: Text(l10n.companyPackBuild),
        ),
        // A pack of two hundred receipts is a while: the count says it is
        // moving.
        if (_progress case (final done, final total)?)
          Padding(
            padding: const EdgeInsets.only(top: GarageTokens.space2),
            child: Text(
              l10n.companyPackFetching(done, total),
              key: const Key('pack-progress'),
              textAlign: TextAlign.center,
              style: TextStyle(color: context.tokens.muted),
            ),
          ),
      ],
    );
  }

  Future<void> _pickMonth() async {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    final current = _thisMonth();
    // This month, and the five before it. A pack is built in the first days
    // of the next month; six is far enough back for a quarter that slipped.
    final options = [
      for (var back = 0; back < 6; back++)
        DateTime.utc(current.year, current.month - back),
    ];
    final picked = await showPickOne<DateTime>(
      context,
      title: l10n.companyPackMonth,
      options: [
        for (final month in options)
          PickOption(month, DateFormat.yMMMM(locale).format(month)),
      ],
    );
    if (picked != null && mounted) {
      setState(() => _month = picked);
    }
  }

  Future<void> _remind(MoneyEntry entry, String driverId, String name) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await ref
        .read(companyControllerProvider.notifier)
        .remindDriver(entry, driverId: driverId);
    if (ok) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.companyReminderSent(name))),
      );
    } else if (mounted) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            failureMessage(
              l10n,
              failureOf(ref.read(companyControllerProvider)),
            ),
          ),
        ),
      );
    }
  }

  /// Builds the month and hands it to the save dialog. Nothing is saved
  /// until everything is in hand: a download that fails part-way is said,
  /// and no half-built pack reaches the accountant.
  Future<void> _build(DateTime month) async {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    final messenger = ScaffoldMessenger.of(context);
    final format = UnitFormat(
      locale: locale,
      preferences: ref.read(unitPreferencesProvider),
    );
    setState(() => _building = true);
    try {
      final bytes = await ref
          .read(accountantPackAssemblyProvider)
          .build(
            month: month,
            locale: locale,
            l10n: l10n,
            format: format,
            // Nothing to count while the receipts are still being listed,
            // and nothing to say for a month without any.
            onProgress: (done, total) {
              if (mounted) {
                setState(() => _progress = total == 0 ? null : (done, total));
              }
            },
          );
      // The tab was left while the pack was being built: nothing to save
      // it from, and the ref it would be read through is gone.
      if (!mounted) {
        return;
      }
      // Named for the month inside, which is what the accountant files it
      // under, not the day it was built.
      final fileName = exportFileName(ExportKind.pack, on: month);
      final saved = await ref.read(fileSaverProvider)(
        fileName: fileName,
        bytes: bytes,
        mimeType: 'application/zip',
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            saved ? l10n.companyPackSaved(fileName) : l10n.companyPackNotSaved,
          ),
        ),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(failureMessage(l10n, AppFailure.from(error)))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _building = false;
          _progress = null;
        });
      }
    }
  }
}
