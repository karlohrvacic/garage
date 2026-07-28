import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/widgets/adaptive.dart';
import '../../../core/format/unit_format.dart';
import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../core/widgets/failure_message.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../domain/entities/service_entry.dart';
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
  }

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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final prefs = ref.watch(unitPreferencesProvider);
    final format = UnitFormat(
      locale: Localizations.localeOf(context).languageCode,
      preferences: prefs,
    );
    final types =
        ref.watch(serviceTypesProvider).value ?? const <ServiceType>[];
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
              const SizedBox(height: GarageTokens.space5),
              FilledButton(
                onPressed: _busy ? null : () => _submit(prefs),
                child: Text(l10n.commonSave),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
