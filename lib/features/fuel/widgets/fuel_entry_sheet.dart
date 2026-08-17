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
import '../../../domain/entities/fuel_entry.dart';
import '../../../domain/entities/attachment.dart';
import '../../attachments/widgets/entry_attachments.dart';
import '../../../domain/fuel/odometer_bounds.dart';
import '../../../domain/fuel/station_history.dart';
import '../../settings/providers/unit_providers.dart';
import '../../vehicles/fuel_type_labels.dart';
import '../../vehicles/providers/vehicle_providers.dart';
import '../../../domain/stations/station_at_the_pump.dart';
import '../providers/fuel_providers.dart';
import '../providers/pump_providers.dart';
import '../providers/station_history_providers.dart';

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

  /// Which fuel went in, on a car that takes two. Null until chosen, and null
  /// forever on a car that takes one — where naming it would be a field with
  /// one possible answer.
  String? _fuelTypeKey;

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
      _prefillFromLastEntry();
      _prefillFromPump();
      return;
    }
    final prefs = ref.read(unitPreferencesProvider);
    _date = existing.date.toLocal();
    _fuelTypeKey = existing.fuelTypeKey;
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
    final pricePerL =
        existing.pricePerL ??
        (existing.total != null && existing.volumeL > 0
            ? existing.total! / existing.volumeL
            : null);
    if (pricePerL != null) {
      // Stored per litre; the field is per display volume unit.
      _price.text = UnitFormat.editableNumber(
        pricePerL * prefs.displayToLiters(1),
      );
    }
    _notes.text = existing.notes ?? '';
    _station.text = existing.station ?? '';
  }

  /// New fill-ups start from the previous one: same station, same unit
  /// price. Both stay fully editable — they are the values most likely to
  /// repeat, not a lock-in.
  Future<void> _prefillFromLastEntry() async {
    final last = await ref.read(
      latestFuelEntryProvider(widget.vehicleId).future,
    );
    if (!mounted || last == null) {
      return;
    }
    final prefs = ref.read(unitPreferencesProvider);
    setState(() {
      if (_station.text.isEmpty && last.station != null) {
        _station.text = last.station!;
        _guessedStation = last.station;
      }
      if (_price.text.isEmpty && last.pricePerL != null) {
        _price.text = UnitFormat.editableNumber(
          last.pricePerL! * prefs.displayToLiters(1),
        );
        _guessedPrice = _price.text;
      }
    });
  }

  /// What the last-entry prefill put in, so the station lookup can tell its own
  /// guess from something the driver typed and never overwrite the latter.
  String? _guessedStation;
  String? _guessedPrice;

  /// Today's posted price at the station being stood at, which beats last
  /// month's price at whichever station that was.
  ///
  /// Only for a new entry, only when location was already granted, and only
  /// over a value this sheet guessed: a slow stations fetch must never land on
  /// top of something typed while it was in flight.
  Future<void> _prefillFromPump() async {
    final match = await ref.read(
      stationAtThePumpProvider(widget.vehicleId).future,
    );
    if (!mounted || match == null) {
      return;
    }
    final prefs = ref.read(unitPreferencesProvider);
    final price = UnitFormat.editableNumber(
      match.pricePerUnit * prefs.displayToLiters(1),
    );
    setState(() {
      if (_station.text.isEmpty || _station.text == _guessedStation) {
        _station.text = match.station.name;
        _guessedStation = match.station.name;
      }
      if (_price.text.isEmpty || _price.text == _guessedPrice) {
        _price.text = price;
        _guessedPrice = price;
      }
      _atThePump = match;
    });
  }

  PumpMatch? _atThePump;

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
      fuelTypeKey: _fuelTypeKey,
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

  /// Deleting goes through the same busy/failure path as saving: a delete that
  /// the server rejects has to say so in the sheet, not throw out of the
  /// button's callback where nothing is listening.
  Future<void> _delete() async {
    if (!await confirmDelete(context) || !mounted) {
      return;
    }
    setState(() {
      _busy = true;
      _failure = null;
    });

    try {
      await ref.read(fuelRepositoryProvider).delete(widget.existing!.id);
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
    final vehicle = ref.watch(vehicleProvider(widget.vehicleId)).value;

    // The guard is a window, not a floor: an entry being edited, or one
    // backdated into the middle of the log, is judged against the fills that
    // bracket its own date rather than against the newest reading on record.
    final log =
        ref.watch(rawFuelEntriesProvider(widget.vehicleId)).value ??
        const <FuelEntry>[];
    final bounds = OdometerBounds.forDate(
      log,
      date: _date,
      excludingId: widget.existing?.id,
    );
    final odometerDisplay = _parse(_odometer.text);
    final odometerKm = odometerDisplay == null
        ? null
        : prefs.displayToKm(odometerDisplay).round();
    final tooLow = odometerKm != null && bounds.isTooLow(odometerKm);
    final tooHigh = odometerKm != null && bounds.isTooHigh(odometerKm);
    final previousReading = bounds.previousKm == null
        ? null
        : format.formatDistance(bounds.previousKm!.toDouble(), decimals: 0);

    final energy = ref.watch(vehicleEnergyProvider(widget.vehicleId));

    // Checked against the derived volume, so a fill entered as price + total
    // is caught the same as one entered in litres. A battery has no tank to
    // overfill, so the check simply does not apply to an electric vehicle.
    final tankCapacityL = energy.isElectric
        ? null
        : ref.watch(vehicleProvider(widget.vehicleId)).value?.tankCapacityL;
    final enteredVolume = deriveMissingValue(
      volume: _volume.text,
      price: _price.text,
      total: _total.text,
    ).volume;
    final overTank =
        tankCapacityL != null &&
        enteredVolume != null &&
        prefs.displayToLiters(enteredVolume) > tankCapacityL;

    final stations = ref.watch(knownStationsProvider).value ?? const <String>[];

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
              // Which fuel went in, on a car that takes two. Placed above the
              // odometer because it is the first thing that differs between
              // two otherwise identical fill-ups, and because it decides which
              // chain the entry lands in.
              if (vehicle?.isBiFuel ?? false) ...[
                LabeledField(
                  label: l10n.fuelWhichFuel,
                  child: SegmentedButton<String>(
                    segments: [
                      for (final key in [
                        vehicle!.fuelTypeKey,
                        vehicle.secondaryFuelTypeKey!,
                      ])
                        ButtonSegment(
                          value: key,
                          label: Text(fuelTypeLabel(l10n, key) ?? key),
                        ),
                    ],
                    selected: {_fuelTypeKey ?? vehicle.fuelTypeKey},
                    onSelectionChanged: (values) =>
                        setState(() => _fuelTypeKey = values.first),
                  ),
                ),
                const SizedBox(height: GarageTokens.space3),
              ],
              LabeledField(
                label: l10n.fuelOdometer,
                child: TextField(
                  controller: _odometer,
                  keyboardType: TextInputType.number,
                  style: GarageTheme.numericField(context),
                  decoration: InputDecoration(
                    // The last reading is the number the driver is comparing
                    // the pump display against, so it belongs on screen
                    // rather than one screen back in the log.
                    helperText: previousReading == null
                        ? null
                        : l10n.fuelOdometerLast(previousReading),
                    errorText: _odometerMissing
                        ? l10n.fuelOdometerRequired
                        : tooLow
                        ? l10n.fuelOdometerTooLow(previousReading!)
                        : tooHigh
                        ? l10n.fuelOdometerTooHigh(
                            format.formatDistance(
                              bounds.nextKm!.toDouble(),
                              decimals: 0,
                            ),
                          )
                        : null,
                  ),
                  onChanged: (_) => setState(() => _odometerMissing = false),
                ),
              ),
              const SizedBox(height: GarageTokens.space3),
              LabeledField(
                label: energy.isElectric ? l10n.fuelEnergy : l10n.fuelVolume,
                child: TextField(
                  controller: _volume,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: GarageTheme.numericField(context),
                  decoration: InputDecoration(
                    errorText: overTank
                        ? l10n.fuelVolumeOverTank(
                            format.formatVolume(tankCapacityL, decimals: 0),
                          )
                        : null,
                  ),
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
                child: _StationField(controller: _station, options: stations),
              ),
              // Said out loud rather than left as a value that appeared by
              // itself: the posted price is the headline one, and a discount
              // card or a different grade means they paid something else.
              if (_atThePump case final match?) ...[
                const SizedBox(height: GarageTokens.space1),
                Text(
                  l10n.fuelAtThePump(
                    match.station.name,
                    format.formatDistance(match.distanceKm, decimals: 1),
                  ),
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: context.tokens.muted),
                ),
              ],
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
              if (widget.existing != null) ...[
                const SizedBox(height: GarageTokens.space4),
                EntryAttachments(
                  vehicleId: widget.vehicleId,
                  kind: AttachmentEntryKind.fuel,
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

/// The station name: free text, with every station the household has fuelled
/// at filtered as you type, and the full list one tap away — so a regular is
/// chosen rather than re-typed. Typing a name that is not on the list is still
/// how a new station gets added.
class _StationField extends StatelessWidget {
  const _StationField({required this.controller, required this.options});

  final TextEditingController controller;
  final List<String> options;

  @override
  Widget build(BuildContext context) {
    // Nothing logged yet: a menu with no entries is worse than no menu, and
    // the first station a household enters is by definition free text.
    if (options.isEmpty) {
      return TextField(
        controller: controller,
        textCapitalization: TextCapitalization.words,
      );
    }

    return DropdownMenu<String>(
      controller: controller,
      expandedInsets: EdgeInsets.zero,
      enableFilter: true,
      requestFocusOnTap: true,
      menuHeight: 260,
      textStyle: Theme.of(context).textTheme.bodyLarge,
      filterCallback: (entries, filter) {
        final matches = StationHistory.matching(options, filter);
        return [
          for (final entry in entries)
            if (matches.contains(entry.value)) entry,
        ];
      },
      dropdownMenuEntries: [
        for (final station in options)
          DropdownMenuEntry(value: station, label: station),
      ],
    );
  }
}
