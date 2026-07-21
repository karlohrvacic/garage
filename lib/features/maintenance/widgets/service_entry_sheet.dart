import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/format/unit_format.dart';
import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../core/widgets/failure_message.dart';
import '../../../domain/entities/service_entry.dart';
import '../../settings/providers/unit_providers.dart';
import '../data/maintenance_repository.dart';
import '../providers/maintenance_providers.dart';
import '../service_type_labels.dart';

Future<bool?> showServiceEntrySheet(BuildContext context, String vehicleId) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => ServiceEntrySheet(vehicleId: vehicleId),
  );
}

class ServiceEntrySheet extends ConsumerStatefulWidget {
  const ServiceEntrySheet({required this.vehicleId, super.key});

  final String vehicleId;

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

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  double? _parse(String raw) {
    final normalized = raw.trim().replaceAll(',', '.');
    return normalized.isEmpty ? null : double.tryParse(normalized);
  }

  Future<void> _submit(UnitPreferences prefs) async {
    final l10n = AppLocalizations.of(context)!;
    if (_selectedKeys.isEmpty) {
      setState(() => _selectionError = l10n.maintenanceServiceItems);
      return;
    }
    final odometerDisplay = _parse(_odometer.text);
    if (odometerDisplay == null || odometerDisplay < 0) {
      return;
    }

    setState(() {
      _busy = true;
      _selectionError = null;
      _failure = null;
    });

    try {
      await ref.read(maintenanceRepositoryProvider).addServiceEntry(
            ServiceEntry(
              id: '',
              vehicleId: widget.vehicleId,
              date: DateTime.utc(_date.year, _date.month, _date.day),
              odometerKm: prefs.displayToKm(odometerDisplay).round(),
              serviceTypeKeys: _selectedKeys.toList(growable: false),
              cost: _parse(_cost.text),
              shop: _shop.text.trim().isEmpty ? null : _shop.text.trim(),
              notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
              createdBy: '',
            ),
          );
      ref.invalidate(serviceEntriesProvider(widget.vehicleId));
      ref.invalidate(vehicleProjectionsProvider(widget.vehicleId));
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
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
    final types = ref.watch(serviceTypesProvider).value ?? const <ServiceType>[];
    final sortedTypes = [...types]
      ..sort(
        (a, b) => serviceTypeLabel(l10n, a.key)
            .compareTo(serviceTypeLabel(l10n, b.key)),
      );

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
              TextField(
                controller: _odometer,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: l10n.fuelOdometer),
              ),
              const SizedBox(height: GarageTokens.space3),
              TextField(
                controller: _cost,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(labelText: l10n.maintenanceServiceCost),
              ),
              const SizedBox(height: GarageTokens.space3),
              TextField(
                controller: _shop,
                decoration: InputDecoration(labelText: l10n.maintenanceServiceShop),
              ),
              const SizedBox(height: GarageTokens.space3),
              TextField(
                controller: _notes,
                decoration: InputDecoration(labelText: l10n.fuelNotes),
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
