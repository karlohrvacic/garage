import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/entities/cost_entry.dart';
import 'package:garage/domain/import/fuelio_backup.dart';

/// Trimmed from a real Fuelio 9.x export: datetimes in the Log, `Date`/`Odo`
/// headers in Costs, reminders and services interleaved with expenses.
const _fixture = '''
"## Vehicle"
"Name","Description","DistUnit","FuelUnit","ConsumptionUnit","ImportCSVDateFormat","VIN","Insurance","Plate","Make","Model","Year"
"Renault Clio","Description","0","0","0","yyyy-MM-dd","","","ZG1234AB","Renault","Clio","2022"
"## Log"
"Data","Odo (km)","Fuel (litres)","Full","Price (optional)","l/100km (optional)","latitude (optional)","longitude (optional)","City (optional)","Notes (optional)","Missed","TankNumber","FuelType","VolumePrice","StationID (optional)","ExcludeDistance","UniqueId","TankCalc","Weather","guid","lastupdated"
"2026-07-25 14:58","46818.0","34.578","1","53.25","6.07","0.0","0.0",,"","0","1","110","1.54","0","0.0","45","0.0",,"b999ff9e","1785246200802"
"2026-07-13 07:06","46248.0","35.162","1","54.15","5.78","0.0","0.0",,"Discount: 1,25 €","1","1","110","1.54","0","0.0","44","0.0",,"bc36e12b","1785246200803"
"## CostCategories"
"CostTypeID","Name","priority","color","guid","lastupdated"
"1","Service","0","","28c6eff3","1785249607209"
"4","Registration","0","","1f9ebc1d","1785249607209"
"31","Insurance","0","","ca6431f2","1785249607209"
"## Costs"
"CostTitle","Date","Odo","CostTypeID","Notes","Cost","flag","idR","read","RemindOdo","RemindDate","isTemplate","RepeatOdo","RepeatMonths","isIncome","UniqueId","guid","lastupdated"
"Zamjena svjećica","2030-07-27","0","1","","0.0","0","0","0","107006","2030-07-27","0","60000","48","0","23","b7ac4fdf","1785187185421"
"Servis","2026-07-27 23:07","47006","1","Ulje, filteri, svijecice","200.0","0","0","1","0","2011-01-01","0","0","0","0","28","e83c91a5","1785186469566"
"Registracija","2026-05-20 17:32","0","4","","167.52","0","0","1","0","2011-01-01","0","0","0","0","26","6ec01f43","1779291194137"
"Osiguranje","2026-05-19 17:33","0","31","","260.0","0","0","1","0","2011-01-01","0","0","0","0","27","3ca75028","1779291208954"
"Gume Prednje","2025-11-03 13:43","29647","1","","27.5","0","0","0","99649","2030-11-04","0","0","0","0","14","00608659","1785249607209"
"Refund","2026-05-11","0","4","","50.0","0","0","1","0","2011-01-01","0","0","0","1","29","aa","1"
"## TripLog"
"title","StartName"
"Test","dfg"
''';

void main() {
  group('the vehicle in a backup', () {
    test('is read, because it is how a Fuelio user gets their first car', () {
      final vehicle = parseFuelioBackup(_fixture).vehicle;

      expect(vehicle, isNotNull);
      expect(vehicle!.name, 'Renault Clio');
      expect(vehicle.make, 'Renault');
      expect(vehicle.model, 'Clio');
      expect(vehicle.year, 2022);
      expect(vehicle.plate, 'ZG1234AB');
    });

    test('leaves blank columns empty rather than storing ""', () {
      final vehicle = parseFuelioBackup(_fixture).vehicle;

      expect(vehicle!.vin, isNull, reason: 'the export had no VIN');
    });

    test('is null when the export has no vehicle section', () {
      const noVehicle = '''
"## Log"
"Data","Odo (km)","Fuel (litres)","Full"
"2026-07-25 14:58","46818.0","34.578","1"
''';

      expect(parseFuelioBackup(noVehicle).vehicle, isNull);
    });
  });

  final now = DateTime.utc(2026, 7, 28);

  test('parses fill-ups with datetimes and zero-price normalisation', () {
    final backup = parseFuelioBackup(_fixture, now: now);

    expect(backup.fillUps, hasLength(2));
    final first = backup.fillUps.first;
    expect(first.date, DateTime.utc(2026, 7, 25));
    expect(first.odometerKm, 46818);
    expect(first.volumeL, closeTo(34.578, 0.001));
    expect(first.total, closeTo(53.25, 0.001));
    expect(first.pricePerL, closeTo(1.54, 0.001));
    expect(backup.fillUps[1].missedFill, isTrue);
    expect(backup.fillUps[1].notes, 'Discount: 1,25 €');
  });

  test('splits the Costs section into expenses, services, and reminders', () {
    final backup = parseFuelioBackup(_fixture, now: now);

    // A recurring reminder (RepeatOdo/RepeatMonths) plus a one-off pinned on
    // the tyre row's RemindDate/RemindOdo.
    expect(backup.reminders, hasLength(2));
    final recurring = backup.reminders.first;
    expect(recurring.serviceTypeKey, 'service_spark_plugs');
    expect(recurring.repeatKm, 60000);
    expect(recurring.repeatMonths, 48);
    expect(recurring.isRecurring, isTrue);
    final oneOff = backup.reminders[1];
    expect(oneOff.isRecurring, isFalse);
    expect(oneOff.serviceTypeKey, 'service_tire_swap_seasonal');
    expect(oneOff.dueDate, DateTime.utc(2030, 11, 4));
    expect(oneOff.dueOdometerKm, 99649);

    // Service-category rows with an odometer become services.
    expect(backup.services, hasLength(2));
    expect(backup.services.first.serviceTypeKey, 'service_oil_change');
    expect(backup.services.first.cost, closeTo(200, 0.001));
    expect(backup.services[1].serviceTypeKey, 'service_tire_swap_seasonal');

    // Plain expenses keep their mapped categories; income rows are skipped.
    expect(backup.costs, hasLength(2));
    expect(backup.costs.first.category, CostCategories.registration);
    expect(backup.costs[1].category, CostCategories.insurance);
    expect(
      backup.costs.any((c) => c.notes?.contains('Refund') ?? false),
      isFalse,
    );
  });

  test('category name heuristics cover Croatian and English labels', () {
    expect(mapFuelioCategory('Osiguranje'), CostCategories.insurance);
    expect(mapFuelioCategory('Tolls'), CostCategories.toll);
    expect(mapFuelioCategory('Tickets/Fines'), CostCategories.fine);
    expect(mapFuelioCategory('Wash'), CostCategories.wash);
    expect(mapFuelioCategory('Tuning'), CostCategories.equipment);
    expect(mapFuelioCategory('Sitnice'), CostCategories.other);
  });

  test('service title heuristics map Croatian names to type keys', () {
    expect(
      mapFuelioServiceTitle('Zamjena motornog ulja'),
      'service_oil_change',
    );
    expect(mapFuelioServiceTitle('Zamjena filtra ulja'), 'service_oil_filter');
    expect(mapFuelioServiceTitle('Zamjena filtra zraka'), 'service_air_filter');
  });

  test(
    'the belts are told apart, since only one of them is the timing belt',
    () {
      // Fuelio's own Croatian preset for the accessory belt is
      // "Zamjena remena za pogon dodatnih agregata i napinjača". Matching on
      // "remen" alone filed it as the timing belt — a different part, a
      // different interval, and a rather more expensive thing to be wrong about.
      expect(
        mapFuelioServiceTitle(
          'Zamjena remena za pogon dodatnih agregata i napinjača',
        ),
        'service_serpentine_belt',
      );
      expect(
        mapFuelioServiceTitle('Zamjena zupčastog remena'),
        'service_timing_belt',
      );
      expect(mapFuelioServiceTitle('Timing belt'), 'service_timing_belt');
      expect(
        mapFuelioServiceTitle('Serpentine belt'),
        'service_serpentine_belt',
      );
    },
  );

  test('the presets added since the importer was written are matched too', () {
    // Fifteen service types arrived in migration 0035 and the Fuelio mapping
    // was not revisited, so a backup naming any of them imported as nothing.
    expect(
      mapFuelioServiceTitle('Zamjena prednjih diskova'),
      'service_brake_discs_front',
    );
    expect(
      mapFuelioServiceTitle('Zamjena filtra goriva'),
      'service_fuel_filter',
    );
    expect(mapFuelioServiceTitle('Zamjena kvačila'), 'service_clutch');
    expect(mapFuelioServiceTitle('Zamjena grijača'), 'service_glow_plugs');
    expect(mapFuelioServiceTitle('Vodena pumpa'), 'service_water_pump');
    expect(
      mapFuelioServiceTitle('Zamjena amortizera'),
      'service_shock_absorbers',
    );
    expect(
      mapFuelioServiceTitle('Geometrija kotača'),
      'service_wheel_alignment',
    );
    expect(mapFuelioServiceTitle('Servis klime'), 'service_ac_service');
    // "klime" alone is ambiguous in Fuelio — it names both the cabin filter
    // and servicing the air conditioning — so only the filter wording claims
    // it.
    expect(
      mapFuelioServiceTitle('Zamjena filtra klime'),
      'service_cabin_filter',
    );
    expect(mapFuelioServiceTitle('Dopuna AdBlue'), 'service_adblue');
    expect(mapFuelioServiceTitle('DPF filtar'), 'service_dpf');
  });

  test('the ones that already worked still do', () {
    expect(mapFuelioServiceTitle('Zamjena svjećica'), 'service_spark_plugs');
    expect(
      mapFuelioServiceTitle('Zamjena kočione tekućine'),
      'service_brake_fluid',
    );
    expect(
      mapFuelioServiceTitle('Zamjena filtra putničkog prostora'),
      'service_cabin_filter',
    );
    expect(
      mapFuelioServiceTitle('Zamjena ulja mjenjača'),
      'service_transmission_oil',
    );
    expect(
      mapFuelioServiceTitle('Zamjena filtra putničkog prostora'),
      'service_cabin_filter',
    );
    expect(
      mapFuelioServiceTitle('Zamjena ulja mjenjača'),
      'service_transmission_oil',
    );
    expect(
      mapFuelioServiceTitle('Zamjena rashladne tekućine'),
      'service_coolant',
    );
    expect(
      mapFuelioServiceTitle('Zamjena kočione tekućine'),
      'service_brake_fluid',
    );
    expect(mapFuelioServiceTitle('Nepoznato'), isNull);
  });

  group('notes as Fuelio writes them', () {
    // Fuelio writes "Discount: 1,25\u00a0\u20ac" with a non-breaking space, and
    // occasionally several discounts separated by newlines inside one CSV
    // field. Carried through verbatim they read as artefacts in the app.
    const messy = '''
"## Log"
"Data","Odo (km)","Fuel (litres)","Full","Notes (optional)"
"2026-07-25 14:58","46818.0","34.578","1","Discount: 1,25\u00a0\u20ac"
"2026-07-13 07:06","46248.0","35.162","1","Discount: 11,25\u00a0\u20ac\nDiscount: 1,25\u00a0\u20ac"
"2026-07-01 09:00","45000.0","30.000","1","   "
''';

    test('a non-breaking space becomes an ordinary one', () {
      final fills = parseFuelioBackup(messy).fillUps;

      expect(fills.first.notes, 'Discount: 1,25 €');
      expect(fills.first.notes, isNot(contains('\u00a0')));
    });

    test('a note split over lines becomes one line', () {
      final note = parseFuelioBackup(messy).fillUps[1].notes;

      expect(note, 'Discount: 11,25 € · Discount: 1,25 €');
    });

    test('a note that is only whitespace is no note at all', () {
      expect(parseFuelioBackup(messy).fillUps[2].notes, isNull);
    });
  });

  group('comprehensive cover is its own bill', () {
    // In Croatia kasko is bought separately from the mandatory policy, often
    // from a different insurer and on a different date. Folding both into one
    // "insurance" line hides which of the two a household is actually paying.
    test('kasko maps to comprehensive, not to plain insurance', () {
      expect(
        mapFuelioCategory('Kasko osiguranje'),
        CostCategories.insuranceComprehensive,
      );
    });

    test('the mandatory policy stays plain insurance', () {
      expect(mapFuelioCategory('Osiguranje'), CostCategories.insurance);
      expect(mapFuelioCategory('Insurance'), CostCategories.insurance);
    });
  });
}
