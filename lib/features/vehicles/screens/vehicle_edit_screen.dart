import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/format/unit_format.dart';
import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../core/widgets/failure_message.dart';
import '../../../domain/entities/vehicle.dart';
import '../../household/providers/household_providers.dart';
import '../../settings/providers/unit_providers.dart';
import '../providers/vehicle_providers.dart';

/// The language-neutral fuel-type keys stored on the vehicle. Labels come from
/// the ARB at display time.
const _fuelTypeKeys = [
  'fuel_petrol',
  'fuel_diesel',
  'fuel_lpg',
  'fuel_electric',
  'fuel_hybrid',
];

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

  String _fuelTypeKey = 'fuel_petrol';
  bool _busy = false;
  bool _prefilled = false;
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
    _fuelTypeKey = vehicle.fuelTypeKey;
  }

  String? _fuelLabel(AppLocalizations l10n, String key) {
    return switch (key) {
      'fuel_petrol' => l10n.fuelPetrol,
      'fuel_diesel' => l10n.fuelDiesel,
      'fuel_lpg' => l10n.fuelLpg,
      'fuel_electric' => l10n.fuelElectric,
      'fuel_hybrid' => l10n.fuelHybrid,
      _ => null,
    };
  }

  String? _emptyToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
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
          ),
        );
      } else {
        await repository.update(
          Vehicle(
            id: existing.id,
            householdId: existing.householdId,
            nickname: _nickname.text.trim(),
            fuelTypeKey: _fuelTypeKey,
            baselineOdometerKm: odometer,
            baselineDate: existing.baselineDate,
            make: _emptyToNull(_make.text),
            model: _emptyToNull(_model.text),
            year: int.tryParse(_year.text.trim()),
            trim: existing.trim,
            plate: _emptyToNull(_plate.text),
            vin: _emptyToNull(_vin.text),
            photoUrl: existing.photoUrl,
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

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? l10n.vehicleEdit : l10n.vehiclesAdd),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(GarageTokens.space4),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nickname,
                  decoration: InputDecoration(labelText: l10n.vehicleNickname),
                  validator: (value) =>
                      (value != null && value.trim().isNotEmpty)
                          ? null
                          : l10n.vehicleNameRequired,
                ),
                const SizedBox(height: GarageTokens.space4),
                DropdownButtonFormField<String>(
                  initialValue: _fuelTypeKey,
                  decoration: InputDecoration(labelText: l10n.vehicleFuelType),
                  items: [
                    for (final key in _fuelTypeKeys)
                      DropdownMenuItem(
                        value: key,
                        child: Text(_fuelLabel(l10n, key) ?? key),
                      ),
                  ],
                  onChanged: (value) =>
                      setState(() => _fuelTypeKey = value ?? _fuelTypeKey),
                ),
                const SizedBox(height: GarageTokens.space4),
                TextFormField(
                  controller: _make,
                  decoration: InputDecoration(labelText: l10n.vehicleMake),
                ),
                const SizedBox(height: GarageTokens.space4),
                TextFormField(
                  controller: _model,
                  decoration: InputDecoration(labelText: l10n.vehicleModel),
                ),
                const SizedBox(height: GarageTokens.space4),
                TextFormField(
                  controller: _year,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: l10n.vehicleYear),
                ),
                const SizedBox(height: GarageTokens.space4),
                TextFormField(
                  controller: _plate,
                  decoration: InputDecoration(labelText: l10n.vehiclePlate),
                ),
                const SizedBox(height: GarageTokens.space4),
                TextFormField(
                  controller: _vin,
                  decoration: InputDecoration(labelText: l10n.vehicleVin),
                ),
                const SizedBox(height: GarageTokens.space4),
                TextFormField(
                  controller: _odometer,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.vehicleOdometer,
                    // Name the unit so the value is entered in the household's
                    // distance unit, matching how it round-trips.
                    suffixText: prefs.distance == DistanceUnit.km ? 'km' : 'mi',
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
