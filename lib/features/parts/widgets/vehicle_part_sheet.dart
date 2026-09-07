import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';

import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../core/widgets/adaptive.dart';
import '../../../core/widgets/discard_guard.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../domain/entities/vehicle_part.dart';
import '../../maintenance/widgets/service_type_field.dart';
import '../providers/vehicle_part_providers.dart';

/// Recording what a car takes for one job.
Future<void> showVehiclePartSheet(
  BuildContext context,
  String vehicleId, {
  VehiclePart? existing,
}) {
  return showAdaptiveEntrySheet<void>(context, (_) {
    return _VehiclePartForm(vehicleId: vehicleId, existing: existing);
  });
}

class _VehiclePartForm extends ConsumerStatefulWidget {
  const _VehiclePartForm({required this.vehicleId, this.existing});

  final String vehicleId;
  final VehiclePart? existing;

  @override
  ConsumerState<_VehiclePartForm> createState() => _VehiclePartFormState();
}

class _VehiclePartFormState extends ConsumerState<_VehiclePartForm> {
  late final _spec = TextEditingController(text: widget.existing?.spec ?? '');
  late final _notes = TextEditingController(text: widget.existing?.notes ?? '');
  late String? _job = widget.existing?.serviceTypeKey;
  bool _specMissing = false;
  bool _busy = false;

  @override
  void dispose() {
    _spec.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(GarageTokens.space5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              DiscardGuard(controllers: [_spec, _notes]),
              Text(
                l10n.partsTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: GarageTokens.space2),
              Text(
                l10n.partsHint,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: context.tokens.muted),
              ),
              const SizedBox(height: GarageTokens.space4),
              LabeledField(
                label: l10n.partsJob,
                // The same picker the reminders use, deliberately: a spec and
                // the reminder that will need it have to land on one key or
                // the service sheet cannot bring them together.
                child: ServiceTypeField(
                  fieldKey: const Key('part-job'),
                  selected: _job,
                  vehicleId: widget.vehicleId,
                  existingKey: widget.existing?.serviceTypeKey,
                  onChanged: (key) => setState(() => _job = key),
                ),
              ),
              const SizedBox(height: GarageTokens.space3),
              LabeledField(
                label: l10n.partsSpec,
                child: TextField(
                  key: const Key('part-spec'),
                  controller: _spec,
                  decoration: InputDecoration(
                    hintText: l10n.partsSpecHint,
                    errorText: _specMissing ? l10n.partsSpecRequired : null,
                  ),
                  onChanged: (_) => setState(() => _specMissing = false),
                ),
              ),
              const SizedBox(height: GarageTokens.space3),
              LabeledField(
                label: l10n.partsNotes,
                child: TextField(controller: _notes, maxLines: 2),
              ),
              const SizedBox(height: GarageTokens.space5),
              FilledButton(
                key: const Key('part-save'),
                onPressed: _busy ? null : _submit,
                child: Text(l10n.commonSave),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final job = _job;
    if (job == null) {
      return;
    }
    if (_spec.text.trim().isEmpty) {
      setState(() => _specMissing = true);
      return;
    }
    setState(() => _busy = true);

    final saved = await ref
        .read(vehiclePartControllerProvider.notifier)
        .save(
          VehiclePart(
            // Kept on an edit so a correction replaces the row rather than
            // colliding with it on the one-per-job constraint.
            id: widget.existing?.id ?? '',
            vehicleId: widget.vehicleId,
            serviceTypeKey: job,
            spec: _spec.text.trim(),
            notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
            createdBy: widget.existing?.createdBy ?? '',
          ),
        );
    if (!mounted) {
      return;
    }
    if (saved) {
      Navigator.of(context).pop();
    } else {
      setState(() => _busy = false);
    }
  }
}
