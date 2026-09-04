import 'package:flutter/material.dart';
import 'package:garage/l10n/app_localizations.dart';

import '../../../domain/entities/vehicle.dart';

/// Asks which vehicle an action belongs to, returning its id or null if the
/// question was dismissed.
///
/// Only ask when there is a question: a household with one car should never be
/// shown a list with one row. Two callers share this — the dashboard's
/// quick-add and the launcher's fill-up route — because they were the same
/// list twice, and the same gesture has to be the same control on every
/// surface that offers it.
Future<String?> showVehiclePicker(
  BuildContext context,
  List<Vehicle> vehicles,
) {
  final l10n = AppLocalizations.of(context)!;
  return showModalBottomSheet<String>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(title: Text(l10n.quickAddPickVehicle), dense: true),
          for (final vehicle in vehicles)
            ListTile(
              title: Text(vehicle.nickname),
              // Two cars of one model, or cars named by their plate, need
              // more than a name to tell apart.
              subtitle: switch ([
                ?vehicle.plate,
                [?vehicle.make, ?vehicle.model].join(' '),
              ].where((s) => s.isNotEmpty).join(' · ')) {
                '' => null,
                final detail => Text(detail),
              },
              onTap: () => Navigator.of(context).pop(vehicle.id),
            ),
        ],
      ),
    ),
  );
}
