import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';

import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../domain/entities/vehicle_part.dart';
import '../../maintenance/service_type_labels.dart';
import '../providers/vehicle_part_providers.dart';
import '../widgets/vehicle_part_sheet.dart';

/// What this car takes, job by job.
///
/// The DIY owner's half of roadmap item 12. There is no free authoritative
/// source for oil specs and filter numbers by engine, and a wrong part number
/// costs more than none — so this is the part that needs no data at all: the
/// household looks it up once, and the app is what remembers. Each row is
/// keyed by the same service type the reminders use, which is what lets the
/// service sheet say "this car takes 5W-30" at the moment somebody logs the
/// oil change.
class VehiclePartsScreen extends ConsumerWidget {
  const VehiclePartsScreen({required this.vehicleId, super.key});

  final String vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final parts = ref.watch(vehiclePartsProvider(vehicleId));
    final any = (parts.value ?? const []).isNotEmpty;

    return GaragePageScaffold(
      title: l10n.partsTitle,
      // The empty state carries its own button, like the documents screen:
      // this list is empty for every household until the first lookup.
      floatingActionButton: any
          ? FloatingActionButton.extended(
              key: const Key('part-add'),
              onPressed: () => showVehiclePartSheet(context, vehicleId),
              icon: const Icon(Icons.add),
              label: Text(l10n.partsAdd),
            )
          : null,
      body: AsyncValueView<List<VehiclePart>>(
        value: parts,
        onRetry: () => ref.invalidate(vehiclePartsProvider(vehicleId)),
        empty: () => LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight.isFinite
                    ? constraints.maxHeight
                    : 0,
              ),
              child: Center(
                child: EmptyState(
                  message: l10n.partsEmpty,
                  action: FilledButton.icon(
                    key: const Key('part-add-first'),
                    onPressed: () => showVehiclePartSheet(context, vehicleId),
                    icon: const Icon(Icons.add),
                    label: Text(l10n.partsAdd),
                  ),
                ),
              ),
            ),
          ),
        ),
        data: (list) => ListView.builder(
          padding: const EdgeInsets.fromLTRB(
            GarageTokens.space4,
            GarageTokens.space4,
            GarageTokens.space4,
            GarageTokens.space8,
          ),
          itemCount: list.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: GarageTokens.space3),
                child: Text(
                  l10n.partsHint,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: context.tokens.muted),
                ),
              );
            }
            return _PartCard(part: list[index - 1]);
          },
        ),
      ),
    );
  }
}

class _PartCard extends ConsumerWidget {
  const _PartCard({required this.part});

  final VehiclePart part;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = context.tokens;

    return Padding(
      padding: const EdgeInsets.only(bottom: GarageTokens.space3),
      child: Card(
        child: ListTile(
          key: Key('part-${part.id}'),
          title: Text(serviceTypeLabel(l10n, part.serviceTypeKey)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // The spec is the point of the row; it gets the weight, the job
              // it belongs to is the caption.
              Text(
                part.spec,
                style: GarageTheme.numeric(
                  Theme.of(context).textTheme.bodyLarge!,
                ).copyWith(color: tokens.fg),
              ),
              if (part.notes case final notes? when notes.isNotEmpty)
                Text(notes, style: TextStyle(color: tokens.muted)),
            ],
          ),
          isThreeLine: part.notes?.isNotEmpty ?? false,
          trailing: PopupMenuButton<String>(
            key: Key('part-menu-${part.id}'),
            onSelected: (action) => _act(context, ref, action),
            itemBuilder: (context) => [
              PopupMenuItem(value: 'edit', child: Text(l10n.partsEdit)),
              PopupMenuItem(value: 'delete', child: Text(l10n.partsDelete)),
            ],
          ),
          onTap: () =>
              showVehiclePartSheet(context, part.vehicleId, existing: part),
        ),
      ),
    );
  }

  Future<void> _act(BuildContext context, WidgetRef ref, String action) async {
    final l10n = AppLocalizations.of(context)!;
    if (action == 'edit') {
      await showVehiclePartSheet(context, part.vehicleId, existing: part);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l10n.partsDeleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.partsDelete),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await ref.read(vehiclePartControllerProvider.notifier).delete(part);
    }
  }
}
