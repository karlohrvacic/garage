import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

import '../../../core/clock.dart';
import '../../../core/format/unit_format.dart';
import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../core/widgets/adaptive.dart';
import '../../../core/widgets/empty_state_art.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/confirm_delete.dart';
import '../../../core/widgets/garage_bottom_nav.dart';
import '../../../core/widgets/vehicle_photo.dart';
import '../../../domain/entities/vehicle.dart';
import '../../company/providers/company_providers.dart';
import '../../company/widgets/driver_notice_card.dart';
import '../../company/widgets/pending_handovers_card.dart';
import '../../settings/providers/unit_providers.dart';
import '../providers/guest_pass_providers.dart';
import '../widgets/code_box_sheet.dart';
import '../providers/vehicle_providers.dart';
import '../../household/providers/household_providers.dart';
import '../widgets/on_loan_badge.dart';

class VehiclesScreen extends ConsumerStatefulWidget {
  const VehiclesScreen({super.key});

  @override
  ConsumerState<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends ConsumerState<VehiclesScreen> {
  String _query = '';

  /// The form, or the reason there is none. The insert policy refuses a
  /// sixth car on a free garage with a bare permission error (migration
  /// 0080), which is not what a full garage needs to hear: this says which
  /// it is — the free cap, or a company plan that ended — before the form.
  Future<void> _addVehicle({required bool canAdd}) async {
    if (canAdd) {
      await context.push('/vehicles/new');
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    final household = ref.read(currentHouseholdProvider).value;
    final format = UnitFormat(
      locale: Localizations.localeOf(context).languageCode,
      preferences: ref.read(unitPreferencesProvider),
    );
    // Lapsed by the household's own rule, so the two screens that say it
    // cannot drift; a lapsed plan has an end by definition, and that is the
    // date the sentence names.
    final lapsedOn =
        household != null &&
            household.companyLapsedAt(ref.read(clockProvider)())
        ? household.planUntil
        : null;
    await showNotice(
      context,
      content: Text(
        lapsedOn == null
            ? l10n.errorPlanLimit
            : l10n.companyPlanLapsed(format.formatDate(lapsedOn.toLocal())),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final vehicles = ref.watch(vehiclesProvider);
    // A driver's list is the cars handed to them, and nothing on it is
    // theirs to add, archive or restore: the administrator does that from
    // the console, and every such write is refused for a driver anyway.
    final driver = ref.watch(isDriverProvider);
    // Watched here rather than read on the tap, so the household and the
    // list it depends on have resolved by the time anybody taps.
    final canAdd = ref.watch(canAddVehicleProvider);
    final showSearch = (vehicles.value?.length ?? 0) > 3;
    // A query typed while the box was shown must not outlive the box: with
    // the fourth car gone there would be nothing left to clear it with.
    final query = showSearch ? _query : '';
    final format = UnitFormat(
      locale: Localizations.localeOf(context).languageCode,
      preferences: ref.watch(unitPreferencesProvider),
    );

    return GarageTabScaffold(
      current: GarageTab.vehicles,
      // The garage is a set of cards, and cards tile. A column of them down a
      // 1500px window is the phone list this layout exists to stop.
      contentWidth: ContentWidth.wide,
      title: driver ? l10n.companyMyCars : l10n.vehiclesTitle,
      actions: [
        // One box for all three kinds of code. A buyer with a transfer code, a
        // borrower with a lending code and somebody joining a garage all
        // arrive holding eight characters and no way to tell which they have;
        // three entry points under three names made that their problem, and
        // the lending one was in Settings, where nobody looked.
        IconButton(
          key: const Key('vehicles-code-box'),
          icon: const Icon(Icons.key_outlined),
          tooltip: l10n.codeBoxAction,
          onPressed: () => showCodeBoxSheet(context),
        ),
      ],
      // The empty state has its own Add vehicle; two of the same button on
      // one screen is one too many.
      floatingActionButton: driver || (vehicles.value?.isEmpty ?? true)
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _addVehicle(canAdd: canAdd),
              icon: const Icon(Icons.add),
              label: Text(l10n.vehiclesAdd),
            ),
      body: Column(
        children: [
          // A search box over one, two or three cars is a control with
          // nothing to do; the whole list is on screen.
          if (showSearch)
            Padding(
              padding: const EdgeInsets.all(GarageTokens.space4),
              child: TextField(
                decoration: InputDecoration(
                  labelText: l10n.vehicleSearch,
                  prefixIcon: const Icon(Icons.search),
                ),
                onChanged: (value) =>
                    setState(() => _query = value.toLowerCase()),
              ),
            ),
          Expanded(
            child: AsyncValueView<List<Vehicle>>(
              value: vehicles,
              onRetry: () => ref.invalidate(garageBootstrapProvider),
              // No `empty:`. Archiving the only car showed "No vehicles yet"
              // with no archived section and no way back to the car: the
              // one-way trip the section below exists to prevent.
              data: (list) {
                final filtered = list
                    .where(
                      (v) => [v.nickname, v.make, v.model, v.plate]
                          .whereType<String>()
                          .any((f) => f.toLowerCase().contains(query)),
                    )
                    .toList(growable: false);
                final archived =
                    ref.watch(archivedVehiclesProvider).value ??
                    const <Vehicle>[];
                final borrowed =
                    ref.watch(borrowedVehiclesProvider).value ??
                    const <Vehicle>[];
                return ListView(
                  padding: const EdgeInsets.fromLTRB(
                    GarageTokens.space4,
                    0,
                    GarageTokens.space4,
                    GarageTokens.fabClearance,
                  ),
                  children: [
                    // A driver adds nothing: the administrator hands a car
                    // over, and the empty state says so instead of offering
                    // a button the policy would refuse.
                    if (list.isEmpty)
                      EmptyState(
                        motif: EmptyStateMotif.garage,
                        message: driver
                            ? l10n.companyMyCarsEmpty
                            : l10n.vehiclesEmpty,
                        action: driver
                            ? null
                            : FilledButton(
                                onPressed: () => context.push('/vehicles/new'),
                                child: Text(l10n.vehiclesAdd),
                              ),
                      ),
                    if (driver) ...[
                      const DriverNoticeCard(),
                      const PendingHandoversCard(),
                    ],
                    // Every card is the same height, so alternating them
                    // between the columns reads as a grid of two vehicles per
                    // row rather than as two unrelated stacks.
                    AdaptiveColumns(
                      children: [
                        for (final vehicle in filtered)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: GarageTokens.space2,
                            ),
                            child: _VehicleCard(
                              key: Key('vehicle-${vehicle.id}'),
                              vehicle: vehicle,
                              format: format,
                            ),
                          ),
                      ],
                    ),
                    // A car somebody lent you is not in your garage — it is
                    // not counted in its totals and it leaves when the pass
                    // does — so it gets its own heading rather than sitting
                    // among cars you own.
                    if (borrowed.isNotEmpty) ...[
                      const SizedBox(height: GarageTokens.space6),
                      Text(
                        l10n.guestBorrowedBadge.toUpperCase(),
                        style: GarageTheme.eyebrow(context),
                      ),
                      const SizedBox(height: GarageTokens.space2),
                      AdaptiveColumns(
                        children: [
                          for (final vehicle in borrowed)
                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: GarageTokens.space2,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _VehicleCard(
                                    key: Key('borrowed-${vehicle.id}'),
                                    vehicle: vehicle,
                                    format: format,
                                  ),
                                  // When it stops being yours. A loan with no
                                  // end on screen is one you find out about by
                                  // opening the app and finding the car gone.
                                  if (ref.watch(
                                        guestPassForVehicleProvider(vehicle.id),
                                      )
                                      case final pass?)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        left: GarageTokens.space4,
                                        top: GarageTokens.space1,
                                      ),
                                      child: Text(
                                        l10n.guestBorrowedUntil(
                                          format.formatDate(
                                            pass.expiresAt.toLocal(),
                                          ),
                                        ),
                                        style: TextStyle(
                                          color: context.tokens.muted,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                    // Below the working garage, and only when there is
                    // something in it. Archiving with nowhere to see the
                    // result is a one-way trip: the vehicle vanishes from
                    // every list and the restore action lives on a screen
                    // that can no longer be reached. Not for a driver, who
                    // can restore nothing and was handed the working cars.
                    if (!driver && archived.isNotEmpty) ...[
                      const SizedBox(height: GarageTokens.space6),
                      Text(
                        l10n.vehiclesArchivedSection.toUpperCase(),
                        style: GarageTheme.eyebrow(context),
                      ),
                      const SizedBox(height: GarageTokens.space2),
                      AdaptiveColumns(
                        children: [
                          for (final vehicle in archived)
                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: GarageTokens.space2,
                              ),
                              child: Opacity(
                                opacity: 0.6,
                                child: _VehicleCard(
                                  key: Key('archived-${vehicle.id}'),
                                  vehicle: vehicle,
                                  format: format,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _VehicleCard extends ConsumerWidget {
  const _VehicleCard({super.key, required this.vehicle, required this.format});

  final Vehicle vehicle;
  final UnitFormat format;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final odometer = ref.watch(currentOdometerProvider(vehicle.id)).value;
    return Card(
      child: ListTile(
        leading: _VehicleThumbnail(vehicleId: vehicle.id),
        title: Text(vehicle.nickname),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              [
                vehicle.make,
                vehicle.model,
                vehicle.year?.toString(),
                if (odometer != null)
                  // A non-breaking space: "142,300" on one line and "km"
                  // alone on the next read as a broken number.
                  format
                      .formatDistance(odometer.toDouble(), decimals: 0)
                      .replaceAll(' ', '\u00a0'),
              ].whereType<String>().join(' · '),
            ),
            OnLoanBadge(vehicleId: vehicle.id, format: format),
          ],
        ),
        trailing: vehicle.plate == null
            ? null
            : Text(
                vehicle.plate!,
                style: GarageTheme.numeric(
                  Theme.of(context).textTheme.labelMedium!,
                ),
              ),
        onTap: () => context.push('/vehicles/${vehicle.id}'),
      ),
    );
  }
}

/// The vehicle's photo at list size, or the car icon when it has none.
///
/// A link that has expired or a device that is offline falls back to the icon
/// rather than leaving a broken box in the row.
class _VehicleThumbnail extends ConsumerWidget {
  const _VehicleThumbnail({required this.vehicleId});

  final String vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = ref.watch(vehiclePhotoUrlProvider(vehicleId)).value;
    return VehiclePhoto(
      vehicleId: vehicleId,
      url: url,
      width: 48,
      height: 48,
      borderRadius: BorderRadius.circular(GarageTokens.radiusSm),
    );
  }
}
