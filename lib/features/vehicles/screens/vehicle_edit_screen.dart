import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/files/file_picker.dart';
import '../../../core/format/unit_format.dart';
import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../core/widgets/adaptive.dart';
import '../../../core/widgets/busy_label.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../core/widgets/failure_message.dart';
import '../../../core/widgets/confirm_delete.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../core/widgets/vehicle_photo.dart';
import '../../../core/files/image_compression.dart';
import '../../../domain/entities/household.dart';
import '../../../domain/entities/vehicle.dart';
import '../../../domain/format/amount_expression.dart';
import 'photo_crop_screen.dart';
import '../../household/providers/household_providers.dart';
import '../../settings/providers/unit_providers.dart';
import '../drivetrain_labels.dart';
import '../vehicle_kind_labels.dart';
import '../fuel_type_labels.dart';
import '../providers/vehicle_providers.dart';
import '../../../core/widgets/discard_guard.dart';
import '../../../core/widgets/amount_calculator_dock.dart';

/// The language-neutral fuel-type keys stored on the vehicle. Labels come from
/// the ARB at display time.
class VehicleEditScreen extends ConsumerStatefulWidget {
  const VehicleEditScreen({this.vehicleId, super.key});

  final String? vehicleId;

  @override
  ConsumerState<VehicleEditScreen> createState() => _VehicleEditScreenState();
}

class _VehicleEditScreenState extends ConsumerState<VehicleEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _engineSection = ExpansibleController();
  bool _touched = false;
  bool _prefilling = false;
  final _vinAnchor = GlobalKey();
  final _nicknameAnchor = GlobalKey();
  final _purchasePriceFocus = FocusNode();
  final _nickname = TextEditingController();
  final _make = TextEditingController();
  final _model = TextEditingController();
  final _year = TextEditingController();
  final _plate = TextEditingController();
  final _vin = TextEditingController();
  final _odometer = TextEditingController();
  final _tankCapacity = TextEditingController();
  final _purchasePrice = TextEditingController();

  String _fuelTypeKey = 'fuel_petrol';
  String? _secondaryFuelTypeKey;
  String? _timingDrive;
  String? _transmission;
  String _kind = 'car';
  String? _finalDrive;
  String? _decodedTrim;

  /// The photo path once one has been uploaded in this session, so saving
  /// records it. A vehicle keeps whatever it already had until then.
  String? _photoPath;

  /// Set once the photo has been removed in this session. Distinct from
  /// [_photoPath] being null, which just means untouched — the save below
  /// needs to tell "keep what the vehicle already had" from "clear it".
  bool _photoRemoved = false;
  bool _uploadingPhoto = false;
  bool _busy = false;
  bool _prefilled = false;
  bool _decoding = false;
  String? _vinMessage;
  AppFailure? _failure;

  bool get _isEditing => widget.vehicleId != null;

  @override
  void dispose() {
    _engineSection.dispose();
    _nickname.dispose();
    _make.dispose();
    _model.dispose();
    _year.dispose();
    _plate.dispose();
    _vin.dispose();
    _odometer.dispose();
    _tankCapacity.dispose();
    _purchasePrice.dispose();
    _purchasePriceFocus.dispose();
    super.dispose();
  }

  void _prefill(Vehicle vehicle, UnitPreferences prefs) {
    if (_prefilled) {
      return;
    }
    // Synchronous, so the flag covers exactly the assignments below and not
    // a keystroke that lands later: a prefill that arrives after the first
    // frame reaches Form.onChanged like typing would.
    _prefilling = true;
    _prefilled = true;
    _nickname.text = vehicle.nickname;
    _make.text = vehicle.make ?? '';
    _model.text = vehicle.model ?? '';
    _year.text = vehicle.year?.toString() ?? '';
    _plate.text = vehicle.plate ?? '';
    _vin.text = vehicle.vin ?? '';
    // Canonical km back into the household's display unit.
    _odometer.text = prefs
        .kmToDisplay(vehicle.baselineOdometerKm.toDouble())
        .round()
        .toString();
    final capacity = vehicle.tankCapacityL;
    if (capacity != null) {
      _tankCapacity.text = UnitFormat.editableNumber(
        prefs.litersToDisplay(capacity),
        decimals: 1,
      );
    }
    final price = vehicle.purchasePrice;
    if (price != null) {
      _purchasePrice.text = price.toStringAsFixed(2);
    }
    _fuelTypeKey = vehicle.fuelTypeKey;
    _secondaryFuelTypeKey = vehicle.secondaryFuelTypeKey;
    _timingDrive = vehicle.timingDrive;
    _transmission = vehicle.transmission;
    _kind = vehicle.kind;
    _finalDrive = vehicle.finalDrive;
    _prefilling = false;
  }

  /// Fills make, model, year, and trim from the VIN registry. Everything it
  /// writes stays editable: the registry is US-oriented and a European VIN
  /// often decodes to the make and little else.
  /// Uploads a photo for the vehicle being edited.
  ///
  /// Only for a vehicle that already exists: the storage path is keyed by its
  /// id, which a vehicle being created does not have yet.
  Future<void> _pickPhoto(Vehicle vehicle) async {
    final file = await ref.read(filePickerProvider)();
    if (file == null) {
      return;
    }
    final rawBytes = await file.readAsBytes();
    if (!mounted) {
      return;
    }

    // A PDF picked through the same dialog, or a HEIC shot none of the pure
    // Dart codecs in this app can read, cannot be laid out in a cropping
    // editor either — sent straight to upload, exactly as before cropping
    // existed, rather than opening an editor on a file it cannot show.
    var bytesToUpload = rawBytes;
    if (isCroppableImage(rawBytes)) {
      final cropped = await Navigator.of(context).push<Uint8List>(
        MaterialPageRoute(builder: (_) => PhotoCropScreen(image: rawBytes)),
      );
      if (!mounted) {
        return;
      }
      // Backing out of framing the photo backs out of the whole pick, the
      // same as closing the file dialog without choosing anything — sending
      // the uncropped original would be sending a photo the household never
      // actually chose to send.
      if (cropped == null) {
        return;
      }
      bytesToUpload = cropped;
    }

    setState(() {
      _uploadingPhoto = true;
      _failure = null;
    });
    try {
      final bytes = compressIconImage(bytesToUpload);
      final path = await ref
          .read(vehiclePhotoRepositoryProvider)
          .upload(
            householdId: vehicle.householdId,
            vehicleId: vehicle.id,
            bytes: bytes,
            contentType: identical(bytes, bytesToUpload)
                ? file.mimeType
                : 'image/jpeg',
          );
      ref.invalidate(vehiclePhotoUrlProvider(vehicle.id));
      if (mounted) {
        setState(() {
          _photoPath = path;
          _photoRemoved = false;
        });
      }
      // Best-effort, and after the state that matters is already set: the
      // upload path is fixed per vehicle, so nothing about the URL changes,
      // and the on-disk cache from `VehiclePhoto` would otherwise keep
      // showing the photo just replaced. Whether the eviction itself
      // succeeds must never be why a completed upload fails to record.
      unawaited(VehiclePhoto.evictCache(vehicle.id).catchError((_) {}));
    } catch (error) {
      if (mounted) {
        setState(() => _failure = AppFailure.from(error));
      }
    } finally {
      if (mounted) {
        setState(() => _uploadingPhoto = false);
      }
    }
  }

  /// Removes the photo for the vehicle being edited, storage and all — not
  /// only what this session would have saved. A vehicle can go back to
  /// having none.
  Future<void> _removePhoto(Vehicle vehicle) async {
    final path = _photoPath ?? vehicle.photoUrl;
    if (path == null) {
      return;
    }
    if (!await confirmDelete(context) || !mounted) {
      return;
    }
    setState(() {
      _uploadingPhoto = true;
      _failure = null;
    });
    try {
      await ref.read(vehiclePhotoRepositoryProvider).delete(path);
      ref.invalidate(vehiclePhotoUrlProvider(vehicle.id));
      if (mounted) {
        setState(() {
          _photoPath = null;
          _photoRemoved = true;
        });
      }
      unawaited(VehiclePhoto.evictCache(vehicle.id).catchError((_) {}));
    } catch (error) {
      if (mounted) {
        setState(() => _failure = AppFailure.from(error));
      }
    } finally {
      if (mounted) {
        setState(() => _uploadingPhoto = false);
      }
    }
  }

  Future<void> _lookUpVin() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _decoding = true;
      _vinMessage = null;
    });
    try {
      final decoded = await ref.read(vinDecoderProvider).decode(_vin.text);
      if (!mounted) {
        return;
      }
      if (decoded.isEmpty) {
        setState(() => _vinMessage = l10n.vehicleVinNotFound);
        return;
      }
      setState(() {
        if (decoded.make != null) {
          _make.text = decoded.make!;
        }
        if (decoded.model != null) {
          _model.text = decoded.model!;
        }
        if (decoded.year != null) {
          _year.text = '${decoded.year}';
        }
        _decodedTrim = decoded.trim ?? _decodedTrim;
        _vinMessage = l10n.vehicleVinDecoded;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _vinMessage = l10n.vehicleVinNotFound);
      }
    } finally {
      if (mounted) {
        setState(() => _decoding = false);
      }
    }
  }

  String? _emptyToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  /// The field is in the household's volume unit; the entity stores litres.
  /// Blank and nonsense both mean "not known", which simply disables the
  /// over-tank check on fill-ups.
  double? _tankCapacityLiters(UnitPreferences prefs) {
    final value = double.tryParse(
      _tankCapacity.text.trim().replaceAll(',', '.'),
    );
    if (value == null || value <= 0) {
      return null;
    }
    return prefs.displayToLiters(value);
  }

  /// Not unit-converted like [_tankCapacityLiters]: the household's currency
  /// goes in as typed, the same as every other amount in the app.
  double? _purchasePriceAmount() {
    final value = evaluateAmount(_purchasePrice.text);
    return value == null || value < 0 ? null : value;
  }

  /// A name is required; the rest of the form is optional.
  static bool _nameAccepted(String value) => value.trim().isNotEmpty;

  /// Mirrors the column's check constraint (migration 0003): pre-1981 cars
  /// had shorter numbers, so 17 alone would refuse a real one.
  static bool _vinAccepted(String value) {
    final length = value.trim().length;
    return length == 0 || (length >= 11 && length <= 17);
  }

  /// Every field that can be refused, in the order they appear, with where
  /// each one lives. **A new validator belongs here too**: routing a refusal
  /// off anything but the field that carries it takes the household to the
  /// wrong place and unfolds a section nobody asked for.
  List<({GlobalKey anchor, bool folded})> get _refusedFields => [
    if (!_nameAccepted(_nickname.text))
      (anchor: _nicknameAnchor, folded: false),
    if (!_vinAccepted(_vin.text)) (anchor: _vinAnchor, folded: true),
  ];

  Future<void> _submit(Vehicle? existing) async {
    final l10n = AppLocalizations.of(context)!;
    // Re-entrant while the scroll below animates: Save stayed tappable for
    // the best part of half a second after a refusal.
    if (_busy) {
      return;
    }
    if (!_formKey.currentState!.validate()) {
      // Take the household to the first field that was actually refused. A
      // red line behind a folded heading is a Save button that does nothing,
      // and unfolding the engine section over a missing name would both hide
      // the complaint and open something nobody asked for.
      final refused = _refusedFields.firstOrNull;
      if (refused == null) {
        return;
      }
      if (refused.folded) {
        _engineSection.expand();
        // Unfolded is not seen: the section opens two screens below the
        // viewport. Wait for its animation before bringing the field up.
        await Future<void>.delayed(const Duration(milliseconds: 250));
        if (!mounted) {
          return;
        }
      }
      final anchor = refused.anchor.currentContext;
      if (anchor != null && anchor.mounted) {
        await Scrollable.ensureVisible(
          anchor,
          alignment: 0.2,
          duration: const Duration(milliseconds: 200),
        );
      }
      return;
    }
    setState(() {
      _busy = true;
      _failure = null;
    });

    // Awaited rather than read synchronously. In the app the router keeps
    // the household loaded before this screen is reachable; with no other
    // listener (a widget test of the create path) a synchronous read said
    // "still loading" and the save silently did nothing. Inside the try so
    // an errored household renders like every other failure here.
    final Household? household;
    try {
      household = await ref.read(currentHouseholdProvider.future);
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _failure = AppFailure.from(error);
        });
      }
      return;
    }
    if (household == null || !mounted) {
      if (mounted) {
        setState(() => _busy = false);
      }
      return;
    }

    // The field is in the household's display unit; store canonical km.
    final prefs = ref.read(unitPreferencesProvider);
    final odometerDisplay = int.tryParse(_odometer.text.trim()) ?? 0;
    final odometer = prefs.displayToKm(odometerDisplay.toDouble()).round();
    final now = DateTime.now();

    try {
      final repository = ref.read(vehicleRepositoryProvider);
      if (existing == null) {
        await repository.create(
          Vehicle(
            id: '',
            householdId: household.id,
            nickname: _nickname.text.trim(),
            fuelTypeKey: _fuelTypeKey,
            secondaryFuelTypeKey: _secondaryFuelTypeKey,
            timingDrive: _timingDrive,
            transmission: _transmission,
            kind: _kind,
            // A rear-wheel drive on a car would be a stale answer to a
            // question the form no longer asks.
            finalDrive: _kind == 'motorcycle' ? _finalDrive : null,
            baselineOdometerKm: odometer,
            // Local calendar day, flagged UTC per the domain invariant. This
            // baseline is what stops a newly added high-mileage car from
            // projecting every interval as already overdue.
            baselineDate: DateTime.utc(now.year, now.month, now.day),
            make: _emptyToNull(_make.text),
            model: _emptyToNull(_model.text),
            year: int.tryParse(_year.text.trim()),
            plate: _emptyToNull(_plate.text),
            vin: _emptyToNull(_vin.text),
            trim: _decodedTrim,
            tankCapacityL: _tankCapacityLiters(prefs),
            purchasePrice: _purchasePriceAmount(),
          ),
        );
      } else {
        await repository.update(
          Vehicle(
            id: existing.id,
            householdId: existing.householdId,
            nickname: _nickname.text.trim(),
            fuelTypeKey: _fuelTypeKey,
            secondaryFuelTypeKey: _secondaryFuelTypeKey,
            timingDrive: _timingDrive,
            transmission: _transmission,
            kind: _kind,
            // A rear-wheel drive on a car would be a stale answer to a
            // question the form no longer asks.
            finalDrive: _kind == 'motorcycle' ? _finalDrive : null,
            baselineOdometerKm: odometer,
            baselineDate: existing.baselineDate,
            make: _emptyToNull(_make.text),
            model: _emptyToNull(_model.text),
            year: int.tryParse(_year.text.trim()),
            trim: _decodedTrim ?? existing.trim,
            plate: _emptyToNull(_plate.text),
            vin: _emptyToNull(_vin.text),
            photoUrl: _photoRemoved ? null : (_photoPath ?? existing.photoUrl),
            tankCapacityL: _tankCapacityLiters(prefs),
            archived: existing.archived,
            // Not `?? existing.purchasePrice`: that made the field the one
            // thing on this form that could be set and never unset, because
            // emptying it put the old figure straight back.
            purchasePrice: _purchasePriceAmount(),
          ),
        );
      }
      ref.invalidate(allVehiclesProvider);
      if (mounted) {
        // Every other first save says so; this one returned to the dashboard
        // in silence.
        if (existing == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.vehicleAdded(_nickname.text.trim()))),
          );
        }
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/vehicles');
        }
      }
    } catch (error) {
      if (mounted) {
        setState(() => _failure = AppFailure.from(error));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
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

    final existing = _isEditing
        ? ref.watch(vehicleProvider(widget.vehicleId!)).value
        : null;
    if (existing != null) {
      _prefill(existing, prefs);
    }

    return GaragePageScaffold(
      title: _isEditing ? l10n.vehicleEdit : l10n.vehiclesAdd,
      body: SafeArea(
        child: AdaptiveContent(
          width: ContentWidth.form,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(GarageTokens.space4),
            child: Form(
              key: _formKey,
              // Once a save has shown an error, correcting the field clears
              // it; a line that stays red after the fix reads as a second one.
              autovalidateMode: AutovalidateMode.onUserInteractionIfError,
              // Pickers and switches are not text; any change to a form
              // field counts as the person's.
              onChanged: () {
                if (!_prefilling) {
                  _touched = true;
                }
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DiscardGuard(
                    controllers: [
                      _nickname,
                      _make,
                      _model,
                      _year,
                      _plate,
                      _vin,
                      _odometer,
                      _tankCapacity,
                      _purchasePrice,
                    ],
                    alsoDirty: () => _touched,
                  ),
                  LabeledField(
                    key: _nicknameAnchor,
                    label: l10n.vehicleNickname,
                    child: TextFormField(
                      controller: _nickname,
                      validator: (value) => _nameAccepted(value ?? '')
                          ? null
                          : l10n.vehicleNameRequired,
                    ),
                  ),
                  const SizedBox(height: GarageTokens.space4),
                  LabeledField(
                    label: l10n.vehicleKind,
                    child: DropdownButtonFormField<String>(
                      key: const Key('vehicle-kind'),
                      initialValue: _kind,
                      isExpanded: true,
                      items: [
                        for (final key in vehicleKindKeys)
                          DropdownMenuItem(
                            value: key,
                            child: Text(vehicleKindLabel(l10n, key) ?? key),
                          ),
                      ],
                      onChanged: (value) =>
                          setState(() => _kind = value ?? _kind),
                    ),
                  ),
                  const SizedBox(height: GarageTokens.space4),
                  LabeledField(
                    label: l10n.vehicleMake,
                    child: TextFormField(controller: _make),
                  ),
                  const SizedBox(height: GarageTokens.space4),
                  LabeledField(
                    label: l10n.vehicleModel,
                    child: TextFormField(controller: _model),
                  ),
                  const SizedBox(height: GarageTokens.space4),
                  LabeledField(
                    label: l10n.vehicleYear,
                    child: TextFormField(
                      controller: _year,
                      keyboardType: TextInputType.number,
                      style: GarageTheme.numericField(context),
                    ),
                  ),
                  const SizedBox(height: GarageTokens.space4),
                  LabeledField(
                    label: l10n.vehiclePlate,
                    child: TextFormField(controller: _plate),
                  ),
                  const SizedBox(height: GarageTokens.space4),
                  LabeledField(
                    label: l10n.vehicleOdometer,
                    child: TextFormField(
                      controller: _odometer,
                      keyboardType: TextInputType.number,
                      style: GarageTheme.numericField(context),
                      decoration: InputDecoration(
                        // Name the unit so the value is entered in the household's
                        // distance unit, matching how it round-trips.
                        suffixText: format.distanceSuffix,
                      ),
                    ),
                  ),
                  const SizedBox(height: GarageTokens.space4),
                  // The mechanic's questions, folded away on a new car: a first
                  // form that opened with belt-or-chain before the car's name read
                  // as a tool for a trade.
                  _FormSection(
                    key: const Key('vehicle-section-engine'),
                    controller: _engineSection,
                    title: l10n.vehicleSectionEngine,
                    initiallyExpanded: _isEditing,
                    children: [
                      LabeledField(
                        label: l10n.vehicleFuelType,
                        child: DropdownButtonFormField<String>(
                          initialValue: _fuelTypeKey,
                          items: [
                            for (final key in fuelTypeKeys)
                              DropdownMenuItem(
                                value: key,
                                child: Text(fuelTypeLabel(l10n, key) ?? key),
                              ),
                          ],
                          onChanged: (value) => setState(() {
                            _fuelTypeKey = value ?? _fuelTypeKey;
                            // A second fuel that is the same as the first is not a
                            // second fuel, and the database refuses it.
                            if (_secondaryFuelTypeKey == _fuelTypeKey) {
                              _secondaryFuelTypeKey = null;
                            }
                          }),
                        ),
                      ),
                      const SizedBox(height: GarageTokens.space4),
                      LabeledField(
                        label: l10n.vehicleSecondFuel,
                        child: DropdownButtonFormField<String?>(
                          key: const Key('vehicle-second-fuel'),
                          initialValue: _secondaryFuelTypeKey,
                          isExpanded: true,
                          items: [
                            DropdownMenuItem(
                              value: null,
                              child: Text(l10n.vehicleSecondFuelNone),
                            ),
                            for (final key in fuelTypeKeys)
                              if (key != _fuelTypeKey)
                                DropdownMenuItem(
                                  value: key,
                                  child: Text(fuelTypeLabel(l10n, key) ?? key),
                                ),
                          ],
                          onChanged: (value) =>
                              setState(() => _secondaryFuelTypeKey = value),
                        ),
                      ),
                      // Set like a field's own helper line, which is what the
                      // neighbouring pickers show theirs as.
                      Padding(
                        padding: const EdgeInsets.only(
                          left: GarageTokens.space4,
                          top: GarageTokens.space1,
                        ),
                        child: Text(
                          l10n.vehicleSecondFuelHint,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: context.tokens.muted),
                        ),
                      ),
                      const SizedBox(height: GarageTokens.space4),
                      LabeledField(
                        label: l10n.vehicleTimingDrive,
                        child: DropdownButtonFormField<String?>(
                          key: const Key('vehicle-timing-drive'),
                          initialValue: _timingDrive,
                          isExpanded: true,
                          decoration: InputDecoration(
                            // The one choice a person is likely to need help with,
                            // and the one whose wrong answer costs an engine.
                            helperText: l10n.vehicleTimingDriveHint,
                            helperMaxLines: 2,
                          ),
                          items: [
                            DropdownMenuItem(
                              value: null,
                              child: Text(l10n.vehicleTimingDriveNotSet),
                            ),
                            for (final key in timingDriveKeys)
                              DropdownMenuItem(
                                value: key,
                                child: Text(timingDriveLabel(l10n, key) ?? key),
                              ),
                          ],
                          onChanged: (value) =>
                              setState(() => _timingDrive = value),
                        ),
                      ),
                      const SizedBox(height: GarageTokens.space4),
                      LabeledField(
                        label: l10n.vehicleTransmission,
                        child: DropdownButtonFormField<String?>(
                          key: const Key('vehicle-transmission'),
                          initialValue: _transmission,
                          isExpanded: true,
                          items: [
                            DropdownMenuItem(
                              value: null,
                              child: Text(l10n.vehicleTransmissionNotSet),
                            ),
                            for (final key in transmissionKeys)
                              DropdownMenuItem(
                                value: key,
                                child: Text(
                                  transmissionLabel(l10n, key) ?? key,
                                ),
                              ),
                          ],
                          onChanged: (value) =>
                              setState(() => _transmission = value),
                        ),
                      ),
                      if (_kind == 'motorcycle') ...[
                        const SizedBox(height: GarageTokens.space4),
                        LabeledField(
                          label: l10n.vehicleFinalDrive,
                          child: DropdownButtonFormField<String?>(
                            key: const Key('vehicle-final-drive'),
                            initialValue: _finalDrive,
                            isExpanded: true,
                            items: [
                              DropdownMenuItem(
                                value: null,
                                child: Text(l10n.vehicleFinalDriveNotSet),
                              ),
                              for (final key in finalDriveKeys)
                                DropdownMenuItem(
                                  value: key,
                                  child: Text(
                                    finalDriveLabel(l10n, key) ?? key,
                                  ),
                                ),
                            ],
                            onChanged: (value) =>
                                setState(() => _finalDrive = value),
                          ),
                        ),
                      ],
                      const SizedBox(height: GarageTokens.space4),
                      LabeledField(
                        key: _vinAnchor,
                        label: l10n.vehicleVin,
                        child: TextFormField(
                          key: const Key('vehicle-vin'),
                          controller: _vin,
                          textCapitalization: TextCapitalization.characters,
                          // Without this the database's refusal reached the
                          // screen as "something went wrong".
                          validator: (value) => _vinAccepted(value ?? '')
                              ? null
                              : l10n.vehicleVinLength,
                          decoration: InputDecoration(
                            helperText: _vinMessage ?? l10n.vehicleVinHint,
                            suffixIcon: TextButton(
                              onPressed: _decoding ? null : _lookUpVin,
                              child: Text(l10n.vehicleDecodeVin),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: GarageTokens.space4),
                  _FormSection(
                    key: const Key('vehicle-section-optional'),
                    title: l10n.vehicleSectionOptional,
                    initiallyExpanded: _isEditing,
                    children: [
                      LabeledField(
                        label: l10n.vehicleTankCapacity,
                        child: TextFormField(
                          controller: _tankCapacity,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          style: GarageTheme.numericField(context),
                          decoration: InputDecoration(
                            helperText: l10n.vehicleTankCapacityHint,
                            suffixText: format.volumeSuffix,
                          ),
                        ),
                      ),
                      const SizedBox(height: GarageTokens.space4),
                      LabeledField(
                        label: l10n.vehiclePurchasePrice,
                        child: TextFormField(
                          key: const Key('vehicle-purchase-price'),
                          controller: _purchasePrice,
                          focusNode: _purchasePriceFocus,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          style: GarageTheme.numericField(context),
                          decoration: InputDecoration(
                            helperText: l10n.vehiclePurchasePriceHint,
                            suffixText: format.currencySymbol,
                          ),
                        ),
                      ),
                      // With its only field, inside the fold: above Save it
                      // was a blank band on a form that had the section shut.
                      AmountCalculatorDock(
                        fields: [
                          AmountField(_purchasePrice, _purchasePriceFocus),
                        ],
                        format: format,
                        reserve: false,
                      ),
                      const SizedBox(height: GarageTokens.space4),
                      if (existing != null) ...[
                        const SizedBox(height: GarageTokens.space4),
                        _PhotoField(
                          vehicle: existing,
                          busy: _uploadingPhoto,
                          hasPhoto:
                              !_photoRemoved &&
                              (_photoPath ?? existing.photoUrl) != null,
                          onPick: () => _pickPhoto(existing),
                          onRemove: () => _removePhoto(existing),
                        ),
                      ],
                    ],
                  ),
                  if (_failure != null) ...[
                    const SizedBox(height: GarageTokens.space4),
                    Text(
                      failureMessage(l10n, _failure!),
                      style: TextStyle(color: context.tokens.danger),
                    ),
                  ],
                  const SizedBox(height: GarageTokens.space6),
                  FilledButton(
                    onPressed: _busy ? null : () => _submit(existing),
                    child: BusyLabel(busy: _busy, child: Text(l10n.commonSave)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The vehicle's photo, with a button to set or replace it.
///
/// Shown only for a vehicle that exists: the storage path is keyed by vehicle
/// id, so there is nowhere to put a photo for one being created. Adding it
/// right after saving is one tap from here.
class _PhotoField extends ConsumerWidget {
  const _PhotoField({
    required this.vehicle,
    required this.busy,
    required this.hasPhoto,
    required this.onPick,
    required this.onRemove,
  });

  final Vehicle vehicle;
  final bool busy;
  final bool hasPhoto;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final url = hasPhoto
        ? ref.watch(vehiclePhotoUrlProvider(vehicle.id)).value
        : null;

    return LabeledField(
      label: l10n.vehiclePhoto,
      child: Row(
        children: [
          if (url != null)
            VehiclePhoto(
              vehicleId: vehicle.id,
              url: url,
              width: 96,
              height: 64,
              borderRadius: BorderRadius.circular(GarageTokens.radiusMd),
            ),
          if (url != null) const SizedBox(width: GarageTokens.space3),
          TextButton.icon(
            onPressed: busy ? null : onPick,
            icon: const Icon(Icons.photo_camera_outlined),
            label: Text(
              hasPhoto ? l10n.vehiclePhotoReplace : l10n.vehiclePhotoAdd,
            ),
          ),
          if (hasPhoto)
            IconButton(
              onPressed: busy ? null : onRemove,
              icon: const Icon(Icons.delete_outline),
              tooltip: l10n.vehiclePhotoRemove,
            ),
        ],
      ),
    );
  }
}

/// A group of fields behind a heading, collapsed on a new vehicle and open
/// when editing one. `maintainState` keeps the fields built while folded so
/// their validators still run on save and their values still round-trip.
class _FormSection extends StatelessWidget {
  const _FormSection({
    required this.title,
    required this.initiallyExpanded,
    required this.children,
    this.controller,
    super.key,
  });

  final String title;
  final bool initiallyExpanded;
  final ExpansibleController? controller;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      controller: controller,
      title: Text(title, style: Theme.of(context).textTheme.titleMedium),
      initiallyExpanded: initiallyExpanded,
      maintainState: true,
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(top: GarageTokens.space2),
      expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
      shape: const Border(),
      collapsedShape: const Border(),
      children: children,
    );
  }
}
