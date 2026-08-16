import '../entities/cost_entry.dart';
import '../entities/fuel_entry.dart';
import '../entities/reminder_rule.dart';
import '../entities/service_entry.dart';
import '../entities/vehicle.dart';

/// A year of plausible history for one car.
///
/// An empty app cannot demonstrate itself: every screen is an empty state, and
/// economy, projections and running cost all need history before they mean
/// anything. This is what "show me what it does" loads, and Settings' delete-all
/// is what removes it again.
///
/// Deterministic on purpose. A demo that differs between runs is a demo nobody
/// can talk about, and randomness would occasionally produce a car that never
/// fills up in winter.
class SampleGarage {
  const SampleGarage({
    required this.vehicle,
    required this.fuel,
    required this.services,
    required this.costs,
    required this.rules,
  });

  final Vehicle vehicle;
  final List<FuelEntry> fuel;
  final List<ServiceEntry> services;
  final List<CostEntry> costs;
  final List<ReminderRule> rules;

  /// Twelve fill-ups over the year ending at [today], with the servicing and
  /// running costs a car that age would really have had.
  static SampleGarage build({
    required DateTime today,
    String householdId = '',
    String vehicleId = '',
  }) {
    final start = DateTime.utc(today.year - 1, today.month, today.day);
    const startOdometer = 42000;

    final fuel = <FuelEntry>[];
    // Roughly monthly fills, 550 to 700 km apart, with prices that move a
    // little: a flat series would make every chart a straight line.
    const distances = [
      640,
      585,
      700,
      610,
      655,
      590,
      680,
      620,
      705,
      600,
      665,
      630,
    ];
    const prices = [
      1.52,
      1.49,
      1.55,
      1.61,
      1.58,
      1.47,
      1.44,
      1.51,
      1.57,
      1.62,
      1.59,
      1.54,
    ];
    const litres = [
      38.4,
      35.1,
      42.0,
      36.6,
      39.3,
      35.4,
      40.8,
      37.2,
      42.3,
      36.0,
      39.9,
      37.8,
    ];

    var odometer = startOdometer;
    for (var i = 0; i < distances.length; i++) {
      odometer += distances[i];
      final date = DateTime.utc(start.year, start.month + i, start.day);
      fuel.add(
        FuelEntry(
          id: '',
          vehicleId: vehicleId,
          date: date,
          odometerKm: odometer,
          volumeL: litres[i],
          pricePerL: prices[i],
          total: double.parse((litres[i] * prices[i]).toStringAsFixed(2)),
          // One partial fill, so the full-tank algorithm has something to
          // demonstrate rather than a uniform series.
          fullTank: i != 6,
          missedFill: false,
          station: i.isEven ? 'INA' : 'Petrol',
          createdBy: '',
        ),
      );
    }

    final services = [
      ServiceEntry(
        id: '',
        vehicleId: vehicleId,
        date: DateTime.utc(start.year, start.month + 2, start.day),
        odometerKm: startOdometer + 1900,
        serviceTypeKeys: const ['service_oil_change', 'service_oil_filter'],
        cost: 128.40,
        shop: 'Auto Kovač',
        createdBy: '',
      ),
      ServiceEntry(
        id: '',
        vehicleId: vehicleId,
        date: DateTime.utc(start.year, start.month + 8, start.day),
        odometerKm: startOdometer + 5400,
        serviceTypeKeys: const ['service_brake_pads_front'],
        cost: 210.00,
        shop: 'Auto Kovač',
        createdBy: '',
      ),
    ];

    final costs = [
      CostEntry(
        id: '',
        vehicleId: vehicleId,
        date: DateTime.utc(start.year, start.month + 1, start.day),
        category: CostCategories.registration,
        amount: 167.52,
        createdBy: '',
      ),
      CostEntry(
        id: '',
        vehicleId: vehicleId,
        date: DateTime.utc(start.year, start.month + 1, start.day),
        category: CostCategories.insurance,
        amount: 260.00,
        createdBy: '',
      ),
      CostEntry(
        id: '',
        vehicleId: vehicleId,
        date: DateTime.utc(start.year, start.month + 5, start.day),
        category: CostCategories.wash,
        amount: 12.00,
        createdBy: '',
      ),
    ];

    final rules = [
      ReminderRule(
        id: '',
        vehicleId: vehicleId,
        serviceTypeKey: 'service_oil_change',
        intervalKm: 15000,
        intervalMonths: 12,
      ),
      ReminderRule(
        id: '',
        vehicleId: vehicleId,
        serviceTypeKey: 'service_technical_inspection',
        intervalMonths: 12,
      ),
    ];

    return SampleGarage(
      vehicle: Vehicle(
        id: vehicleId,
        householdId: householdId,
        nickname: 'Renault Clio',
        fuelTypeKey: 'fuel_diesel',
        make: 'Renault',
        model: 'Clio',
        year: 2019,
        // Tracking starts before the first fill-up, or the history would
        // predate the car.
        baselineOdometerKm: startOdometer,
        baselineDate: start,
        tankCapacityL: 45,
      ),
      fuel: fuel,
      services: services,
      costs: costs,
      rules: rules,
    );
  }
}
