import '../entities/cost_entry.dart';
import '../entities/fuel_entry.dart';
import '../entities/income_entry.dart';
import '../entities/odometer_entry.dart';
import '../entities/reminder_rule.dart';
import '../entities/service_entry.dart';
import '../entities/trip_entry.dart';
import '../entities/vehicle.dart';

/// The car the sample garage adds.
///
/// Named here rather than written inline because the confirmation has to say
/// it out loud: the people this app was built for own Renault Clios, so
/// somebody who loads the sample by accident ends up with two cars of the same
/// name and no way to tell which is theirs.
const sampleVehicleName = 'Renault Clio';

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
    required this.trips,
    required this.income,
    required this.readings,
  });

  final Vehicle vehicle;
  final List<FuelEntry> fuel;
  final List<ServiceEntry> services;
  final List<CostEntry> costs;
  final List<ReminderRule> rules;

  /// A handful of each of the newer kinds. Without them the trip log, the
  /// balance figure and the odometer chart are empty states on a garage that is
  /// meant to demonstrate the app.
  final List<TripEntry> trips;
  final List<IncomeEntry> income;
  final List<OdometerEntry> readings;

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
    // Volumes chosen so consumption lands between about 5.4 and 6.6 l/100km
    // rather than on one figure. These were each distance times a flat 0.06,
    // which made every span exactly 6.0: a flat chart, a ring with nothing to
    // scale against, and "Best 6.0 · Worst 6.0" on the car's own summary.
    const litres = [
      35.8,
      35.7,
      41.3,
      39.0,
      42.6,
      38.9,
      42.8,
      37.2,
      40.2,
      32.4,
      38.6,
      39.1,
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
          // Brands rather than fuels: "Petrol" is a real chain, but in the
          // field labelled Station it reads as a fuel type in the wrong box.
          station: i.isEven ? 'INA' : 'Tifon',
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

    // A few journeys worth logging, split the way a logbook is: two runs to
    // the coast for work and one family weekend. Dated between fill-ups so the
    // trip log and the fill-up log tell the same story.
    final trips = [
      TripEntry(
        id: '',
        vehicleId: vehicleId,
        date: DateTime.utc(start.year, start.month + 3, start.day + 4),
        distanceKm: 188,
        purpose: TripPurpose.business,
        title: 'Split — client',
        fromPlace: 'Zagreb',
        toPlace: 'Split',
        minutes: 235,
        createdBy: '',
      ),
      TripEntry(
        id: '',
        vehicleId: vehicleId,
        date: DateTime.utc(start.year, start.month + 6, start.day + 2),
        distanceKm: 96,
        purpose: TripPurpose.private,
        title: 'Plitvice',
        fromPlace: 'Zagreb',
        toPlace: 'Plitvička jezera',
        minutes: 105,
        createdBy: '',
      ),
      TripEntry(
        id: '',
        vehicleId: vehicleId,
        date: DateTime.utc(start.year, start.month + 9, start.day + 1),
        distanceKm: 188,
        purpose: TripPurpose.business,
        title: 'Split — follow-up',
        fromPlace: 'Zagreb',
        toPlace: 'Split',
        minutes: 228,
        createdBy: '',
      ),
    ];

    // Money in, so the balance figure is something other than the cost total
    // with a minus sign in front of it.
    final income = [
      IncomeEntry(
        id: '',
        vehicleId: vehicleId,
        date: DateTime.utc(start.year, start.month + 3, start.day + 4),
        category: IncomeCategories.ride,
        amount: 40.00,
        createdBy: '',
      ),
      IncomeEntry(
        id: '',
        vehicleId: vehicleId,
        date: DateTime.utc(start.year, start.month + 7, start.day),
        category: IncomeCategories.refund,
        amount: 85.30,
        createdBy: '',
      ),
    ];

    // One reading between two fills, taken on a day nothing was bought. Its
    // odometer sits between the fills that bracket it, or the merged series
    // would drop it as a reading that goes backwards and the demo would be
    // missing the very point it is making.
    final readings = [
      OdometerEntry(
        id: '',
        vehicleId: vehicleId,
        date: DateTime.utc(start.year, start.month + 4, start.day + 10),
        odometerKm:
            startOdometer + distances.take(5).reduce((a, b) => a + b) + 120,
        createdBy: '',
      ),
    ];

    return SampleGarage(
      vehicle: Vehicle(
        id: vehicleId,
        householdId: householdId,
        nickname: sampleVehicleName,
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
      trips: trips,
      income: income,
      readings: readings,
    );
  }
}
