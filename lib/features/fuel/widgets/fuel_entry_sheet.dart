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
import '../../../domain/entities/fuel_entry.dart';
import '../../settings/providers/unit_providers.dart';
import '../providers/fuel_providers.dart';

/// The result of filling in whichever of volume/price/total the user left out.
class DerivedAmounts {
  const DerivedAmounts({this.volume, this.pricePerUnit, this.total});

  final double? volume;
  final double? pricePerUnit;
  final double? total;

  bool get isComplete =>
      volume != null && pricePerUnit != null && total != null;
}

double? _parse(String raw) {
  final normalized = raw.trim().replaceAll(',', '.');
  if (normalized.isEmpty) {
    return null;
  }
  return double.tryParse(normalized);
}

/// Given any two of volume, unit price, and total, works out the third — so a
/// user who has a pump receipt showing litres and total never has to divide
/// anything by hand.
DerivedAmounts deriveMissingValue({
  required String volume,
  required String price,
  required String total,
}) {
  final v = _parse(volume);
  final p = _parse(price);
  final t = _parse(total);

  final derived = FuelEntry.deriveThird(volumeL: v, pricePerL: p, total: t);
  if (derived == null) {
    return DerivedAmounts(volume: v, pricePerUnit: p, total: t);
  }
  return DerivedAmounts(
    volume: v ?? derived,
    pricePerUnit: p ?? derived,
    total: t ?? derived,
  );
}

/// Opens the fuel-entry sheet and returns true if an entry was saved. Pass
/// [existing] to edit that entry in place.
Future<bool?> showFuelEntrySheet(
  BuildContext context,
  String vehicleId, {
  FuelEntry? existing,
}) {
  return showAdaptiveEntrySheet<bool>(
    context,
    (_) => FuelEntrySheet(vehicleId: vehicleId, existing: existing),
  );
}

class FuelEntrySheet extends ConsumerStatefulWidget {
  const FuelEntrySheet({required this.vehicleId, this.existing, super.key});

  final String vehicleId;
  final FuelEntry? existing;

  @override
  ConsumerState<FuelEntrySheet> createState() => _FuelEntrySheetState();
}

class _FuelEntrySheetState extends ConsumerState<FuelEntrySheet> {
  final _odometer = TextEditingController();
  final _volume = TextEditingController();
  final _price = TextEditingController();
  final _total = TextEditingController();
  final _station = TextEditingController();
  final _notes = TextEditingController();

  DateTime _date = DateTime.now();
  bool _fullTank = true;
  bool _missedFill = false;
  bool _busy = false;
  bool _odometerMissing = false;
  String? _amountError;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing == null) {
      return;
    }
    final prefs = ref.read(unitPreferencesProvider);
    _date = existing.date.toLocal();
    _fullTank = existing.fullTank;
    _missedFill = existing.missedFill;
    _odometer.text = prefs
        .kmToDisplay(existing.odometerKm.toDouble())
        .round()
        .toString();
    _volume.text = prefs.litersToDisplay(existing.volumeL).toStringAsFixed(2);
    if (existing.total != null) {
      _total.text = existing.total!.toStringAsFixed(2);
    }
    _station.text = existing.station ?? '';
    _notes.text = existing.notes ?? '';
  }

  @override
  void dispose() {
    _odometer.dispose();
    _volume.dispose();
    _price.dispose();
    _total.dispose();
    _station.dispose();
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
    if (picked != null && mounted) {
      setState(() => _date = picked);
    }
  }

  Future<void> _submit(UnitPreferences prefs) async {
    setState(() {
      _amountError = null;
      _odometerMissing = false;
      _failure = null;
    });

    final odometerDisplay = _parse(_odometer.text);
    if (odometerDisplay == null || odometerDisplay < 0) {
      setState(() => _odometerMissing = true);
      return;
    }

    final amounts = deriveMissingValue(
      volume: _volume.text,
      price: _price.text,
      total: _total.text,
    );
    final l10n = AppLocalizations.of(context)!;
    if (!amounts.isComplete) {
      setState(() => _amountError = l10n.fuelNeedTwoValues);
      return;
    }

    setState(() => _busy = true);

    final odometerKm = prefs.displayToKm(odometerDisplay).round();
    final volumeL = prefs.displayToLiters(amounts.volume!);
    // price and total are per display-volume; convert price back to per-litre.
    final total = amounts.total;
    final pricePerL = volumeL > 0 ? (total! / volumeL) : null;

    final entry = FuelEntry(
      id: widget.existing?.id ?? '',
      vehicleId: widget.vehicleId,
      date: DateTime.utc(_date.year, _date.month, _date.day),
      odometerKm: odometerKm,
      volumeL: volumeL,
      pricePerL: pricePerL,
      total: total,
      fullTank: _fullTank,
      missedFill: _missedFill,
      station: _station.text.trim().isEmpty ? null : _station.text.trim(),
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      createdBy: widget.existing?.createdBy ?? '',
    );

    try {
      if (widget.existing == null) {
        await ref.read(fuelRepositoryProvider).add(entry);
      } else {
        await ref.read(fuelRepositoryProvider).update(entry);
      }
      ref.invalidate(rawFuelEntriesProvider(widget.vehicleId));
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
    final locale = Localizations.localeOf(context).languageCode;
    final format = UnitFormat(locale: locale, preferences: prefs);
    final previousKm = ref
        .watch(latestOdometerProvider(widget.vehicleId))
        .value;

    final odometerDisplay = _parse(_odometer.text);
    final belowPrevious =
        previousKm != null &&
        odometerDisplay != null &&
        prefs.displayToKm(odometerDisplay).round() < previousKm;

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
              Text(l10n.fuelAdd, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: GarageTokens.space4),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.fuelDate),
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
                        : belowPrevious
                        ? l10n.fuelOdometerTooLow(
                            format.formatDistance(previousKm.toDouble()),
                          )
                        : null,
                  ),
                  onChanged: (_) => setState(() => _odometerMissing = false),
                ),
              ),
              const SizedBox(height: GarageTokens.space3),
              LabeledField(
                label: l10n.fuelVolume,
                child: TextField(
                  controller: _volume,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: GarageTheme.numericField(context),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(height: GarageTokens.space3),
              LabeledField(
                label: l10n.fuelPricePerUnit,
                child: TextField(
                  controller: _price,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: GarageTheme.numericField(context),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(height: GarageTokens.space3),
              LabeledField(
                label: l10n.fuelTotal,
                child: TextField(
                  controller: _total,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: GarageTheme.numericField(context),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              if (_amountError != null) ...[
                const SizedBox(height: GarageTokens.space2),
                Text(
                  _amountError!,
                  style: TextStyle(color: context.tokens.danger),
                ),
              ],
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _fullTank,
                onChanged: (value) => setState(() => _fullTank = value),
                title: Text(l10n.fuelFullTank),
                subtitle: Text(l10n.fuelFullTankHint),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _missedFill,
                onChanged: (value) => setState(() => _missedFill = value),
                title: Text(l10n.fuelMissedFill),
                subtitle: Text(l10n.fuelMissedFillHint),
              ),
              LabeledField(
                label: l10n.fuelStation,
                child: TextField(controller: _station),
              ),
              const SizedBox(height: GarageTokens.space3),
              LabeledField(
                label: l10n.fuelNotes,
                child: TextField(controller: _notes),
              ),
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
