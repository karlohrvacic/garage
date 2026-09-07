import '../../../core/widgets/unit_suffix.dart';
import 'dart:async';
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
import '../../../core/widgets/busy_label.dart';
import '../../../domain/entities/fuel_entry.dart';
import '../../../domain/format/amount_expression.dart';
import '../../../domain/entities/attachment.dart';
import '../../attachments/data/attachment_repository.dart';
import '../../attachments/providers/attachment_providers.dart';
import '../../attachments/widgets/entry_attachments.dart';
import '../../../domain/fuel/implied_consumption.dart';
import '../../../domain/fuel/odometer_bounds.dart';
import '../../odometer/providers/odometer_providers.dart';
import '../../../domain/fuel/odometer_history.dart';
import '../../../domain/fuel/station_history.dart';
import '../../settings/providers/unit_providers.dart';
import '../../vehicles/fuel_type_labels.dart';
import '../../vehicles/providers/vehicle_providers.dart';
import '../../vehicles/widgets/sheet_vehicle_row.dart';
import '../../../domain/stations/cheapest_nearby.dart';
import '../../../domain/stations/fuel_price_context.dart';
import '../../../domain/stations/posted_price.dart';
import '../../../domain/stations/station_at_the_pump.dart';
import '../providers/fuel_providers.dart';
import '../providers/pump_providers.dart';
import '../providers/station_history_providers.dart';
import '../../stations/providers/station_providers.dart';
import '../../../core/widgets/save_progress.dart';
import '../../../core/ids.dart';
import '../../../core/widgets/date_pickers.dart';
import '../../../core/widgets/discard_guard.dart';
import '../../../core/widgets/amount_calculator_dock.dart';
import '../../../core/sync/sync_providers.dart';

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
  // The two money fields take a sum as well as a number; a volume off a pump
  // receipt is only ever one reading.
  final p = evaluateAmount(price);
  final t = evaluateAmount(total);

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
  /// Chosen once, so a save retried after a timeout is the same entry.
  late final _newId = newEntryId();

  /// Whether the entry reached the repository. Until it does, anything
  /// attached hangs off an id nothing else knows about, and closing the sheet
  /// has to take it back down.
  bool _saved = false;

  /// Whether a write was ever started. A save that times out is not a save
  /// that failed — the request cannot be cancelled and may well have landed —
  /// so from here the cleanup keeps its hands off. An orphaned file costs
  /// storage; deleting a receipt off a real entry costs the household its
  /// paperwork.
  bool _attemptedWrite = false;

  /// Uploads still in flight. The cleanup waits for them: a file picked and
  /// then abandoned mid-upload would otherwise be inserted after the query
  /// that was meant to find it, and nothing would ever list it again.
  final _uploads = <Future<void>>[];

  /// Whether anything was attached in this sheet, which makes it dirty: a
  /// receipt is worth more than the fields around it, and dismissing the
  /// sheet by tapping outside used to take it with no question asked.
  bool _attachedAny = false;

  /// Read in [initState], while there is still a ref to read it with: the
  /// cleanup runs from [dispose], where the element is already going away and
  /// a lazy read would throw.
  late final AttachmentRepository _attachments;

  /// Starts as the vehicle the sheet was opened for; the first row lets a
  /// new entry move to another car before anything is saved.
  late String _vehicleId = widget.vehicleId;
  final _odometer = TextEditingController();
  final _volume = TextEditingController();
  final _price = TextEditingController();
  final _total = TextEditingController();
  final _priceFocus = FocusNode();
  final _totalFocus = FocusNode();
  final _station = TextEditingController();
  final _notes = TextEditingController();

  DateTime _date = DateTime.now();

  /// Which fuel went in, on a car that takes two. Null until chosen, and null
  /// forever on a car that takes one — where naming it would be a field with
  /// one possible answer.
  String? _fuelTypeKey;

  /// The field this sheet filled in for you, and what it put there.
  ///
  /// Kept so the arithmetic can be redone when an input changes, and undone
  /// when one is cleared — while anything the household typed itself is left
  /// exactly as typed. A pump that rounds, or a receipt with a discount on
  /// it, beats our multiplication every time.
  TextEditingController? _derivedField;
  String _derivedText = '';

  bool _fullTank = true;
  bool _missedFill = false;
  bool _busy = false;
  bool _odometerMissing = false;
  String? _amountError;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _attachments = ref.read(attachmentRepositoryProvider);
    // A prefilled price is a suggestion. With the caret at its end, typing
    // "1.47" over "1.45" gave "1.451.47" and a blank total; selected on
    // focus, the first keystroke replaces it.
    _priceFocus.addListener(_selectGuessedPrice);
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
  /// A new entry moved to another car: what was guessed for the first car
  /// (its last station, its last price) is guessed again for this one;
  /// what was typed stays.
  void _switchVehicle(String vehicleId) {
    setState(() {
      _vehicleId = vehicleId;
      if (_station.text == _guessedStation) {
        _station.clear();
      }
      if (_price.text == _guessedPrice) {
        _price.clear();
      }
      _guessedStation = null;
      _guessedPrice = null;
      _fuelTypeKey = null;
      _atThePump = null;
    });
    _prefillFromLastEntry();
    _prefillFromPump();
  }

  void _selectGuessedPrice() {
    if (_priceFocus.hasFocus &&
        _price.text.isNotEmpty &&
        _price.text == _guessedPrice) {
      _price.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _price.text.length,
      );
    }
  }

  /// A live "not a number" for an amount that is neither a number nor a
  /// sum in progress: a malformed price used to blank the total in silence.
  String? _notANumber(AppLocalizations l10n, String text) {
    if (text.trim().isEmpty || isAmountExpression(text)) {
      return null;
    }
    // The same reader the total and the save use, so what is flagged here
    // is exactly what would have blanked the total.
    return evaluateAmount(text) == null ? l10n.amountNotANumber : null;
  }

  Future<void> _prefillFromLastEntry() async {
    // Both prefills remember which car they were started for: a switch
    // while one is in flight must not land the first car's station and
    // price on the second.
    final forVehicle = _vehicleId;
    final last = await ref.read(latestFuelEntryProvider(forVehicle).future);
    if (!mounted || _vehicleId != forVehicle || last == null) {
      return;
    }
    final prefs = ref.read(unitPreferencesProvider);
    // Today's price where they last filled up, which beats what they paid
    // there last month. Only the price is taken from it — the station itself
    // is still the one the last fill-up recorded.
    final posted = await _postedPriceAtLastStation(last.station);
    if (!mounted || _vehicleId != forVehicle) {
      return;
    }
    final pricePerL = posted ?? last.pricePerL;
    setState(() {
      if (_station.text.isEmpty && last.station != null) {
        _station.text = last.station!;
        _guessedStation = last.station;
      }
      if (_price.text.isEmpty && pricePerL != null) {
        _price.text = UnitFormat.editableNumber(
          pricePerL * prefs.displayToLiters(1),
        );
        _guessedPrice = _price.text;
      }
    });
    _selectGuessedPrice();
  }

  /// Only reached for a new fill-up: an edit shows the price that was actually
  /// paid, and quietly moving a recorded amount to today's would be a bug
  /// rather than a convenience.
  Future<double?> _postedPriceAtLastStation(String? stationName) async {
    if (stationName == null) {
      return null;
    }
    final vehicle = await ref.read(vehicleProvider(_vehicleId).future);
    if (vehicle == null) {
      return null;
    }
    final stations = await ref.read(stationsProvider.future);
    return postedPriceAt(
      stations: stations,
      stationName: stationName,
      fuelTypeId: StationFuel.forVehicle(vehicle.fuelTypeKey),
    );
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
    final forVehicle = _vehicleId;
    final match = await ref.read(stationAtThePumpProvider(forVehicle).future);
    if (!mounted || _vehicleId != forVehicle || match == null) {
      return;
    }
    final prefs = ref.read(unitPreferencesProvider);
    final price = UnitFormat.editableNumber(
      match.pricePerUnit * prefs.displayToLiters(1),
    );
    setState(() {
      if (_station.text.isEmpty || _station.text == _guessedStation) {
        _station.text = match.station.displayName;
        _guessedStation = match.station.displayName;
      }
      if (_price.text.isEmpty || _price.text == _guessedPrice) {
        _price.text = price;
        _guessedPrice = price;
      }
      _atThePump = match;
    });
    _selectGuessedPrice();
  }

  PumpMatch? _atThePump;

  /// Works out whichever of volume, price and total was left blank, as it is
  /// typed rather than on save.
  ///
  /// The arithmetic was always here — it just ran once, at save, so a sheet
  /// showing 45 litres at 1.35 said nothing about the 60.75 on the receipt in
  /// your hand until you committed it.
  void _deriveOnTheFly() {
    // Ours to overwrite, so it does not count as a value when deciding what
    // is missing.
    if (_derivedField != null && _derivedField!.text != _derivedText) {
      // Typed over by hand since we filled it: it is theirs now.
      _derivedField = null;
    }
    _derivedField?.text = '';

    final volume = _parse(_volume.text);
    final price = evaluateAmount(_price.text);
    final total = evaluateAmount(_total.text);

    final target = switch ((volume, price, total)) {
      (null, != null, != null) => _volume,
      (!= null, null, != null) => _price,
      (!= null, != null, null) => _total,
      _ => null,
    };
    // The three fields are in display units, and the price is per the same
    // unit the volume is in, so the arithmetic holds whatever those units are.
    final derived = FuelEntry.deriveThird(
      volumeL: volume,
      pricePerL: price,
      total: total,
    );
    if (target == null || derived == null || !derived.isFinite) {
      _derivedField = null;
      _derivedText = '';
      return;
    }

    // Money to the cent, a volume or a unit price to what the pump shows.
    final text = UnitFormat.editableNumber(
      derived,
      decimals: target == _total ? 2 : 3,
    );
    _derivedField = target;
    _derivedText = text;
    target.text = text;
  }

  @override
  void dispose() {
    if (widget.existing == null && !_saved && !_attemptedWrite) {
      // Fire and forget: the sheet is going, and there is nothing left to
      // report a failed cleanup to.
      unawaited(
        discardUnsavedAttachments(
          _attachments,
          pending: _uploads,
          kind: AttachmentEntryKind.fuel,
          entryId: _newId,
        ),
      );
    }
    _odometer.dispose();
    _volume.dispose();
    _price.dispose();
    _total.dispose();
    _priceFocus.removeListener(_selectGuessedPrice);
    _priceFocus.dispose();
    _totalFocus.dispose();
    _station.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showGarageDatePicker(
      context: context,
      initialDate: _date,
      firstDate: firstLoggableDate(_date),
      // Already happened: dating it ahead is a typo, not a plan.
      lastDate: lastLoggableDate(_date),
    );
    if (picked != null && mounted) {
      setState(() => _date = picked);
    }
  }

  /// A closed sheet said nothing, and "Average —" on the dashboard gave no
  /// reason. The one thing a first fill-up needs to say is what happens next.
  void _confirmSaved(
    FuelEntry entry,
    UnitPreferences prefs,
    int? fullBefore, {
    bool queued = false,
  }) {
    final l10n = AppLocalizations.of(context)!;
    if (queued) {
      // The entry is on the phone and will go on its own. Confirming the
      // amount as though it had reached the garage would be a lie the person
      // only discovers when somebody else cannot see it.
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.syncEntryQueued)));
      return;
    }
    final format = UnitFormat(
      locale: Localizations.localeOf(context).languageCode,
      preferences: prefs,
    );
    final total = entry.total;
    final message = total == null
        ? l10n.fuelSavedPlain
        : entry.fullTank && fullBefore == 0
        ? l10n.fuelSavedFirstFull(format.formatMoney(total))
        : l10n.fuelSaved(format.formatMoney(total));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
      id: widget.existing?.id ?? _newId,
      vehicleId: _vehicleId,
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
      // Counted before the invalidate below: whether this is the first full
      // tank decides what the confirmation promises.
      final known = ref.read(rawFuelEntriesProvider(_vehicleId));
      // Null when the log is not known: an errored fetch must not turn a
      // garage with years of fills into "your first full tank".
      // Per fuel, like consumption itself: a petrol full tank does not make
      // the first LPG one the second. Null means the vehicle's main fuel.
      final mainFuel = ref.read(vehicleProvider(_vehicleId)).value?.fuelTypeKey;
      final fullFillsBefore = known.hasValue
          ? known.value!
                .where(
                  (e) =>
                      e.fullTank &&
                      (e.fuelTypeKey ?? mainFuel) ==
                          (entry.fuelTypeKey ?? mainFuel),
                )
                .length
          : null;
      if (widget.existing == null) {
        // Two network stages, both bounded: the price lookup degrades to
        // "no context" when it is slow, the insert itself times out.
        final priceContext = await _priceContextFor(
          entry,
        ).timeout(writeTimeout, onTimeout: () => null);
        // Set before the write, not after: a write that times out may still
        // have landed, and the cleanup must not delete the receipts off an
        // entry that exists.
        _attemptedWrite = true;
        await writeNew(
          () => ref
              .read(fuelRepositoryProvider)
              .add(entry.copyWith(priceContext: priceContext)),
        );
        _saved = true;
      } else {
        // Never on an edit. The snapshot describes the day the fill-up
        // happened, and re-reading today's market onto it would replace what
        // was true then with what is true now.
        await writeWithTimeout(ref.read(fuelRepositoryProvider).update(entry));
      }
      ref.invalidate(rawFuelEntriesProvider(_vehicleId));
      // Whether it reached the garage or is waiting on the phone. The
      // repository queues silently by design, so this is where the difference
      // becomes visible.
      final queued = (await ref.read(pendingWriteStoreProvider).all()).any(
        (write) => write.id == entry.id,
      );
      if (mounted) {
        if (widget.existing == null) {
          _confirmSaved(entry, prefs, fullFillsBefore, queued: queued);
        }
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

  /// The cheapest station near the one this fill-up names, as the dataset has
  /// it right now.
  ///
  /// Best-effort and entirely silent: the prices come from a network fetch
  /// that may not have happened, and a saved fill-up must never fail because
  /// a price lookup did.
  Future<FuelPriceContext?> _priceContextFor(FuelEntry entry) async {
    try {
      final vehicle = await ref.read(vehicleProvider(_vehicleId).future);
      if (vehicle == null) {
        return null;
      }
      final cheapest = cheapestNear(
        stations: await ref.read(stationsProvider.future),
        stationName: entry.station,
        fuelTypeId: StationFuel.forVehicle(
          entry.fuelTypeKey ?? vehicle.fuelTypeKey,
        ),
      );
      if (cheapest == null) {
        return null;
      }
      final now = DateTime.now().toUtc();
      return FuelPriceContext(
        station: cheapest.station,
        pricePerUnit: cheapest.pricePerUnit,
        distanceKm: cheapest.distanceKm,
        seenOn: DateTime.utc(now.year, now.month, now.day),
      );
    } catch (_) {
      return null;
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
      await sweepAttachments(
        ref.read(attachmentRepositoryProvider),
        kind: AttachmentEntryKind.fuel,
        entryId: widget.existing!.id,
      );
      ref.invalidate(rawFuelEntriesProvider(_vehicleId));
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
    final vehicle = ref.watch(vehicleProvider(_vehicleId)).value;

    // The guard is a window, not a floor: an entry being edited, or one
    // backdated into the middle of the log, is judged against the fills that
    // bracket its own date rather than against the newest reading on record.
    // Every kind of reading, not just fill-ups. Bounded by the fuel log alone,
    // a household that logs services or bare readings and pays cash at the
    // pump could type any number here and be told nothing — and that is the
    // household odometer entries were added for.
    final samples =
        ref.watch(rawOdometerSamplesProvider(_vehicleId)).value ??
        const <OdometerSample>[];
    final bounds = OdometerBounds.forSamples(
      samples,
      date: _date,
      // The reading this fill-up already contributes, so an edit is not
      // measured against its own stored figure.
      excluding: switch (widget.existing) {
        final FuelEntry existing => OdometerSample(
          date: existing.date,
          km: existing.odometerKm,
        ),
        null => null,
      },
    );
    final odometerDisplay = _parse(_odometer.text);
    final odometerKm = odometerDisplay == null
        ? null
        : prefs.displayToKm(odometerDisplay).round();
    final tooLow = odometerKm != null && bounds.isTooLow(odometerKm);
    final tooHigh = odometerKm != null && bounds.isTooHigh(odometerKm);
    // Before the first fill-up the only reading is the one the car was
    // added with; a blank helper there left the driver typing from memory.
    final previousKm = bounds.previousKm ?? vehicle?.baselineOdometerKm;
    final previousReading = previousKm == null
        ? null
        : format.formatDistance(previousKm.toDouble(), decimals: 0);
    // A reading earlier today beats the baseline as the number to compare
    // the pump display against; the baseline is exactly what it replaced.
    final earlierToday = bounds.previousKm == null && bounds.sameDayKm != null
        ? format.formatDistance(bounds.sameDayKm!.toDouble(), decimals: 0)
        : null;

    final energy = ref.watch(vehicleEnergyProvider(_vehicleId));

    // Checked against the derived volume, so a fill entered as price + total
    // is caught the same as one entered in litres. A battery has no tank to
    // overfill, so the check simply does not apply to an electric vehicle.
    final tankCapacityL = energy.isElectric
        ? null
        : ref.watch(vehicleProvider(_vehicleId)).value?.tankCapacityL;
    final enteredVolume = deriveMissingValue(
      volume: _volume.text,
      price: _price.text,
      total: _total.text,
    ).volume;
    final overTank =
        tankCapacityL != null &&
        enteredVolume != null &&
        prefs.displayToLiters(enteredVolume) > tankCapacityL;

    // What the fill-up implies about consumption, checked while it is being
    // typed. A transposed digit in the odometer reads as plausible on its own
    // and only becomes nonsense beside the litres; without this, nothing said
    // so until the economy figure went strange weeks later.
    final impliedRate = switch ((odometerKm, previousKm, enteredVolume)) {
      (final now?, final before?, final volume?) => impliedConsumption(
        distanceKm: prefs.displayToKm((now - before).toDouble()),
        quantity: energy.isElectric ? volume : prefs.displayToLiters(volume),
        energy: energy,
      ),
      _ => null,
    };
    final implausibleRate = !overTank && !tooLow && !tooHigh
        ? isImplausibleConsumption(impliedRate, energy)
        : false;

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
              DiscardGuard(
                alsoDirty: () => _attachedAny,
                controllers: [
                  _odometer,
                  _volume,
                  _price,
                  _total,
                  _station,
                  _notes,
                ],
              ),
              Text(
                widget.existing == null ? l10n.fuelAdd : l10n.fuelEdit,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              SheetVehicleRow(
                vehicleId: _vehicleId,
                // Locked once a receipt is on it. The file carries the car's
                // id in its own row and its storage path, and a car that is
                // later deleted or handed over takes everything keyed to it
                // — so an attachment left pointing at the wrong car is not a
                // cosmetic mismatch.
                onSwitch: widget.existing == null && !_attachedAny
                    ? _switchVehicle
                    : null,
                lockedNote: widget.existing == null && _attachedAny
                    ? l10n.sheetVehicleLockedByFile
                    : null,
              ),
              const SizedBox(height: GarageTokens.space2),
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
                    suffixIcon: unitSuffix(context, format.distanceSuffix),
                    // The last reading is the number the driver is comparing
                    // the pump display against, so it belongs on screen
                    // rather than one screen back in the log.
                    helperText: earlierToday != null
                        ? l10n.fuelOdometerEarlierToday(earlierToday)
                        : previousReading == null
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
                    suffixIcon: unitSuffix(
                      context,
                      format.energySuffix(energy),
                    ),
                    errorText: overTank
                        ? l10n.fuelVolumeOverTank(
                            format.formatVolume(tankCapacityL, decimals: 0),
                          )
                        : null,
                    // A warning, not a refusal: a jerrycan, a fill after a
                    // tow and a forgotten fill-up are all real, and the
                    // household is the one who knows which this is.
                    helperText: implausibleRate
                        ? l10n.fuelImpliedConsumption(
                            format.formatEconomy(impliedRate!, energy),
                          )
                        : null,
                    helperMaxLines: 2,
                    helperStyle: TextStyle(color: context.tokens.danger),
                  ),
                  onChanged: (_) => setState(_deriveOnTheFly),
                ),
              ),
              const SizedBox(height: GarageTokens.space3),
              LabeledField(
                label: l10n.fuelPricePerUnit,
                child: TextField(
                  controller: _price,
                  focusNode: _priceFocus,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: GarageTheme.numericField(context),
                  decoration: InputDecoration(
                    suffixIcon: unitSuffix(
                      context,
                      format.pricePerUnitSuffix(energy),
                    ),
                    errorText: _notANumber(l10n, _price.text),
                  ),
                  onChanged: (_) => setState(_deriveOnTheFly),
                ),
              ),
              const SizedBox(height: GarageTokens.space3),
              LabeledField(
                label: l10n.fuelTotal,
                child: TextField(
                  controller: _total,
                  focusNode: _totalFocus,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: GarageTheme.numericField(context),
                  decoration: InputDecoration(
                    suffixIcon: unitSuffix(context, format.currencySymbol),
                    errorText: _notANumber(l10n, _total.text),
                  ),
                  onChanged: (_) => setState(_deriveOnTheFly),
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
                    match.station.displayName,
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
                  // The entry is not lost, which is the first thing a person
                  // whose save failed wants to know.
                  '${failureMessage(l10n, _failure!)} ${l10n.saveEntryKept}',
                  style: TextStyle(color: context.tokens.danger),
                ),
              ],
              const SizedBox(height: GarageTokens.space4),
              // Offered while the entry is still being typed: the id
              // exists before the row does, and anything attached to a
              // sheet that is then abandoned is taken back down.
              EntryAttachments(
                vehicleId: _vehicleId,
                kind: AttachmentEntryKind.fuel,
                entryId: widget.existing?.id ?? _newId,
                onUpload: (upload) {
                  _uploads.add(upload);
                  setState(() => _attachedAny = true);
                },
              ),
              const SizedBox(height: GarageTokens.space5),
              AmountCalculatorDock(
                fields: [
                  AmountField(_price, _priceFocus),
                  AmountField(_total, _totalFocus),
                ],
                format: format,
              ),
              const SizedBox(height: GarageTokens.space2),
              FilledButton(
                onPressed: _busy ? null : () => _submit(prefs),
                child: BusyLabel(busy: _busy, child: Text(l10n.commonSave)),
              ),
              StillSavingNote(busy: _busy),
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
