import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';

import '../../../core/format/unit_format.dart';
import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../core/widgets/cluster_readout.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../domain/fuel/trip_math.dart';
import '../../dashboard/providers/dashboard_providers.dart';
import '../../fuel/providers/fuel_providers.dart';
import '../../settings/providers/unit_providers.dart';
import '../../vehicles/providers/vehicle_providers.dart';
import '../../vehicles/vehicle_choice.dart';

enum _CalcMode { tripCost, distance, consumption, requiredFuel }

class CalculatorScreen extends ConsumerStatefulWidget {
  const CalculatorScreen({super.key});

  @override
  ConsumerState<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends ConsumerState<CalculatorScreen> {
  final _distance = TextEditingController();
  final _price = TextEditingController();
  final _consumption = TextEditingController();
  final _fuel = TextEditingController();

  _CalcMode _mode = _CalcMode.tripCost;
  String? _vehicleId;
  bool _prefilled = false;

  @override
  void dispose() {
    _distance.dispose();
    _price.dispose();
    _consumption.dispose();
    _fuel.dispose();
    super.dispose();
  }

  double? _parse(TextEditingController controller) {
    final normalized = controller.text.trim().replaceAll(',', '.');
    if (normalized.isEmpty) {
      return null;
    }
    return double.tryParse(normalized);
  }

  /// Seeds price and consumption from real data: the whole fleet's when no
  /// vehicle is picked, one vehicle's own averages when it is. Values land in
  /// the text fields, so they stay fully editable as custom what-ifs.
  Future<void> _applyRealData({bool force = false}) async {
    if (_prefilled && !force) {
      return;
    }
    _prefilled = true;
    // Read through the container rather than `ref`. This walks a chain of
    // awaits — a fleet's worth of fuel logs on a slow connection — and `ref`
    // belongs to the element, which is gone the moment the user leaves the
    // screen mid-prefill. The `mounted` check below is what stops the result
    // being applied to a screen that is no longer there.
    final providers = ProviderScope.containerOf(context, listen: false);
    final vehicles = await providers.read(vehiclesProvider.future);
    final selected = _vehicleId == null
        ? vehicles
        : vehicles.where((v) => v.id == _vehicleId).toList(growable: false);

    final economy = _vehicleId == null
        ? await providers.read(fleetAverageEconomyProvider.future)
        : await providers.read(averageEconomyProvider(_vehicleId!).future);

    double? latestPrice;
    DateTime? latestDate;
    for (final vehicle in selected) {
      final entries = await providers.read(
        rawFuelEntriesProvider(vehicle.id).future,
      );
      for (final entry in entries) {
        if (entry.pricePerL != null &&
            (latestDate == null || entry.date.isAfter(latestDate))) {
          latestDate = entry.date;
          latestPrice = entry.pricePerL;
        }
      }
    }
    if (!mounted) {
      return;
    }
    setState(() {
      if ((force || _consumption.text.isEmpty) && economy != null) {
        _consumption.text = economy.toStringAsFixed(1);
      }
      if ((force || _price.text.isEmpty) && latestPrice != null) {
        _price.text = latestPrice.toStringAsFixed(2);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final format = UnitFormat(
      locale: Localizations.localeOf(context).languageCode,
      preferences: ref.watch(unitPreferencesProvider),
    );
    _applyRealData();

    final distance = _parse(_distance);
    final price = _parse(_price);
    final consumption = _parse(_consumption);
    final fuel = _parse(_fuel);

    final (String label, String? value) = switch (_mode) {
      _CalcMode.tripCost => (
        l10n.calcModeTripCost,
        switch (TripMath.tripCost(
          distanceKm: distance,
          litersPer100Km: consumption,
          pricePerLiter: price,
        )) {
          null => null,
          final cost => format.formatMoney(cost),
        },
      ),
      _CalcMode.distance => (
        l10n.calcModeDistance,
        switch (TripMath.reachableDistance(
          fuelLiters: fuel,
          litersPer100Km: consumption,
        )) {
          null => null,
          final km => format.formatDistance(km, decimals: 0),
        },
      ),
      _CalcMode.consumption => (
        l10n.calcModeConsumption,
        switch (TripMath.consumption(distanceKm: distance, fuelLiters: fuel)) {
          null => null,
          final economy => format.formatEconomy(economy),
        },
      ),
      _CalcMode.requiredFuel => (
        l10n.calcModeRequiredFuel,
        switch (TripMath.requiredFuel(
          distanceKm: distance,
          litersPer100Km: consumption,
        )) {
          null => null,
          final liters => format.formatVolume(liters),
        },
      ),
    };

    final needsDistance = _mode != _CalcMode.distance;
    final needsFuel =
        _mode == _CalcMode.distance || _mode == _CalcMode.consumption;
    final needsConsumption = _mode != _CalcMode.consumption;
    final needsPrice = _mode == _CalcMode.tripCost;

    final vehicles = ref.watch(vehiclesProvider).value ?? const [];
    final chosen = chosenVehicleId(vehicles, _vehicleId);

    return GaragePageScaffold(
      title: l10n.calculatorTitle,
      body: ListView(
        padding: const EdgeInsets.all(GarageTokens.space4),
        children: [
          LabeledField(
            // The field's name, not its default option's: this read
            // "All vehicles" above a box already saying "All vehicles".
            label: l10n.commonVehicle,
            child: DropdownButtonFormField<String?>(
              initialValue: chosen,
              isExpanded: true,
              items: [
                DropdownMenuItem(
                  value: null,
                  child: Text(l10n.statsAllVehicles),
                ),
                for (final vehicle in vehicles)
                  DropdownMenuItem(
                    value: vehicle.id,
                    child: Text(vehicle.nickname),
                  ),
              ],
              onChanged: (value) {
                setState(() => _vehicleId = value);
                _applyRealData(force: true);
              },
            ),
          ),
          const SizedBox(height: GarageTokens.space3),
          LabeledField(
            label: l10n.calcResult,
            child: DropdownButtonFormField<_CalcMode>(
              initialValue: _mode,
              isExpanded: true,
              items: [
                DropdownMenuItem(
                  value: _CalcMode.tripCost,
                  child: Text(l10n.calcModeTripCost),
                ),
                DropdownMenuItem(
                  value: _CalcMode.distance,
                  child: Text(l10n.calcModeDistance),
                ),
                DropdownMenuItem(
                  value: _CalcMode.consumption,
                  child: Text(l10n.calcModeConsumption),
                ),
                DropdownMenuItem(
                  value: _CalcMode.requiredFuel,
                  child: Text(l10n.calcModeRequiredFuel),
                ),
              ],
              onChanged: (mode) => setState(() => _mode = mode ?? _mode),
            ),
          ),
          const SizedBox(height: GarageTokens.space4),
          if (needsDistance) ...[
            LabeledField(
              label: l10n.calcModeDistance,
              child: TextField(
                controller: _distance,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: GarageTheme.numericField(context),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(height: GarageTokens.space3),
          ],
          if (needsFuel) ...[
            LabeledField(
              // The same box, two opposite meanings: in distance mode it is
              // what is still in the tank, in consumption mode it is what has
              // already gone. It borrowed the fill-up sheet's "Volume", where
              // the surrounding form supplies the context this screen has
              // none of — leaving a lone box asking for a quantity of nothing
              // in particular.
              label: _mode == _CalcMode.distance
                  ? l10n.calcFuelAvailable
                  : l10n.calcFuelUsed,
              child: TextField(
                controller: _fuel,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: GarageTheme.numericField(context),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(height: GarageTokens.space3),
          ],
          if (needsConsumption) ...[
            LabeledField(
              label: l10n.calcConsumption,
              child: TextField(
                controller: _consumption,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: GarageTheme.numericField(context),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(height: GarageTokens.space3),
          ],
          if (needsPrice) ...[
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
          ],
          const SizedBox(height: GarageTokens.space3),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(GarageTokens.space5),
              child: ClusterReadout(
                label: label,
                value: value ?? UnitFormat.emptyValue,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
