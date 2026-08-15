import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/widgets/adaptive.dart';
import '../../../core/format/unit_format.dart';
import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../core/widgets/confirm_delete.dart';
import '../../../core/widgets/failure_message.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../domain/entities/service_entry.dart';
import '../../../domain/maintenance/tracking_level.dart';
import '../../../domain/entities/attachment.dart';
import '../../attachments/widgets/entry_attachments.dart';
import '../../settings/providers/unit_providers.dart';
import '../data/maintenance_repository.dart';
import '../providers/maintenance_providers.dart';
import '../service_type_labels.dart';

Future<bool?> showServiceEntrySheet(
  BuildContext context,
  String vehicleId, {
  ServiceEntry? existing,
}) {
  return showAdaptiveEntrySheet<bool>(
    context,
    (_) => ServiceEntrySheet(vehicleId: vehicleId, existing: existing),
  );
}

class ServiceEntrySheet extends ConsumerStatefulWidget {
  const ServiceEntrySheet({required this.vehicleId, this.existing, super.key});

  final String vehicleId;
  final ServiceEntry? existing;

  @override
  ConsumerState<ServiceEntrySheet> createState() => _ServiceEntrySheetState();
}

class _ServiceEntrySheetState extends ConsumerState<ServiceEntrySheet> {
  final _odometer = TextEditingController();
  final _cost = TextEditingController();
  final _shop = TextEditingController();
  final _notes = TextEditingController();
  final _partsCost = TextEditingController();
  final _laborCost = TextEditingController();
  final _partsDetail = TextEditingController();
  final _faultCodes = TextEditingController();

  /// One controller per reading the household can take, created lazily so a
  /// basic household allocates nothing it will never show.
  final _readings = <String, TextEditingController>{};
  bool _diy = false;
  DateTime? _warrantyUntil;

  DateTime _date = DateTime.now();
  final Set<String> _selectedKeys = {};
  bool _busy = false;
  bool _odometerMissing = false;
  String? _selectionError;
  AppFailure? _failure;

  @override
  void dispose() {
    _odometer.dispose();
    _cost.dispose();
    _shop.dispose();
    _notes.dispose();
    _partsCost.dispose();
    _laborCost.dispose();
    _partsDetail.dispose();
    _faultCodes.dispose();
    for (final controller in _readings.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing == null) {
      return;
    }
    final prefs = ref.read(unitPreferencesProvider);
    _date = existing.date.toLocal();
    _selectedKeys.addAll(existing.serviceTypeKeys);
    _odometer.text = prefs
        .kmToDisplay(existing.odometerKm.toDouble())
        .round()
        .toString();
    if (existing.cost != null) {
      _cost.text = existing.cost!.toStringAsFixed(2);
    }
    _shop.text = existing.shop ?? '';
    _notes.text = existing.notes ?? '';
    _diy = existing.diy;
    _partsDetail.text = existing.partsDetail ?? '';
    _faultCodes.text = existing.faultCodes ?? '';
    _warrantyUntil = existing.warrantyUntil?.toLocal();
    if (existing.partsCost != null) {
      _partsCost.text = existing.partsCost!.toStringAsFixed(2);
    }
    if (existing.laborCost != null) {
      _laborCost.text = existing.laborCost!.toStringAsFixed(2);
    }
    for (final reading in existing.measurements.entries) {
      _reading(reading.key).text = UnitFormat.editableNumber(
        reading.value,
        decimals: 2,
      );
    }
  }

  TextEditingController _reading(String key) =>
      _readings[key] ??= TextEditingController();

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() => _date = picked);
    }
  }

  double? _parse(String raw) {
    final normalized = raw.trim().replaceAll(',', '.');
    return normalized.isEmpty ? null : double.tryParse(normalized);
  }

  Future<void> _pickWarrantyDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _warrantyUntil ?? _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() => _warrantyUntil = picked);
    }
  }

  Future<void> _submit(UnitPreferences prefs) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _odometerMissing = false);
    if (_selectedKeys.isEmpty) {
      setState(() => _selectionError = l10n.maintenanceServiceItems);
      return;
    }
    final odometerDisplay = _parse(_odometer.text);
    if (odometerDisplay == null || odometerDisplay < 0) {
      setState(() => _odometerMissing = true);
      return;
    }

    setState(() {
      _busy = true;
      _selectionError = null;
      _failure = null;
    });

    final entry = ServiceEntry(
      id: widget.existing?.id ?? '',
      vehicleId: widget.vehicleId,
      date: DateTime.utc(_date.year, _date.month, _date.day),
      odometerKm: prefs.displayToKm(odometerDisplay).round(),
      serviceTypeKeys: _selectedKeys.toList(growable: false),
      cost: _parse(_cost.text),
      shop: _shop.text.trim().isEmpty ? null : _shop.text.trim(),
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      createdBy: widget.existing?.createdBy ?? '',
      diy: _diy,
      partsCost: _parse(_partsCost.text),
      laborCost: _parse(_laborCost.text),
      partsDetail: _partsDetail.text.trim().isEmpty
          ? null
          : _partsDetail.text.trim(),
      warrantyUntil: _warrantyUntil == null
          ? null
          : DateTime.utc(
              _warrantyUntil!.year,
              _warrantyUntil!.month,
              _warrantyUntil!.day,
            ),
      faultCodes: _faultCodes.text.trim().isEmpty
          ? null
          : _faultCodes.text.trim(),
      measurements: {
        // A reading left blank parses to null and is simply not recorded.
        for (final entry in _readings.entries)
          if (_parse(entry.value.text) != null)
            entry.key: _parse(entry.value.text)!,
      },
    );

    try {
      if (widget.existing == null) {
        await ref.read(maintenanceRepositoryProvider).addServiceEntry(entry);
        await ref
            .read(maintenanceRepositoryProvider)
            .completeOneTimeRules(widget.vehicleId, entry.serviceTypeKeys);
      } else {
        await ref.read(maintenanceRepositoryProvider).updateServiceEntry(entry);
      }
      ref.invalidate(serviceEntriesProvider(widget.vehicleId));
      ref.invalidate(vehicleProjectionsProvider(widget.vehicleId));
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _failure = AppFailure.from(error);
        _busy = false;
      });
    }
  }

  /// Deleting goes through the same busy/failure path as saving: a delete the
  /// server rejects has to say so in the sheet, not throw out of the button's
  /// callback where nothing is listening.
  Future<void> _delete() async {
    if (!await confirmDelete(context) || !mounted) {
      return;
    }
    setState(() {
      _busy = true;
      _failure = null;
    });

    try {
      await ref
          .read(maintenanceRepositoryProvider)
          .deleteServiceEntry(widget.existing!.id);
      ref
        ..invalidate(serviceEntriesProvider(widget.vehicleId))
        ..invalidate(vehicleProjectionsProvider(widget.vehicleId));
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _failure = AppFailure.from(error);
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final prefs = ref.watch(unitPreferencesProvider);
    final format = UnitFormat(
      locale: Localizations.localeOf(context).languageCode,
      preferences: prefs,
    );
    final level = ref.watch(trackingLevelProvider);
    final types =
        ref.watch(availableServiceTypesProvider).value ?? const <ServiceType>[];
    final sortedTypes = [...types]
      ..sort(
        (a, b) => serviceTypeLabel(
          l10n,
          a.key,
        ).compareTo(serviceTypeLabel(l10n, b.key)),
      );

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
              Text(
                l10n.maintenanceLogService,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: GarageTokens.space4),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.maintenanceServiceDate),
                subtitle: Text(format.formatShortDate(_date)),
                trailing: const Icon(Icons.calendar_today),
                onTap: _pickDate,
              ),
              LabeledField(
                label: l10n.fuelOdometer,
                child: TextField(
                  controller: _odometer,
                  keyboardType: TextInputType.number,
                  style: GarageTheme.numericField(context),
                  decoration: InputDecoration(
                    errorText: _odometerMissing
                        ? l10n.fuelOdometerRequired
                        : null,
                  ),
                  onChanged: (_) => setState(() => _odometerMissing = false),
                ),
              ),
              const SizedBox(height: GarageTokens.space3),
              LabeledField(
                label: l10n.maintenanceServiceCost,
                child: TextField(
                  controller: _cost,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: GarageTheme.numericField(context),
                ),
              ),
              const SizedBox(height: GarageTokens.space3),
              LabeledField(
                label: l10n.maintenanceServiceShop,
                child: TextField(controller: _shop),
              ),
              const SizedBox(height: GarageTokens.space3),
              LabeledField(
                label: l10n.fuelNotes,
                child: TextField(controller: _notes),
              ),
              if (level.showsPartsAndLabour) ...[
                const SizedBox(height: GarageTokens.space3),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _diy,
                  onChanged: (value) => setState(() => _diy = value),
                  title: Text(l10n.serviceDiy),
                ),
                Row(
                  children: [
                    Expanded(
                      child: LabeledField(
                        label: l10n.servicePartsCost,
                        child: TextField(
                          controller: _partsCost,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          style: GarageTheme.numericField(context),
                        ),
                      ),
                    ),
                    const SizedBox(width: GarageTokens.space3),
                    Expanded(
                      child: LabeledField(
                        label: l10n.serviceLaborCost,
                        child: TextField(
                          controller: _laborCost,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          style: GarageTheme.numericField(context),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: GarageTokens.space3),
                LabeledField(
                  label: l10n.servicePartsDetail,
                  child: TextField(controller: _partsDetail),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.serviceWarrantyUntil),
                  subtitle: Text(
                    _warrantyUntil == null
                        ? UnitFormat.emptyValue
                        : format.formatShortDate(_warrantyUntil!),
                  ),
                  trailing: const Icon(Icons.shield_outlined),
                  onTap: _pickWarrantyDate,
                ),
              ],
              if (level.showsMeasurements) ...[
                const SizedBox(height: GarageTokens.space3),
                LabeledField(
                  label: l10n.serviceFaultCodes,
                  child: TextField(
                    controller: _faultCodes,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      helperText: l10n.serviceFaultCodesHint,
                    ),
                  ),
                ),
                const SizedBox(height: GarageTokens.space4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l10n.serviceMeasurements,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                for (final measurement in Measurements.all)
                  LabeledField(
                    label:
                        '${_measurementLabel(l10n, measurement.key)} '
                        '(${measurement.unit})',
                    child: TextField(
                      controller: _reading(measurement.key),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: GarageTheme.numericField(context),
                    ),
                  ),
              ],
              const SizedBox(height: GarageTokens.space4),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  l10n.maintenanceServiceItems,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Wrap(
                spacing: GarageTokens.space2,
                children: [
                  for (final type in sortedTypes)
                    FilterChip(
                      label: Text(serviceTypeLabel(l10n, type.key)),
                      selected: _selectedKeys.contains(type.key),
                      onSelected: (selected) => setState(() {
                        if (selected) {
                          _selectedKeys.add(type.key);
                        } else {
                          _selectedKeys.remove(type.key);
                        }
                      }),
                    ),
                ],
              ),
              if (_selectionError != null) ...[
                const SizedBox(height: GarageTokens.space2),
                Text(
                  _selectionError!,
                  style: TextStyle(color: context.tokens.danger),
                ),
              ],
              if (_failure != null) ...[
                const SizedBox(height: GarageTokens.space3),
                Text(
                  failureMessage(l10n, _failure!),
                  style: TextStyle(color: context.tokens.danger),
                ),
              ],
              if (widget.existing != null) ...[
                const SizedBox(height: GarageTokens.space4),
                EntryAttachments(
                  vehicleId: widget.vehicleId,
                  kind: AttachmentEntryKind.service,
                  entryId: widget.existing!.id,
                ),
              ],
              const SizedBox(height: GarageTokens.space5),
              FilledButton(
                onPressed: _busy ? null : () => _submit(prefs),
                child: Text(l10n.commonSave),
              ),
              if (widget.existing != null) ...[
                const SizedBox(height: GarageTokens.space3),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _delete,
                  icon: Icon(
                    Icons.delete_outline,
                    color: context.tokens.danger,
                  ),
                  label: Text(
                    l10n.commonDelete,
                    style: TextStyle(color: context.tokens.danger),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The label for a reading. Keys are language-neutral; this is where they
/// become words.
String _measurementLabel(AppLocalizations l10n, String key) {
  return switch (key) {
    'brake_pad_front_mm' => l10n.measurementBrakePadFront,
    'brake_pad_rear_mm' => l10n.measurementBrakePadRear,
    'brake_disc_front_mm' => l10n.measurementBrakeDiscFront,
    'tread_front_left_mm' => l10n.measurementTreadFrontLeft,
    'tread_front_right_mm' => l10n.measurementTreadFrontRight,
    'tread_rear_left_mm' => l10n.measurementTreadRearLeft,
    'tread_rear_right_mm' => l10n.measurementTreadRearRight,
    'battery_volts' => l10n.measurementBatteryVolts,
    'battery_cca' => l10n.measurementBatteryCca,
    _ => key,
  };
}
