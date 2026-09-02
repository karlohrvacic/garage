import '../entities/vehicle.dart';
import 'make_intervals.dart';
import 'make_key.dart';

/// Where a default came from, so the sheet can say so.
enum IntervalSource { generic, make, drivetrain, fuel }

/// A remark the sheet localises under the interval fields.
enum IntervalNote {
  chain,
  wetBelt,
  setTimingDrive,
  setTransmission,
  sealed,
  advisory,
}

class IntervalDefault {
  const IntervalDefault({
    required this.km,
    required this.months,
    required this.source,
    this.note,
  });

  final int? km;
  final int? months;
  final IntervalSource source;
  final IntervalNote? note;
}

/// The interval a fresh rule should start from.
///
/// Order, first match wins: the drivetrain (belt and gearbox oil vary by
/// engine, not make), the fuel (a fuel filter is a diesel thing), the make
/// overlay, then the type's own preset — which is what every rule started
/// from before this existed. Every result is a prefilled number the person
/// can overwrite.
class IntervalDefaults {
  IntervalDefaults._();

  static const _timingTypes = {'service_timing_belt', 'service_water_pump'};
  static const _gearboxTypes = {'service_transmission_oil'};
  static const _fuelTypes = {'service_fuel_filter'};

  static IntervalDefault resolve({
    required String serviceTypeKey,
    required int? presetKm,
    required int? presetMonths,
    required Vehicle vehicle,
  }) {
    final generic = IntervalDefault(
      km: presetKm,
      months: presetMonths,
      source: IntervalSource.generic,
    );

    if (_timingTypes.contains(serviceTypeKey)) {
      return switch (vehicle.timingDrive) {
        'chain' => const IntervalDefault(
          km: null,
          months: null,
          source: IntervalSource.drivetrain,
          note: IntervalNote.chain,
        ),
        'wet_belt' => const IntervalDefault(
          km: 100000,
          months: 72,
          source: IntervalSource.drivetrain,
          note: IntervalNote.wetBelt,
        ),
        'belt' => generic,
        _ => IntervalDefault(
          km: presetKm,
          months: presetMonths,
          source: IntervalSource.generic,
          note: IntervalNote.setTimingDrive,
        ),
      };
    }

    if (_gearboxTypes.contains(serviceTypeKey)) {
      return switch (vehicle.transmission) {
        'manual' => const IntervalDefault(
          km: 90000,
          months: 72,
          source: IntervalSource.drivetrain,
          note: IntervalNote.advisory,
        ),
        'automatic' => const IntervalDefault(
          km: 60000,
          months: 48,
          source: IntervalSource.drivetrain,
          note: IntervalNote.advisory,
        ),
        'dct_dry' => const IntervalDefault(
          km: null,
          months: null,
          source: IntervalSource.drivetrain,
          note: IntervalNote.sealed,
        ),
        'dct_wet' => const IntervalDefault(
          km: 60000,
          months: 48,
          source: IntervalSource.drivetrain,
        ),
        'cvt' => const IntervalDefault(
          km: 60000,
          months: 48,
          source: IntervalSource.drivetrain,
          note: IntervalNote.advisory,
        ),
        _ => IntervalDefault(
          km: presetKm,
          months: presetMonths,
          source: IntervalSource.generic,
          note: IntervalNote.setTransmission,
        ),
      };
    }

    if (_fuelTypes.contains(serviceTypeKey)) {
      return switch (vehicle.fuelTypeKey) {
        'fuel_diesel' => const IntervalDefault(
          km: 40000,
          months: 48,
          source: IntervalSource.fuel,
        ),
        'fuel_electric' => const IntervalDefault(
          km: null,
          months: null,
          source: IntervalSource.fuel,
        ),
        _ => const IntervalDefault(
          km: 90000,
          months: null,
          source: IntervalSource.fuel,
          note: IntervalNote.advisory,
        ),
      };
    }

    // The oil filter is changed with the oil; one row serves both.
    final overlayKey = serviceTypeKey == 'service_oil_filter'
        ? 'service_oil_change'
        : serviceTypeKey;
    final make = MakeKey.of(vehicle.make);
    if (make != null) {
      for (final row in makeIntervals) {
        if (row.make == make && row.serviceTypeKey == overlayKey) {
          return IntervalDefault(
            km: row.km ?? presetKm,
            months: row.months ?? presetMonths,
            source: IntervalSource.make,
          );
        }
      }
    }
    return generic;
  }
}
