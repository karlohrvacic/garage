import '../../../core/widgets/unit_suffix.dart';
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

  /// Whose economy is in the box, when the screen filled it in: nothing on
  /// screen said where the figure came from.
  String? _economyFrom;

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

  double? _converted(
    TextEditingController controller,
    double Function(double) toCanonical,
  ) {
    final typed = _parse(controller);
    return typed == null ? null : toCanonical(typed);
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
    // The boxes are in the household's units; the data is canonical. A price
    // per litre becomes a price per gallon by the litres in one gallon, the
    // way the fill-up sheet already does it.
    final prefs = providers.read(unitPreferencesProvider);
    setState(() {
      if ((force || _consumption.text.isEmpty) && economy != null) {
        _consumption.text = prefs.economyToDisplay(economy).toStringAsFixed(1);
        _economyFrom = _vehicleId == null
            ? null
            : selected.firstOrNull?.nickname;
      } else if (force && economy == null) {
        // A car with no economy of its own kept the last car's figure and
        // presented it as its: a wrong answer, silently, on the one screen
        // whose whole job is a number.
        _consumption.clear();
        _economyFrom = null;
      }
      if (force && latestPrice == null) {
        // Same as the economy above: the previous car's price stayed in the
        // box with nothing saying whose it was.
        _price.clear();
      }
      if ((force || _price.text.isEmpty) && latestPrice != null) {
        _price.text = (latestPrice * prefs.displayToLiters(1)).toStringAsFixed(
          2,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final prefs = ref.watch(unitPreferencesProvider);
    final format = UnitFormat(
      locale: Localizations.localeOf(context).languageCode,
      preferences: prefs,
    );
    _applyRealData();

    // Typed in the household's units, computed in km and litres — the
    // results below were always converted on the way out, and until the
    // inputs were converted on the way in an imperial household got a screen
    // that contradicted itself.
    final distance = _converted(_distance, prefs.displayToKm);
    final price = _converted(_price, (v) => v / prefs.displayToLiters(1));
    final consumption = _converted(_consumption, prefs.displayToEconomy);
    final fuel = _converted(_fuel, prefs.displayToLiters);

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
                decoration: InputDecoration(
                  suffixIcon: unitSuffix(context, format.distanceSuffix),
                ),
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
                decoration: InputDecoration(
                  suffixIcon: unitSuffix(context, format.volumeSuffix),
                ),
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
                decoration: InputDecoration(
                  suffixIcon: unitSuffix(context, format.economySuffix),
                  // Nothing said where the number came from, so a figure
                  // borrowed from another car could not be caught.
                  helperText: switch (_economyFrom) {
                    null => null,
                    final name => l10n.calculatorFromCar(
                      name,
                      _consumption.text,
                    ),
                  },
                ),
                onChanged: (_) => setState(() {
                  _economyFrom = null;
                }),
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
                decoration: InputDecoration(
                  suffixIcon: unitSuffix(context, format.pricePerUnitSuffix()),
                ),
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
