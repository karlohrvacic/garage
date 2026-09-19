import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';

import '../../../core/clock.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/format/unit_format.dart';
import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/confirm_delete.dart';
import '../../../core/widgets/failure_message.dart';
import '../../../domain/company/assignment_resolution.dart';
import '../../../domain/entities/vehicle.dart';
import '../../../domain/entities/vehicle_assignment.dart';
import '../../household/providers/household_providers.dart';
import '../../household/providers/member_providers.dart';
import '../../settings/providers/unit_providers.dart';
import '../../vehicles/providers/vehicle_providers.dart';
import '../member_name.dart';
import '../providers/company_providers.dart';
import 'fleet_retry.dart';
import 'handover_sheet.dart';

/// Cars as rows, who has each one today, and a handover per row.
///
/// A list of rows in the app's own idiom rather than a data table: every
/// row is a card with a button, which reads the same on the phone an admin
/// happens to have in hand as on the desk the console is built for.
class DriversAndCarsTab extends ConsumerWidget {
  const DriversAndCarsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final format = UnitFormat(
      locale: Localizations.localeOf(context).languageCode,
      preferences: ref.watch(unitPreferencesProvider),
    );
    final log = ref.watch(fleetAssignmentsProvider);
    final names = ref.watch(memberNamesProvider);
    final today = ref.watch(todayProvider);
    // A read that failed before anything arrived: the cache serves last-good
    // rows on a network failure only, so a refusal or a server error on the
    // first load has nothing to fall back on. Said above the list, and the
    // cause logged, rather than "Nobody" on every car with nothing to report.
    // Once per build and deduplicated, since both reads usually fail alike.
    final failures = {
      for (final read in [log, names])
        if (!read.hasValue && read.hasError)
          failureMessage(l10n, AppFailure.from(read.error!)),
    };
    final loading =
        failures.isEmpty && [log, names].any((read) => !read.hasValue);

    return AsyncValueView<List<Vehicle>>(
      value: ref.watch(vehiclesProvider),
      onRetry: () => ref.invalidate(garageBootstrapProvider),
      empty: () => EmptyState(message: l10n.companyNoCars),
      data: (cars) {
        if (loading) {
          return const Center(child: CircularProgressIndicator());
        }
        final assignments = log.value;
        return ListView(
          padding: const EdgeInsets.all(GarageTokens.space4),
          children: [
            for (final failure in failures)
              Padding(
                padding: const EdgeInsets.only(bottom: GarageTokens.space3),
                child: Text(
                  failure,
                  style: TextStyle(color: context.tokens.danger),
                ),
              ),
            // The log and the members are kept alive and never retried on
            // their own, so without this only a resume or a realtime event
            // read them again. The fleet's Retry, like every other tab's.
            if (failures.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: GarageTokens.space3),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: OutlinedButton(
                    onPressed: fleetRetry(ref, [
                      fleetAssignmentsProvider,
                      membersProvider,
                    ]),
                    child: Text(l10n.commonRetry),
                  ),
                ),
              ),
            for (final car in cars)
              _CarRow(
                key: Key('company-car-${car.id}'),
                vehicle: car,
                open: assignments == null
                    ? null
                    : AssignmentResolution.openFor(
                        assignments,
                        vehicleId: car.id,
                        today: today,
                      ),
                history: assignments == null
                    ? null
                    : AssignmentResolution.historyOf(assignments, car.id),
                names: names.value,
                format: format,
              ),
          ],
        );
      },
    );
  }
}

class _CarRow extends ConsumerWidget {
  const _CarRow({
    super.key,
    required this.vehicle,
    required this.open,
    required this.history,
    required this.names,
    required this.format,
  });

  final Vehicle vehicle;

  /// The window that holds today, whose driver the row names.
  final VehicleAssignment? open;

  /// Every window the car has had, newest first. Null when the log could
  /// not be read: the row then claims nothing about a driver, and the line
  /// above the list says why.
  final List<VehicleAssignment>? history;

  /// Null while the member list is unknown, for the same reason: a name
  /// that is not in a list nobody has read is not a departed member's.
  final Map<String, String>? names;
  final UnitFormat format;

  /// "Former member" for somebody the list no longer names, as every other
  /// reader of the log prints one; blank for a deleted account, whose
  /// window keeps its dates and loses its driver, and while the list is
  /// unknown, when the line above the rows says why.
  String _name(AppLocalizations l10n, String? userId) {
    return switch ((names, userId)) {
      (final known?, final id?) => memberNameOf(l10n, known, id),
      _ => '',
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final current = open;
    final known = history;
    final earlier = [
      for (final assignment in known ?? const <VehicleAssignment>[])
        if (assignment.id != current?.id) assignment,
    ];
    // What the menu removes: the newest window still open. Usually the one
    // the row names, but a handover arranged on Friday for Monday is open
    // too, is not today's, and is the likelier mistake.
    final removable = known?.where((it) => it.isOpen).firstOrNull;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(GarageTokens.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        [vehicle.nickname, ?vehicle.plate].join(' · '),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (known != null) ...[
                        const SizedBox(height: GarageTokens.space1),
                        Text(
                          '${l10n.companyCurrentDriver}: '
                          '${current == null ? l10n.companyNobody : _name(l10n, current.userId)}',
                        ),
                      ],
                      if (current != null)
                        Text(
                          [
                            l10n.companySince(
                              format.formatDate(current.fromDate),
                            ),
                            current.isConfirmed
                                ? l10n.companyConfirmedOn(
                                    format.formatDate(
                                      current.confirmedAt!.toLocal(),
                                    ),
                                  )
                                : l10n.companyUnconfirmed,
                          ].join(' · '),
                          style: TextStyle(color: tokens.muted),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: GarageTokens.space3),
                FilledButton.tonal(
                  key: Key('company-handover-${vehicle.id}'),
                  onPressed: () => showHandoverSheet(
                    context,
                    vehicle: vehicle,
                    current: current,
                  ),
                  child: Text(l10n.companyHandOver),
                ),
                if (removable != null)
                  PopupMenuButton<String>(
                    key: Key('company-car-menu-${vehicle.id}'),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'remove',
                        child: Text(l10n.companyRemoveAssignment),
                      ),
                    ],
                    onSelected: (_) => _remove(context, ref, removable),
                  ),
              ],
            ),
            if (earlier.isNotEmpty) ...[
              const SizedBox(height: GarageTokens.space3),
              Text(
                l10n.companyEarlierDrivers.toUpperCase(),
                style: GarageTheme.eyebrow(context),
              ),
              for (final assignment in earlier.take(5))
                Text(switch (assignment.toDate) {
                  final to? => l10n.companyAssignmentRange(
                    format.formatDate(assignment.fromDate),
                    _name(l10n, assignment.userId),
                    format.formatDate(to),
                  ),
                  // Open and not today's: a handover arranged ahead.
                  null => l10n.companyAssignmentFrom(
                    format.formatDate(assignment.fromDate),
                    _name(l10n, assignment.userId),
                  ),
                }, style: TextStyle(color: tokens.muted)),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    VehicleAssignment assignment,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    // The database allows deleting a signed window (migration 0080), so the
    // question says what else goes: the driver's sign-off is evidence for a
    // fine, and nothing brings it back.
    final confirmed = await confirmDestructive(
      context,
      title: l10n.companyRemoveAssignment,
      body: [
        l10n.companyRemoveAssignmentBody(
          format.formatDate(assignment.fromDate),
          _name(l10n, assignment.userId),
        ),
        if (assignment.isConfirmed) l10n.companyRemoveSignedBody,
      ].join(' '),
      confirmLabel: l10n.commonDelete,
    );
    if (!confirmed) {
      return;
    }
    final ok = await ref
        .read(companyControllerProvider.notifier)
        .removeAssignment(assignment);
    if (ok) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.companyAssignmentRemoved)),
      );
    } else if (context.mounted) {
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
}
