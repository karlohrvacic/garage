import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/files/file_picker.dart';
import '../../../core/format/unit_format.dart';
import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../core/widgets/failure_message.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../domain/entities/vehicle.dart';
import '../../household/providers/household_providers.dart';
import '../../settings/providers/unit_providers.dart';
import '../fuel_type_labels.dart';
import '../providers/vehicle_providers.dart';

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
  final _nickname = TextEditingController();
  final _make = TextEditingController();
  final _model = TextEditingController();
  final _year = TextEditingController();
  final _plate = TextEditingController();
  final _vin = TextEditingController();
  final _odometer = TextEditingController();
  final _tankCapacity = TextEditingController();

  String _fuelTypeKey = 'fuel_petrol';
  String? _secondaryFuelTypeKey;
  String? _decodedTrim;

  /// The photo path once one has been uploaded in this session, so saving
  /// records it. A vehicle keeps whatever it already had until then.
  String? _photoPath;
  bool _uploadingPhoto = false;
  bool _busy = false;
  bool _prefilled = false;
  bool _decoding = false;
  String? _vinMessage;
  AppFailure? _failure;

  bool get _isEditing => widget.vehicleId != null;

  @override
  void dispose() {
    _nickname.dispose();
    _make.dispose();
    _model.dispose();
    _year.dispose();
    _plate.dispose();
    _vin.dispose();
    _odometer.dispose();
    _tankCapacity.dispose();
    super.dispose();
  }

  void _prefill(Vehicle vehicle, UnitPreferences prefs) {
    if (_prefilled) {
      return;
    }
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
    _fuelTypeKey = vehicle.fuelTypeKey;
    _secondaryFuelTypeKey = vehicle.secondaryFuelTypeKey;
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
    setState(() {
      _uploadingPhoto = true;
      _failure = null;
    });
    try {
      final path = await ref
          .read(vehiclePhotoRepositoryProvider)
          .upload(
            householdId: vehicle.householdId,
            vehicleId: vehicle.id,
            bytes: await file.readAsBytes(),
            contentType: file.mimeType,
          );
      ref.invalidate(vehiclePhotoUrlProvider(vehicle.id));
      if (mounted) {
        setState(() => _photoPath = path);
      }
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

  Future<void> _submit(Vehicle? existing) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final household = ref.read(currentHouseholdProvider).value;
    if (household == null) {
      return;
    }

    setState(() {
      _busy = true;
      _failure = null;
    });

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
            baselineOdometerKm: odometer,
            baselineDate: existing.baselineDate,
            make: _emptyToNull(_make.text),
            model: _emptyToNull(_model.text),
            year: int.tryParse(_year.text.trim()),
            trim: _decodedTrim ?? existing.trim,
            plate: _emptyToNull(_plate.text),
            vin: _emptyToNull(_vin.text),
            photoUrl: _photoPath ?? existing.photoUrl,
            tankCapacityL: _tankCapacityLiters(prefs),
            archived: existing.archived,
          ),
        );
      }
      ref.invalidate(allVehiclesProvider);
      if (mounted) {
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

    final existing = _isEditing
        ? ref.watch(vehicleProvider(widget.vehicleId!)).value
        : null;
    if (existing != null) {
      _prefill(existing, prefs);
    }

    return GaragePageScaffold(
      title: _isEditing ? l10n.vehicleEdit : l10n.vehiclesAdd,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(GarageTokens.space4),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LabeledField(
                  label: l10n.vehicleNickname,
                  child: TextFormField(
                    controller: _nickname,
                    validator: (value) =>
                        (value != null && value.trim().isNotEmpty)
                        ? null
                        : l10n.vehicleNameRequired,
                  ),
                ),
                const SizedBox(height: GarageTokens.space4),
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
                Padding(
                  padding: const EdgeInsets.only(top: GarageTokens.space1),
                  child: Text(
                    l10n.vehicleSecondFuelHint,
                    style: TextStyle(color: context.tokens.muted),
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
                if (existing != null) ...[
                  const SizedBox(height: GarageTokens.space4),
                  _PhotoField(
                    vehicle: existing,
                    busy: _uploadingPhoto,
                    hasPhoto: (_photoPath ?? existing.photoUrl) != null,
                    onPick: () => _pickPhoto(existing),
                  ),
                ],
                const SizedBox(height: GarageTokens.space4),
                LabeledField(
                  label: l10n.vehiclePlate,
                  child: TextFormField(controller: _plate),
                ),
                const SizedBox(height: GarageTokens.space4),
                LabeledField(
                  label: l10n.vehicleVin,
                  child: TextFormField(
                    controller: _vin,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      helperText: _vinMessage,
                      suffixIcon: TextButton(
                        onPressed: _decoding ? null : _lookUpVin,
                        child: Text(l10n.vehicleDecodeVin),
                      ),
                    ),
                  ),
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
                      suffixText: prefs.distance == DistanceUnit.km
                          ? 'km'
                          : 'mi',
                    ),
                  ),
                ),
                const SizedBox(height: GarageTokens.space4),
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
                      suffixText: prefs.volume == VolumeUnit.liter
                          ? 'l'
                          : 'gal',
                    ),
                  ),
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
                  child: Text(l10n.commonSave),
                ),
              ],
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
  });

  final Vehicle vehicle;
  final bool busy;
  final bool hasPhoto;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final url = ref.watch(vehiclePhotoUrlProvider(vehicle.id)).value;

    return LabeledField(
      label: l10n.vehiclePhoto,
      child: Row(
        children: [
          if (url != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(GarageTokens.radiusMd),
              child: Image.network(
                url.toString(),
                width: 96,
                height: 64,
                fit: BoxFit.cover,
                // A signed link that has expired, or a device that is offline,
                // should leave the form usable rather than throwing into it.
                errorBuilder: (context, _, _) => Icon(
                  Icons.directions_car_outlined,
                  color: context.tokens.muted,
                ),
              ),
            ),
          if (url != null) const SizedBox(width: GarageTokens.space3),
          TextButton.icon(
            onPressed: busy ? null : onPick,
            icon: const Icon(Icons.photo_camera_outlined),
            label: Text(
              hasPhoto ? l10n.vehiclePhotoReplace : l10n.vehiclePhotoAdd,
            ),
          ),
        ],
      ),
    );
  }
}
