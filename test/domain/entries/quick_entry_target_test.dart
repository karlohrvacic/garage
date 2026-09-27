import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/entities/vehicle.dart';
import 'package:garage/domain/entries/quick_entry_target.dart';

Vehicle car(String id, {bool archived = false}) {
  return Vehicle(
    id: id,
    householdId: 'h1',
    nickname: id,
    fuelTypeKey: 'fuel_diesel',
    baselineOdometerKm: 50000,
    baselineDate: DateTime.utc(2026, 1, 1),
    archived: archived,
  );
}

void main() {
  test('an empty garage has nothing to log against', () {
    expect(QuickEntryTarget.forGarage(const []), isA<NoVehicleToLog>());
  });

  test('one car is not a question worth asking', () {
    final target = QuickEntryTarget.forGarage([car('v1')]);

    expect(target, isA<LogThisVehicle>());
    expect((target as LogThisVehicle).vehicleId, 'v1');
  });

  test('two cars are a question, because the sheet does not name one', () {
    final target = QuickEntryTarget.forGarage([car('v1'), car('v2')]);

    expect(target, isA<AskWhichVehicle>());
    expect((target as AskWhichVehicle).vehicles.map((v) => v.id), ['v1', 'v2']);
  });

  group('an archived car is not a car you log against', () {
    test('so a garage of only archived cars has nothing to offer', () {
      expect(
        QuickEntryTarget.forGarage([car('v1', archived: true)]),
        isA<NoVehicleToLog>(),
      );
    });

    // The launcher hands us whatever the garage holds, archived rows included:
    // filtering here rather than trusting the caller is what stops a sold car
    // being the one the shortcut silently picks.
    test('and one live car beside an archived one is still unambiguous', () {
      final target = QuickEntryTarget.forGarage([
        car('sold', archived: true),
        car('v2'),
      ]);

      expect((target as LogThisVehicle).vehicleId, 'v2');
    });

    test('and is not offered in the list when there is a choice', () {
      final target = QuickEntryTarget.forGarage([
        car('v1'),
        car('sold', archived: true),
        car('v2'),
      ]);

      expect((target as AskWhichVehicle).vehicles.map((v) => v.id), [
        'v1',
        'v2',
      ]);
    });
  });
}
