import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';

import '../../../core/theme/garage_theme.dart';
import '../providers/vehicle_providers.dart';
import 'vehicle_picker.dart';

/// The vehicle an entry sheet will log against, as its first row.
///
/// The sheets never said. With one car that was implied; with two, the
/// dashboard's + button gave no clue which one was about to get the fill-up,
/// and the only recovery was to find the entry in the timeline and edit it.
/// Tappable to switch while there is a choice and the entry is new; a saved
/// entry stays with its car.
class SheetVehicleRow extends ConsumerWidget {
  const SheetVehicleRow({
    required this.vehicleId,
    required this.onSwitch,
    this.lockedNote,
    super.key,
  });

  final String vehicleId;

  /// Null when the row must not switch: an existing entry.
  final ValueChanged<String>? onSwitch;

  /// Why switching is off, when it is off for a reason the household can undo.
  /// A row that simply stops responding reads as broken.
  final String? lockedNote;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final vehicle = ref.watch(vehicleProvider(vehicleId)).value;
    final choices = ref.watch(vehiclesProvider).value ?? const [];
    final canSwitch = onSwitch != null && choices.length > 1;
    if (vehicle == null) {
      return const SizedBox.shrink();
    }
    final note = canSwitch ? null : lockedNote;
    return ListTile(
      key: const Key('sheet-vehicle'),
      isThreeLine: note != null,
      contentPadding: EdgeInsets.zero,
      leading: Icon(Icons.directions_car_outlined, color: context.tokens.muted),
      title: Text(vehicle.nickname),
      subtitle: switch ((vehicle.plate, canSwitch, note)) {
        (final plate?, _, final note?) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              plate,
              style: GarageTheme.numeric(
                Theme.of(context).textTheme.bodySmall!,
              ),
            ),
            Text(note, style: TextStyle(color: context.tokens.muted)),
          ],
        ),
        (final plate?, _, null) => Text(
          plate,
          style: GarageTheme.numeric(Theme.of(context).textTheme.bodySmall!),
        ),
        (null, _, final note?) => Text(
          note,
          style: TextStyle(color: context.tokens.muted),
        ),
        (null, true, null) => Text(l10n.sheetVehicleTapToChange),
        (null, false, null) => null,
      },
      trailing: canSwitch ? const Icon(Icons.unfold_more) : null,
      onTap: canSwitch
          ? () async {
              final picked = await showVehiclePicker(context, choices);
              if (picked != null && picked != vehicleId) {
                onSwitch!(picked);
              }
            }
          : null,
    );
  }
}
